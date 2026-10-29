SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_test_dispatch_event_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 provider_event_key text NOT NULL CHECK(length(btrim(provider_event_key)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 event_state text NOT NULL CHECK(event_state IN ('accepted','ended','rejected')),
 disposition text NOT NULL CHECK(disposition IN ('applied','observed','late')),
 dispatch_version integer NOT NULL CHECK(dispatch_version>0),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,provider_account_id,provider_event_key),
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_test_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 CHECK(disposition<>'late' OR event_state='accepted')
);
CREATE INDEX caller_test_dispatch_event_receipts_history ON public.caller_test_dispatch_event_receipts(tenant_id,dispatch_id,id DESC);
CREATE FUNCTION public.guard_test_dispatch_event_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE intent public.caller_test_dispatch_intents%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN
  RAISE EXCEPTION 'Test dispatch event receipts are immutable.' USING ERRCODE='23514';
 END IF;
 SELECT * INTO intent FROM public.caller_test_dispatch_intents WHERE id=NEW.dispatch_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND OR intent.provider_account_id<>NEW.provider_account_id OR intent.version<>NEW.dispatch_version
  OR (NEW.disposition='late' AND intent.state<>'ended')
  OR (NEW.disposition<>'late' AND intent.state<>NEW.event_state) THEN
  RAISE EXCEPTION 'Test dispatch event receipt binding does not match the recorded result.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_test_dispatch_event_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_test_dispatch_event_receipts FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_event_receipt();

CREATE TRIGGER caller_test_dispatch_event_receipt_no_truncate BEFORE TRUNCATE ON public.caller_test_dispatch_event_receipts FOR EACH STATEMENT EXECUTE FUNCTION public.guard_test_dispatch_event_receipt();
