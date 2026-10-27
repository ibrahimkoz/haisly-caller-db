SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_callback_consent_challenges (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 replaces_callback_id bigint,
 due_at timestamptz NOT NULL CHECK(isfinite(due_at) AND due_at=date_trunc('minute',due_at)),
 recipient_timezone text NOT NULL,
 language text NOT NULL CHECK(language IN ('tr','en')),
 prompt text NOT NULL CHECK(length(prompt) BETWEEN 1 AND 2000),
 prompt_version text NOT NULL CHECK(prompt_version='callback-consent-v1'),
 intent_digest text NOT NULL CHECK(intent_digest ~ '^[a-f0-9]{64}$'),
 issued_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 decision text CHECK(decision IN ('granted','denied','unknown')),
 prompt_event_ref text CHECK(prompt_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 response_event_ref text CHECK(response_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 prompt_completed_at timestamptz,
 response_observed_at timestamptz,
 resolved_at timestamptz,
 consumed_at timestamptz,
 applied_callback_id bigint,
 UNIQUE(id,tenant_id),
 UNIQUE(tenant_id,runtime_binding_id,response_event_ref),
 UNIQUE(tenant_id,applied_callback_id),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(replaces_callback_id,tenant_id) REFERENCES public.caller_callback_plans(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(applied_callback_id,tenant_id) REFERENCES public.caller_callback_plans(id,tenant_id) ON DELETE RESTRICT,
 CHECK(isfinite(issued_at) AND isfinite(expires_at) AND expires_at>issued_at AND expires_at<=issued_at+interval '5 minutes' AND expires_at<=due_at),
 CHECK((decision IS NULL AND prompt_event_ref IS NULL AND response_event_ref IS NULL AND prompt_completed_at IS NULL AND response_observed_at IS NULL AND resolved_at IS NULL) OR
  (decision IS NOT NULL AND prompt_event_ref IS NOT NULL AND response_event_ref IS NOT NULL AND prompt_completed_at IS NOT NULL AND response_observed_at IS NOT NULL AND resolved_at IS NOT NULL
   AND prompt_event_ref<>response_event_ref AND prompt_completed_at>=issued_at AND response_observed_at>prompt_completed_at AND response_observed_at<=resolved_at AND resolved_at<expires_at)),
 CHECK((consumed_at IS NULL AND applied_callback_id IS NULL) OR
  (consumed_at IS NOT NULL AND applied_callback_id IS NOT NULL AND decision IS NOT NULL AND decision='granted' AND resolved_at IS NOT NULL AND consumed_at>=resolved_at AND consumed_at<expires_at))
);
CREATE INDEX caller_callback_consent_binding ON public.caller_callback_consent_challenges(tenant_id,runtime_binding_id,issued_at DESC);
CREATE INDEX caller_callback_consent_replaces ON public.caller_callback_consent_challenges(tenant_id,replaces_callback_id);
CREATE FUNCTION public.guard_callback_consent_challenge() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE bound_target bigint; bound_dispatch bigint; decision_clock timestamptz := clock_timestamp();
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Callback consent history cannot be deleted' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='INSERT' THEN
  IF NEW.decision IS NOT NULL OR NEW.consumed_at IS NOT NULL THEN RAISE EXCEPTION 'Issue callback consent before resolving it' USING ERRCODE='23514'; END IF;
  NEW.issued_at:=decision_clock;
  NEW.expires_at:=least(decision_clock+interval '5 minutes',NEW.due_at);
 ELSE
  IF ROW(NEW.id,NEW.public_id,NEW.tenant_id,NEW.runtime_binding_id,NEW.replaces_callback_id,NEW.due_at,NEW.recipient_timezone,NEW.language,NEW.prompt,NEW.prompt_version,NEW.intent_digest,NEW.issued_at,NEW.expires_at)
   IS DISTINCT FROM ROW(OLD.id,OLD.public_id,OLD.tenant_id,OLD.runtime_binding_id,OLD.replaces_callback_id,OLD.due_at,OLD.recipient_timezone,OLD.language,OLD.prompt,OLD.prompt_version,OLD.intent_digest,OLD.issued_at,OLD.expires_at) THEN
   RAISE EXCEPTION 'Callback consent scope is immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.decision IS NOT NULL AND ROW(NEW.decision,NEW.prompt_event_ref,NEW.response_event_ref,NEW.prompt_completed_at,NEW.response_observed_at,NEW.resolved_at)
   IS DISTINCT FROM ROW(OLD.decision,OLD.prompt_event_ref,OLD.response_event_ref,OLD.prompt_completed_at,OLD.response_observed_at,OLD.resolved_at) THEN
   RAISE EXCEPTION 'Callback consent decision is immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.consumed_at IS NOT NULL THEN
   IF NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Consumed callback consent is immutable' USING ERRCODE='23514'; END IF;
   RETURN NEW;
  END IF;
  IF OLD.decision IS NULL AND NEW.decision IS NOT NULL THEN NEW.resolved_at:=decision_clock; END IF;
  IF NEW.consumed_at IS NOT NULL THEN NEW.consumed_at:=decision_clock; END IF;
 END IF;
 SELECT d.target_id,d.id INTO bound_target,bound_dispatch
 FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 JOIN public.caller_campaign_targets target ON target.id=d.target_id AND target.tenant_id=d.tenant_id
 WHERE b.id=NEW.runtime_binding_id AND b.tenant_id=NEW.tenant_id
 AND s.status='active' AND s.ended_at IS NULL AND c.status='in_progress' AND c.ended_at IS NULL
 AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref AND d.state='accepted'
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL AND person.do_not_call_at IS NULL
 AND target.identity_revision=d.identity_revision AND target.customer_id=d.customer_id AND target.snapshot_id=d.snapshot_id AND target.state<>'canceled'
 FOR SHARE OF b,d,s,c,person,target;
 IF NOT FOUND THEN RAISE EXCEPTION 'Callback consent requires its active bound call' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.caller_campaign_targets t JOIN public.caller_campaign_stop_requests r ON r.campaign_id=t.campaign_id AND r.tenant_id=t.tenant_id WHERE t.id=bound_target AND t.tenant_id=NEW.tenant_id AND r.intent='cancel') THEN
  RAISE EXCEPTION 'Canceled campaign cannot receive callback consent' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=NEW.recipient_timezone) OR NEW.due_at<=decision_clock THEN
  RAISE EXCEPTION 'Callback consent requires a future instant and valid timezone' USING ERRCODE='23514';
 END IF;
 IF TG_OP='INSERT' AND EXISTS(SELECT 1 FROM public.caller_callback_plans p WHERE p.tenant_id=NEW.tenant_id AND p.target_id=bound_target AND p.state='pending' AND p.id IS DISTINCT FROM NEW.replaces_callback_id) THEN
  RAISE EXCEPTION 'Specify the current callback being replaced' USING ERRCODE='23514';
 END IF;
 IF NEW.replaces_callback_id IS NOT NULL THEN
  PERFORM id FROM public.caller_callback_plans WHERE id=NEW.replaces_callback_id AND tenant_id=NEW.tenant_id AND target_id=bound_target
   AND ((NEW.consumed_at IS NULL AND state='pending') OR (NEW.consumed_at IS NOT NULL AND state='canceled' AND cancellation_reason='rescheduled')) FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Callback replacement no longer matches' USING ERRCODE='23514'; END IF;
 END IF;
 IF NEW.consumed_at IS NOT NULL THEN
  PERFORM id FROM public.caller_callback_plans WHERE id=NEW.applied_callback_id AND tenant_id=NEW.tenant_id AND target_id=bound_target
   AND source_dispatch_id=bound_dispatch AND due_at=NEW.due_at AND recipient_timezone=NEW.recipient_timezone AND state='pending'
   AND confirmed_at=NEW.response_observed_at AND evidence_reference=NEW.response_event_ref FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Callback consent consumption requires its matching plan' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_callback_consent_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_callback_consent_challenges FOR EACH ROW EXECUTE FUNCTION public.guard_callback_consent_challenge();
