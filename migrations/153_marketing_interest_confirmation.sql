SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_marketing_interest_confirmations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 result_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 subject text NOT NULL CHECK(length(subject) BETWEEN 1 AND 300),
 request text NOT NULL CHECK(request IN ('information','quote','demo')),
 language text NOT NULL CHECK(language IN ('tr','en')),
 prompt text NOT NULL CHECK(length(prompt) BETWEEN 1 AND 1000),
 prompt_version text NOT NULL CHECK(prompt_version='marketing-interest-v1'),
 intent_digest text NOT NULL CHECK(intent_digest ~ '^[a-f0-9]{64}$'),
 issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '5 minutes',
 decision text CHECK(decision IN ('granted','denied','unknown')),
 prompt_event_ref text CHECK(prompt_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 response_event_ref text CHECK(response_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 prompt_completed_at timestamptz,
 response_observed_at timestamptz,
 resolved_at timestamptz,
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,runtime_binding_id,response_event_ref),
 FOREIGN KEY(result_id,tenant_id) REFERENCES public.caller_marketing_result_revisions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 CHECK(isfinite(issued_at) AND isfinite(expires_at) AND expires_at>issued_at AND expires_at<=issued_at+interval '5 minutes'),
 CHECK((decision IS NULL AND prompt_event_ref IS NULL AND response_event_ref IS NULL AND prompt_completed_at IS NULL AND response_observed_at IS NULL AND resolved_at IS NULL)
 OR (decision IS NOT NULL AND prompt_event_ref IS NOT NULL AND response_event_ref IS NOT NULL AND prompt_event_ref<>response_event_ref AND prompt_completed_at IS NOT NULL AND response_observed_at IS NOT NULL AND resolved_at IS NOT NULL
 AND prompt_completed_at>=issued_at AND response_observed_at>prompt_completed_at AND resolved_at>=response_observed_at AND resolved_at<expires_at))
);
CREATE UNIQUE INDEX caller_marketing_confirmation_decision ON public.caller_marketing_interest_confirmations(tenant_id,result_id) WHERE decision IS NOT NULL;
CREATE INDEX caller_marketing_confirmation_pending ON public.caller_marketing_interest_confirmations(tenant_id,result_id,expires_at) WHERE decision IS NULL;
CREATE FUNCTION public.guard_marketing_interest_confirmation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Marketing confirmation history is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='UPDATE' THEN
  IF OLD.decision IS NOT NULL OR ROW(NEW.id,NEW.public_id,NEW.tenant_id,NEW.result_id,NEW.runtime_binding_id,NEW.subject,NEW.request,NEW.language,NEW.prompt,NEW.prompt_version,NEW.intent_digest,NEW.issued_at,NEW.expires_at)
   IS DISTINCT FROM ROW(OLD.id,OLD.public_id,OLD.tenant_id,OLD.result_id,OLD.runtime_binding_id,OLD.subject,OLD.request,OLD.language,OLD.prompt,OLD.prompt_version,OLD.intent_digest,OLD.issued_at,OLD.expires_at)
   OR NEW.decision IS NULL OR clock_timestamp()>=OLD.expires_at THEN
   RAISE EXCEPTION 'Marketing confirmation requires an unchanged unexpired challenge' USING ERRCODE='23514';
  END IF;
 END IF;
 PERFORM r.id FROM public.caller_marketing_result_revisions r
 JOIN public.caller_runtime_release_bindings b ON b.id=r.runtime_binding_id AND b.tenant_id=r.tenant_id
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=r.snapshot_id AND snap.tenant_id=r.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 WHERE r.id=NEW.result_id AND r.tenant_id=NEW.tenant_id AND r.runtime_binding_id=NEW.runtime_binding_id
 AND r.outcome='interested' AND r.connection_outcome='human' AND r.request=NEW.request
 AND snap.document->>'campaign_type'='marketing' AND snap.document->>'name'=NEW.subject AND snap.document->>'language'=NEW.language
 AND d.state='accepted' AND s.status='active' AND s.ended_at IS NULL
 AND c.status='in_progress' AND c.ended_at IS NULL AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 AND NOT EXISTS(SELECT 1 FROM public.caller_marketing_result_revisions later WHERE later.tenant_id=r.tenant_id AND later.target_id=r.target_id AND later.snapshot_id=r.snapshot_id AND later.version>r.version)
 AND NOT EXISTS(SELECT 1 FROM public.caller_marketing_interest_confirmations settled WHERE settled.tenant_id=r.tenant_id AND settled.result_id=r.id AND settled.decision IS NOT NULL)
 FOR SHARE OF r,b,d,s,c,snap,person;
 IF NOT FOUND THEN RAISE EXCEPTION 'Marketing confirmation must match current human interest in its active call' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.decision IS NOT NULL THEN RAISE EXCEPTION 'Marketing confirmation must start unresolved' USING ERRCODE='23514'; END IF;
  NEW.issued_at:=clock_timestamp(); NEW.expires_at:=NEW.issued_at+interval '5 minutes';
 ELSE NEW.resolved_at:=clock_timestamp(); END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_marketing_confirmation_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_marketing_interest_confirmations FOR EACH ROW EXECUTE FUNCTION public.guard_marketing_interest_confirmation();
