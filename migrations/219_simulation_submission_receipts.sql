SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_simulation_submission_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 submission_intent_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 state text NOT NULL CHECK(state IN ('accepted','uncertain','not_started')),
 reason text,
 invocation_id text CHECK(invocation_id IS NULL OR invocation_id ~ '^[A-Za-z0-9_-]{1,128}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,submission_intent_id),
 UNIQUE(tenant_id,provider_account_id,invocation_id),
 FOREIGN KEY(submission_intent_id,tenant_id) REFERENCES public.caller_simulation_submission_intents(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 CHECK((state='accepted' AND reason IS NULL AND invocation_id IS NOT NULL)
  OR (state='uncertain' AND reason IS NOT NULL AND reason IN ('http_response','invalid_response','binding_unconfirmed','transport_or_response'))
  OR (state='not_started' AND invocation_id IS NULL AND reason IS NOT NULL AND reason IN ('disabled','invalid_binding','not_configured','aborted')))
);
CREATE FUNCTION public.guard_simulation_submission_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE intent public.caller_simulation_submission_intents%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Simulation submission receipt is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO intent FROM public.caller_simulation_submission_intents WHERE id=NEW.submission_intent_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND OR intent.provider_account_id<>NEW.provider_account_id THEN
  RAISE EXCEPTION 'Simulation receipt provider does not match intent' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_simulation_submission_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_simulation_submission_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_simulation_submission_receipt();
COMMENT ON TABLE public.caller_simulation_submission_receipts IS 'Immutable first transport outcome, including late responses. Never marks simulation success or authorizes retry. Uncertain invocation IDs are unconfirmed recovery hints.';
