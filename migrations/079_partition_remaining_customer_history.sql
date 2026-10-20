SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
DO $$ DECLARE relation text; BEGIN
 FOREACH relation IN ARRAY ARRAY['leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  EXECUTE format('ALTER TABLE public.%I ADD COLUMN customer_identity_revision integer',relation);
  EXECUTE format('UPDATE public.%I h SET customer_identity_revision=c.identity_revision FROM public.customers c WHERE c.id=h.customer_id AND c.tenant_id=h.tenant_id',relation);
  EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK ((customer_id IS NULL AND customer_identity_revision IS NULL) OR (customer_id IS NOT NULL AND customer_identity_revision IS NOT NULL AND customer_identity_revision>0))',relation,relation||'_customer_revision_check');
  EXECUTE format('CREATE INDEX %I ON public.%I(tenant_id,customer_id,customer_identity_revision) WHERE customer_id IS NOT NULL',relation||'_customer_revision_idx',relation);
 END LOOP;
END $$;
ALTER TABLE public.handoff_requests ADD COLUMN customer_display_name_snapshot text,
 ADD COLUMN customer_first_name_snapshot text, ADD COLUMN customer_last_name_snapshot text;
UPDATE public.handoff_requests h SET customer_display_name_snapshot=c.display_name,
 customer_first_name_snapshot=c.first_name,customer_last_name_snapshot=c.last_name
FROM public.customers c WHERE c.id=h.customer_id AND c.tenant_id=h.tenant_id;

-- Only fixed, internal relation names are used by these checks.
CREATE FUNCTION public.guard_related_customer_identity(
 tenant bigint, person bigint, revision integer, fields jsonb
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE key text; target text; ref_id bigint; linked_person bigint; linked_revision integer; call_ref bigint; identity_boundary timestamptz;
BEGIN
 FOREACH key IN ARRAY ARRAY['call_id','source_call_id','call_session_id','case_id','source_case_id','lead_id','workflow_run_id'] LOOP
  ref_id := (fields->>key)::bigint;
  IF ref_id IS NULL THEN CONTINUE; END IF;
  IF key IN ('call_id','source_call_id','call_session_id') THEN
   call_ref:=ref_id;
   IF key='call_session_id' THEN
    SELECT call_id INTO call_ref FROM public.call_sessions WHERE id=ref_id AND tenant_id=tenant;
   END IF;
   SELECT max(valid_until) INTO identity_boundary FROM public.contact_identity_revisions WHERE tenant_id=tenant AND customer_id=person;
   IF identity_boundary IS NOT NULL AND EXISTS(SELECT 1 FROM public.calls c WHERE c.id=call_ref AND c.tenant_id=tenant AND c.started_at<identity_boundary) THEN
    RAISE EXCEPTION 'Call predates the current identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
   IF EXISTS(SELECT 1 FROM public.customer_interactions i WHERE i.tenant_id=tenant AND i.call_id=call_ref AND
       (i.customer_id<>person OR i.customer_identity_revision<>revision)) THEN
    RAISE EXCEPTION 'Related call belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  ELSE
   target:=CASE WHEN key IN ('case_id','source_case_id') THEN 'cases' WHEN key='lead_id' THEN 'leads' ELSE 'workflow_runs' END;
   EXECUTE format('SELECT customer_id,customer_identity_revision FROM public.%I WHERE id=$1 AND tenant_id=$2',target)
    INTO linked_person,linked_revision USING ref_id,tenant;
   IF linked_person IS NOT NULL AND (linked_person<>person OR linked_revision<>revision) THEN
    RAISE EXCEPTION 'Related resource belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  END IF;
 END LOOP;
END $$;

CREATE FUNCTION public.snapshot_remaining_customer_history() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person public.customers%ROWTYPE; boundary timestamptz; event_at timestamptz; fields jsonb; old_fields jsonb; key text;
BEGIN
 fields:=to_jsonb(NEW);
 IF TG_OP='UPDATE' THEN
  old_fields:=to_jsonb(OLD);
  FOREACH key IN ARRAY ARRAY['tenant_id','tenant_environment_id','customer_identity_revision','call_id','source_call_id','call_session_id','case_id','source_case_id','lead_id','workflow_run_id','created_at','requested_at','occurred_at','captured_at','customer_display_name_snapshot','customer_first_name_snapshot','customer_last_name_snapshot'] LOOP
   IF fields->key IS DISTINCT FROM old_fields->key THEN
    RAISE EXCEPTION 'Historical identity or relationship cannot be changed' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  END LOOP;
  IF NEW.customer_id IS NOT DISTINCT FROM OLD.customer_id THEN RETURN NEW; END IF;
  -- Keep legitimate conversion of an unassigned lead; never reassign a known identity.
  IF TG_TABLE_NAME<>'leads' OR OLD.customer_id IS NOT NULL OR NEW.customer_id IS NULL THEN
   RAISE EXCEPTION 'Historical customer cannot be reassigned' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
  END IF;
 END IF;
 IF NEW.customer_id IS NULL THEN
  NEW.customer_identity_revision:=NULL;
  IF TG_TABLE_NAME='handoff_requests' THEN
   NEW.customer_display_name_snapshot:=NULL;NEW.customer_first_name_snapshot:=NULL;NEW.customer_last_name_snapshot:=NULL;
  END IF;
  RETURN NEW;
 END IF;
 SELECT * INTO person FROM public.customers WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Customer is outside tenant scope' USING ERRCODE='23503'; END IF;
 IF NEW.customer_identity_revision IS NOT NULL AND NEW.customer_identity_revision<>person.identity_revision THEN
  RAISE EXCEPTION 'Historical identity requires reconciliation' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
 END IF;
 SELECT max(valid_until) INTO boundary FROM public.contact_identity_revisions WHERE tenant_id=NEW.tenant_id AND customer_id=NEW.customer_id;
 event_at:=coalesce((fields->>'occurred_at')::timestamptz,(fields->>'captured_at')::timestamptz,(fields->>'requested_at')::timestamptz,(fields->>'created_at')::timestamptz);
 IF boundary IS NOT NULL AND event_at<boundary THEN
  RAISE EXCEPTION 'Late historical event requires reconciliation' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
 END IF;
 NEW.customer_identity_revision:=person.identity_revision;
 PERFORM public.guard_related_customer_identity(NEW.tenant_id,NEW.customer_id,NEW.customer_identity_revision,fields);
 IF TG_TABLE_NAME='handoff_requests' THEN
  NEW.customer_display_name_snapshot:=person.display_name;
  NEW.customer_first_name_snapshot:=person.first_name;
  NEW.customer_last_name_snapshot:=person.last_name;
 END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE relation text; BEGIN
 FOREACH relation IN ARRAY ARRAY['leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.snapshot_remaining_customer_history()',relation||'_snapshot_identity',relation);
 END LOOP;
END $$;

-- Extend cross-resource protection to the earlier case/interaction snapshot writers.
CREATE FUNCTION public.enforce_related_customer_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.customer_id IS NOT NULL THEN
  PERFORM public.guard_related_customer_identity(NEW.tenant_id,NEW.customer_id,NEW.customer_identity_revision,to_jsonb(NEW));
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cases_validate_related_identity BEFORE INSERT ON public.cases FOR EACH ROW EXECUTE FUNCTION public.enforce_related_customer_identity();
CREATE TRIGGER customer_interactions_validate_related_identity BEFORE INSERT ON public.customer_interactions FOR EACH ROW EXECUTE FUNCTION public.enforce_related_customer_identity();
