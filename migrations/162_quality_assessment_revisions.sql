SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_assessment_revisions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 runtime_binding_id bigint NOT NULL,
 call_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 version integer NOT NULL CHECK(version>0),
 evaluator_ref text NOT NULL CHECK(evaluator_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 assessment jsonb NOT NULL CHECK(jsonb_typeof(assessment)='object'),
 calculation jsonb NOT NULL CHECK(jsonb_typeof(calculation)='object'),
 request_key text NOT NULL CHECK(length(request_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,runtime_binding_id,version),
 UNIQUE(tenant_id,runtime_binding_id,request_key),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(call_id,tenant_id) REFERENCES public.calls(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_quality_call_history ON public.caller_quality_assessment_revisions(tenant_id,call_id,id DESC);
CREATE INDEX caller_quality_snapshot_history ON public.caller_quality_assessment_revisions(tenant_id,snapshot_id,id DESC);
CREATE FUNCTION public.guard_quality_assessment_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE closure record; prior_version integer; dimension text; check_name text; item jsonb;
 weight_value integer; score_value integer; total_weight integer:=0; coverage integer:=0;
 weighted_score integer:=0; missing jsonb:='[]'::jsonb; expected_score numeric;
 evidence_id text;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality assessment revisions are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT call_id,snapshot_id INTO closure FROM public.caller_call_end_snapshots
 WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quality assessment requires a captured bound call end' USING ERRCODE='23514'; END IF;
 NEW.call_id:=closure.call_id; NEW.snapshot_id:=closure.snapshot_id;
 SELECT coalesce(max(version),0) INTO prior_version FROM public.caller_quality_assessment_revisions
 WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id;
 IF NEW.version<>prior_version+1 THEN RAISE EXCEPTION 'Quality assessment requires the next version' USING ERRCODE='23514'; END IF;
 FOREACH dimension IN ARRAY ARRAY['objective','grounding','identity_tone','preference_tools'] LOOP
  IF coalesce(NEW.assessment->'weights'->>dimension,'') !~ '^(0|[1-9][0-9]?|100)$' THEN
   RAISE EXCEPTION 'Quality weight is invalid' USING ERRCODE='23514';
  END IF;
  weight_value:=(NEW.assessment->'weights'->>dimension)::integer; total_weight:=total_weight+weight_value;
  item:=NEW.assessment->'dimensions'->dimension;
  IF item IS NULL THEN RAISE EXCEPTION 'Quality dimension is missing' USING ERRCODE='23514'; END IF;
  IF item='null'::jsonb THEN missing:=missing||jsonb_build_array(dimension);
  ELSE
   IF coalesce(item->>'score','') !~ '^(0|[1-9][0-9]?|100)$'
    OR jsonb_typeof(item->'evidence_public_ids') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Quality score/evidence is invalid' USING ERRCODE='23514';
   END IF;
   IF jsonb_array_length(item->'evidence_public_ids') NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Quality dimension requires bounded evidence' USING ERRCODE='23514';
   END IF;
   score_value:=(item->>'score')::integer; weighted_score:=weighted_score+score_value*weight_value; coverage:=coverage+weight_value;
  END IF;
 END LOOP;
 IF total_weight<>100 THEN RAISE EXCEPTION 'Quality weights must total100' USING ERRCODE='23514'; END IF;
 FOREACH check_name IN ARRAY ARRAY['do_not_call','tool_authorization'] LOOP
  item:=NEW.assessment->'critical_checks'->check_name;
  IF item->>'provenance' IS DISTINCT FROM 'model_assessment'
   OR coalesce(item->>'result','') NOT IN ('pass','violation','unknown')
   OR jsonb_typeof(item->'evidence_public_ids') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'Model evaluation cannot assert verified critical evidence' USING ERRCODE='23514';
  END IF;
  IF jsonb_array_length(item->'evidence_public_ids')>100
   OR (item->>'result'<>'unknown' AND jsonb_array_length(item->'evidence_public_ids')=0) THEN
   RAISE EXCEPTION 'Critical evidence is invalid' USING ERRCODE='23514';
  END IF;
 END LOOP;
 -- Only immutable, exact-call structured artifacts are currently supported.
 FOR evidence_id IN
  SELECT DISTINCT e.value FROM (
   SELECT value FROM jsonb_each(NEW.assessment->'dimensions') WHERE value<>'null'::jsonb
   UNION ALL SELECT value FROM jsonb_each(NEW.assessment->'critical_checks')
  ) items CROSS JOIN LATERAL jsonb_array_elements_text(items.value->'evidence_public_ids') e
 LOOP
  IF NOT EXISTS(SELECT 1 FROM public.caller_call_end_snapshots WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id AND public_id::text=evidence_id)
   AND NOT EXISTS(SELECT 1 FROM public.caller_marketing_result_revisions WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id AND public_id::text=evidence_id) THEN
   RAISE EXCEPTION 'Quality evidence does not belong to this bound call' USING ERRCODE='23514';
  END IF;
 END LOOP;
 expected_score:=CASE WHEN coverage=100 THEN weighted_score::numeric/100 ELSE NULL END;
 -- Derive the result independently; caller cannot forge a score or critical flag.
 NEW.calculation:=jsonb_build_object('rubric_version',1,'score',expected_score,'coverage_percent',coverage,
  'missing_dimensions',missing,'review_required',true,'critical_violations','[]'::jsonb);
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_assessment_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_assessment_revisions
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_assessment_revision();
