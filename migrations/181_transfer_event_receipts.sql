SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_transfer_event_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 transfer_attempt_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 provider_event_key text NOT NULL CHECK(length(btrim(provider_event_key)) BETWEEN 1 AND 200),
 provider_transfer_ref text NOT NULL CHECK(length(btrim(provider_transfer_ref)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 outcome text NOT NULL CHECK(outcome IN ('accepted','connected','failed','completed')),
 occurred_at timestamptz NOT NULL,
 result_status text NOT NULL CHECK(result_status IN ('reserved','pending','uncertain','connected','failed','completed')),
 result_conflict_hold boolean NOT NULL,
 result_version integer NOT NULL CHECK(result_version>0),
 reason text NOT NULL CHECK(length(reason) BETWEEN 1 AND 100),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,provider_account_id,provider_event_key),
 FOREIGN KEY(transfer_attempt_id,tenant_id) REFERENCES public.caller_transfer_attempts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_transfer_receipt_attempt_idx ON public.caller_transfer_event_receipts(tenant_id,transfer_attempt_id,id);
CREATE INDEX caller_transfer_receipt_provider_ref_idx ON public.caller_transfer_event_receipts(tenant_id,provider_account_id,provider_transfer_ref);
CREATE FUNCTION public.guard_caller_transfer_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE attempt public.caller_transfer_attempts%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Transfer receipts are immutable' USING ERRCODE='23514'; END IF;
 -- Service takes this lock before call/policy/attempt locks. The trigger is a
 -- final integrity check, not an independent authorization or ingestion API.
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT * INTO attempt FROM public.caller_transfer_attempts WHERE tenant_id=NEW.tenant_id AND id=NEW.transfer_attempt_id FOR SHARE;
 IF NOT FOUND OR attempt.version<>NEW.result_version OR attempt.status<>NEW.result_status OR attempt.conflict_hold<>NEW.result_conflict_hold THEN
  RAISE EXCEPTION 'Transfer receipt result mismatch' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.caller_dispatch_intents d
  JOIN public.telephony_provider_accounts p ON p.id=d.provider_account_id AND p.tenant_id=d.tenant_id
  JOIN public.caller_runtime_release_bindings b ON b.dispatch_id=d.id AND b.tenant_id=d.tenant_id
  JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
  JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
  WHERE d.id=NEW.dispatch_id AND d.tenant_id=NEW.tenant_id AND p.id=NEW.provider_account_id
   AND s.call_id=attempt.call_id AND s.tenant_environment_id=attempt.tenant_environment_id
   AND p.tenant_environment_id=attempt.tenant_environment_id AND c.provider_call_id=d.provider_call_ref
 ) THEN RAISE EXCEPTION 'Transfer receipt provider binding mismatch' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.caller_transfer_event_receipts r WHERE r.tenant_id=NEW.tenant_id AND
  ((r.transfer_attempt_id=NEW.transfer_attempt_id AND (r.provider_account_id<>NEW.provider_account_id OR r.provider_transfer_ref<>NEW.provider_transfer_ref OR r.dispatch_id<>NEW.dispatch_id)) OR
   (r.provider_account_id=NEW.provider_account_id AND r.provider_transfer_ref=NEW.provider_transfer_ref AND r.transfer_attempt_id<>NEW.transfer_attempt_id))) THEN
  RAISE EXCEPTION 'Transfer provider reference already bound' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 IF NEW.occurred_at>NEW.created_at THEN RAISE EXCEPTION 'Transfer receipt time is in the future' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_transfer_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_transfer_event_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_transfer_receipt();
COMMENT ON TABLE public.caller_transfer_event_receipts IS 'Immutable normalized outbound transfer observations from an authenticated adapter. General webhook status or unverified runtime input is not provider proof. Retention requires a separate workflow.';
