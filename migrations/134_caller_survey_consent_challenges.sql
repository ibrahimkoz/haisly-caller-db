-- Additive storage only. Trusted observer verification and atomic survey mutation
-- remain service responsibilities; this table never turns model output into authority.
SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_runtime_release_bindings ADD CONSTRAINT caller_runtime_binding_id_tenant_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_survey_consent_challenges (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
 runtime_binding_id bigint NOT NULL,
 purpose text NOT NULL CHECK(purpose IN ('start','resume')),
 survey_session_id bigint,
 expected_version integer NOT NULL,
 language text NOT NULL CHECK(language IN ('tr','en')),
 prompt_version text NOT NULL CHECK(prompt_version='survey-consent-v1'),
 intent_digest text NOT NULL CHECK(intent_digest ~ '^[a-f0-9]{64}$'),
 issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT (clock_timestamp()+interval '5 minutes'),
 decision text CHECK(decision IN ('granted','denied','unknown')),
 prompt_event_ref text CHECK(prompt_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 response_event_ref text CHECK(response_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 prompt_completed_at timestamptz,
 response_observed_at timestamptz,
 resolved_at timestamptz,
 consumed_at timestamptz,
 applied_survey_session_id bigint,
 applied_version integer,
 UNIQUE(id,tenant_id),
 UNIQUE(tenant_id,runtime_binding_id,response_event_ref),
 UNIQUE(tenant_id,applied_survey_session_id,applied_version),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(survey_session_id,tenant_id) REFERENCES public.caller_survey_sessions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(applied_survey_session_id,tenant_id) REFERENCES public.caller_survey_sessions(id,tenant_id) ON DELETE RESTRICT,
 CHECK((purpose='start' AND survey_session_id IS NULL AND expected_version=0) OR
       (purpose='resume' AND survey_session_id IS NOT NULL AND expected_version>0)),
 CHECK(expires_at>issued_at AND expires_at<=issued_at+interval '5 minutes'),
 CHECK((decision IS NULL AND prompt_event_ref IS NULL AND response_event_ref IS NULL AND
        prompt_completed_at IS NULL AND response_observed_at IS NULL AND resolved_at IS NULL) OR
       (decision IS NOT NULL AND prompt_event_ref IS NOT NULL AND response_event_ref IS NOT NULL AND
        prompt_completed_at IS NOT NULL AND response_observed_at IS NOT NULL AND resolved_at IS NOT NULL AND
        prompt_event_ref<>response_event_ref AND prompt_completed_at>=issued_at AND
        response_observed_at>prompt_completed_at AND response_observed_at<=resolved_at AND resolved_at<expires_at)),
 CHECK((consumed_at IS NULL AND applied_survey_session_id IS NULL AND applied_version IS NULL) OR
       (consumed_at IS NOT NULL AND decision IS NOT NULL AND decision='granted' AND resolved_at IS NOT NULL AND
        applied_survey_session_id IS NOT NULL AND applied_version IS NOT NULL AND
        applied_version=expected_version+1 AND consumed_at>=resolved_at AND consumed_at<expires_at))
);
CREATE INDEX caller_survey_consent_binding_idx ON public.caller_survey_consent_challenges(tenant_id,runtime_binding_id,issued_at DESC);
CREATE INDEX caller_survey_consent_session_idx ON public.caller_survey_consent_challenges(tenant_id,survey_session_id);
CREATE INDEX caller_survey_consent_applied_idx ON public.caller_survey_consent_challenges(tenant_id,applied_survey_session_id);
CREATE INDEX caller_survey_consent_expiry_idx ON public.caller_survey_consent_challenges(expires_at) WHERE consumed_at IS NULL;
CREATE FUNCTION public.caller_guard_survey_consent_challenge() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE bound_target bigint; bound_snapshot bigint; decision_clock timestamptz;
BEGIN
 decision_clock := clock_timestamp();
 IF TG_OP='INSERT' THEN
  IF NEW.decision IS NOT NULL OR NEW.consumed_at IS NOT NULL THEN
   RAISE EXCEPTION 'Survey consent must be issued before resolution' USING ERRCODE='23514';
  END IF;
  NEW.issued_at := decision_clock;
  NEW.expires_at := decision_clock+interval '5 minutes';
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.runtime_binding_id,NEW.purpose,NEW.survey_session_id,
      NEW.expected_version,NEW.language,NEW.prompt_version,NEW.intent_digest,NEW.issued_at,NEW.expires_at)
    IS DISTINCT FROM
     (OLD.id,OLD.public_id,OLD.tenant_id,OLD.runtime_binding_id,OLD.purpose,OLD.survey_session_id,
      OLD.expected_version,OLD.language,OLD.prompt_version,OLD.intent_digest,OLD.issued_at,OLD.expires_at) THEN
   RAISE EXCEPTION 'Survey consent scope is immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.decision IS NOT NULL AND (NEW.decision,NEW.prompt_event_ref,NEW.response_event_ref,
     NEW.prompt_completed_at,NEW.response_observed_at,NEW.resolved_at) IS DISTINCT FROM
     (OLD.decision,OLD.prompt_event_ref,OLD.response_event_ref,OLD.prompt_completed_at,OLD.response_observed_at,OLD.resolved_at) THEN
   RAISE EXCEPTION 'Survey consent decision is immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.consumed_at IS NOT NULL THEN
   IF NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'Consumed survey consent is immutable' USING ERRCODE='23514';
   END IF;
   RETURN NEW;
  END IF;
  IF OLD.decision IS NULL AND NEW.decision IS NOT NULL THEN NEW.resolved_at := decision_clock; END IF;
  IF NEW.consumed_at IS NOT NULL THEN NEW.consumed_at := decision_clock; END IF;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id,0));
 SELECT d.target_id,d.snapshot_id INTO bound_target,bound_snapshot
 FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 JOIN public.caller_campaign_targets target ON target.id=d.target_id AND target.tenant_id=d.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=d.snapshot_id AND snap.tenant_id=d.tenant_id
 WHERE b.id=NEW.runtime_binding_id AND b.tenant_id=NEW.tenant_id
 AND s.status='active' AND s.ended_at IS NULL AND c.status='in_progress' AND c.ended_at IS NULL
 AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref AND d.state='accepted'
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 AND target.identity_revision=d.identity_revision AND target.customer_id=d.customer_id AND target.snapshot_id=d.snapshot_id
 AND snap.document->>'campaign_type'='survey'
 FOR SHARE OF b,d,s,c,person,target,snap;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'Survey consent requires an active matching survey call' USING ERRCODE='23514';
 END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.purpose='start' THEN
   IF EXISTS(SELECT 1 FROM public.caller_survey_sessions WHERE tenant_id=NEW.tenant_id AND target_id=bound_target) THEN
    RAISE EXCEPTION 'Survey already started' USING ERRCODE='23514';
   END IF;
  ELSE
   PERFORM id FROM public.caller_survey_sessions WHERE id=NEW.survey_session_id AND tenant_id=NEW.tenant_id
    AND target_id=bound_target AND snapshot_id=bound_snapshot AND version=NEW.expected_version AND state='partial' FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Survey resume version does not match' USING ERRCODE='23514'; END IF;
  END IF;
 END IF;
 IF NEW.consumed_at IS NOT NULL THEN
  PERFORM id FROM public.caller_survey_sessions WHERE id=NEW.applied_survey_session_id AND tenant_id=NEW.tenant_id
   AND target_id=bound_target AND snapshot_id=bound_snapshot AND version=NEW.applied_version AND state='active'
   AND (NEW.purpose='start' OR id=NEW.survey_session_id) FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Survey consent consumption requires its applied survey transition' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_consent_guard BEFORE INSERT OR UPDATE ON public.caller_survey_consent_challenges
FOR EACH ROW EXECUTE FUNCTION public.caller_guard_survey_consent_challenge();
