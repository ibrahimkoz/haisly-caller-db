SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_call_end_snapshots (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 runtime_binding_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 call_id bigint NOT NULL,
 target_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 ended_at timestamptz NOT NULL CHECK(isfinite(ended_at)),
 end_reason text NOT NULL CHECK(end_reason IN ('completed','no_answer','busy','declined','failed','canceled','voicemail')),
 call_status text NOT NULL CHECK(call_status IN ('completed','failed','no_answer','busy','canceled')),
 marketing_result_id bigint,
 marketing_version integer CHECK(marketing_version>0),
 marketing_confirmation text CHECK(marketing_confirmation IN ('granted','denied','unknown','not_requested')),
 survey_session_id bigint,
 survey_version integer CHECK(survey_version>0),
 survey_state text CHECK(survey_state IN ('active','partial','completed','declined')),
 survey_revision_count integer CHECK(survey_revision_count>=0),
 survey_attribution text NOT NULL CHECK(survey_attribution IN ('not_applicable','not_started','captured','superseded')),
 captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,runtime_binding_id),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(call_id,tenant_id) REFERENCES public.calls(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(marketing_result_id,tenant_id) REFERENCES public.caller_marketing_result_revisions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(survey_session_id,tenant_id) REFERENCES public.caller_survey_sessions(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_call_end_read ON public.caller_call_end_snapshots(tenant_id,call_id);
CREATE FUNCTION public.guard_call_end_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source record; marketing record; survey record;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Call end snapshots are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT d.id dispatch_id,d.target_id,d.snapshot_id,d.accepted_at,d.ended_at,d.end_reason,c.id call_id,c.status call_status,snap.document->>'campaign_type' campaign_type
 INTO source FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=b.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=d.snapshot_id AND snap.tenant_id=d.tenant_id
 WHERE b.tenant_id=NEW.tenant_id AND b.id=NEW.runtime_binding_id
 AND d.state='ended' AND d.ended_at<=clock_timestamp()
 AND c.ended_at=d.ended_at AND s.ended_at=d.ended_at
 AND c.status IN ('completed','failed','no_answer','busy','canceled') AND s.status IN ('completed','failed','cancelled')
 AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref AND c.phone_number_id=d.outbound_phone_number_id
 FOR SHARE OF b,d,s,c,snap;
 IF NOT FOUND THEN RAISE EXCEPTION 'Call end snapshot requires a closed matching bound call' USING ERRCODE='23514'; END IF;
 NEW.dispatch_id:=source.dispatch_id; NEW.call_id:=source.call_id; NEW.target_id:=source.target_id; NEW.snapshot_id:=source.snapshot_id;
 NEW.ended_at:=source.ended_at; NEW.end_reason:=source.end_reason; NEW.call_status:=source.call_status;
 NEW.marketing_result_id:=NULL; NEW.marketing_version:=NULL; NEW.marketing_confirmation:=NULL;
 NEW.survey_session_id:=NULL; NEW.survey_version:=NULL; NEW.survey_state:=NULL; NEW.survey_revision_count:=NULL;
 NEW.survey_attribution:='not_applicable';
 IF source.campaign_type='marketing' THEN
  SELECT id,version INTO marketing FROM public.caller_marketing_result_revisions WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id ORDER BY version DESC LIMIT 1 FOR SHARE;
  IF FOUND THEN
   NEW.marketing_result_id:=marketing.id; NEW.marketing_version:=marketing.version;
   SELECT coalesce(decision,'unknown') INTO NEW.marketing_confirmation FROM public.caller_marketing_interest_confirmations WHERE tenant_id=NEW.tenant_id AND result_id=marketing.id ORDER BY (decision IS NOT NULL) DESC,id DESC LIMIT 1 FOR SHARE;
   NEW.marketing_confirmation:=coalesce(NEW.marketing_confirmation,'not_requested');
  END IF;
 ELSE
  NEW.survey_attribution:='not_started';
  IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND target_id=source.target_id AND snapshot_id=source.snapshot_id AND (accepted_at>source.accepted_at OR (accepted_at=source.accepted_at AND id>source.dispatch_id))) THEN
   NEW.survey_attribution:='superseded';
  ELSE
   SELECT id,version,state,revision_count INTO survey FROM public.caller_survey_sessions WHERE tenant_id=NEW.tenant_id AND target_id=source.target_id AND snapshot_id=source.snapshot_id FOR SHARE;
   IF FOUND THEN
    NEW.survey_session_id:=survey.id; NEW.survey_version:=survey.version; NEW.survey_state:=survey.state; NEW.survey_revision_count:=survey.revision_count; NEW.survey_attribution:='captured';
   END IF;
  END IF;
 END IF;
 NEW.captured_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_call_end_snapshot_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_call_end_snapshots FOR EACH ROW EXECUTE FUNCTION public.guard_call_end_snapshot();
