SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_provider_circuits (
 provider_account_id bigint PRIMARY KEY,
 tenant_id bigint NOT NULL,
 mode text NOT NULL CHECK(mode IN ('closed','open','probing')),
 epoch bigint NOT NULL CHECK(epoch BETWEEN 0 AND 9007199254740990),
 consecutive_failures integer NOT NULL CHECK(consecutive_failures BETWEEN 0 AND 3),
 opened_at timestamptz,
 next_probe_at timestamptz,
 probe_token uuid,
 probe_expires_at timestamptz,
 alerted boolean NOT NULL DEFAULT false,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 updated_at timestamptz NOT NULL,
 UNIQUE(provider_account_id,tenant_id),
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 CHECK(isfinite(updated_at)),
 CHECK((mode='closed' AND consecutive_failures<3 AND opened_at IS NULL AND next_probe_at IS NULL AND NOT alerted)
  OR (mode IN ('open','probing') AND consecutive_failures=3 AND opened_at IS NOT NULL AND next_probe_at IS NOT NULL AND isfinite(opened_at) AND isfinite(next_probe_at) AND opened_at<=updated_at AND next_probe_at>=opened_at)),
 CHECK((mode='probing' AND probe_token IS NOT NULL AND probe_expires_at IS NOT NULL AND isfinite(probe_expires_at) AND probe_expires_at>updated_at)
  OR (mode<>'probing' AND probe_token IS NULL AND probe_expires_at IS NULL))
);
CREATE INDEX caller_provider_circuits_due_idx ON public.caller_provider_circuits(tenant_id,next_probe_at,provider_account_id) WHERE mode<>'closed';
CREATE TABLE public.caller_provider_circuit_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 event_key text NOT NULL CHECK(length(btrim(event_key)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 ignored boolean NOT NULL,
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,provider_account_id,event_key),
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.caller_provider_circuits(provider_account_id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_provider_circuit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Provider circuit history must be retained.' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND ((NEW.provider_account_id,NEW.tenant_id) IS DISTINCT FROM (OLD.provider_account_id,OLD.tenant_id)
  OR NEW.version<>OLD.version+1 OR NEW.epoch<OLD.epoch OR NEW.updated_at<OLD.updated_at) THEN
  RAISE EXCEPTION 'Invalid provider circuit revision.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_provider_circuit_guard BEFORE UPDATE OR DELETE ON public.caller_provider_circuits FOR EACH ROW EXECUTE FUNCTION public.guard_provider_circuit();
CREATE FUNCTION public.guard_provider_circuit_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 RAISE EXCEPTION 'Provider circuit receipts are immutable.' USING ERRCODE='23514';
END;
$$;
CREATE TRIGGER caller_provider_circuit_receipt_guard BEFORE UPDATE OR DELETE ON public.caller_provider_circuit_receipts FOR EACH ROW EXECUTE FUNCTION public.guard_provider_circuit_receipt();
