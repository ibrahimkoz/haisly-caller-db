-- Additive storage only: runtime issuance remains disabled until trusted consent
-- evidence and release/session/contact authorization are connected.
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_tool_confirmations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  call_session_id bigint NOT NULL,
  tool_code text NOT NULL CHECK (tool_code IN ('appointment_create', 'appointment_cancel', 'crm_upsert')),
  contract_version integer NOT NULL CHECK (contract_version > 0),
  intent_digest text NOT NULL CHECK (intent_digest ~ '^[a-f0-9]{64}$'),
  token_hash text NOT NULL UNIQUE CHECK (token_hash ~ '^[a-f0-9]{64}$'),
  -- Opaque verified event identifier, never transcript or model-supplied consent.
  confirmation_event_ref text NOT NULL CHECK (confirmation_event_ref ~ '^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,159}$'),
  issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  tool_execution_run_id bigint,
  revoked_at timestamptz,
  CONSTRAINT caller_tool_confirmation_session_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions(id, tenant_id) ON DELETE CASCADE,
  CONSTRAINT caller_tool_confirmation_execution_fk FOREIGN KEY (tool_execution_run_id, tenant_id)
    REFERENCES public.tool_execution_runs(id, tenant_id) ON DELETE RESTRICT,
  CONSTRAINT caller_tool_confirmation_event_unique UNIQUE (tenant_id, call_session_id, confirmation_event_ref),
  CONSTRAINT caller_tool_confirmation_execution_unique UNIQUE (tenant_id, tool_execution_run_id),
  CONSTRAINT caller_tool_confirmation_lifetime_check CHECK (
    isfinite(issued_at) AND isfinite(expires_at) AND expires_at > issued_at
    AND expires_at <= issued_at + interval '5 minutes'
  ),
  CONSTRAINT caller_tool_confirmation_consumption_check CHECK (
    (consumed_at IS NULL AND tool_execution_run_id IS NULL)
    OR (consumed_at IS NOT NULL AND tool_execution_run_id IS NOT NULL
      AND consumed_at >= issued_at AND consumed_at < expires_at)
  ),
  CONSTRAINT caller_tool_confirmation_revocation_check CHECK (
    revoked_at IS NULL OR (isfinite(revoked_at) AND revoked_at >= issued_at AND consumed_at IS NULL)
  )
);
CREATE INDEX caller_tool_confirmation_session_idx
  ON public.caller_tool_confirmations(tenant_id, call_session_id, issued_at DESC);
CREATE INDEX caller_tool_confirmation_expiry_idx
  ON public.caller_tool_confirmations(expires_at);

CREATE FUNCTION public.caller_guard_tool_confirmation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  observed_now timestamptz := clock_timestamp();
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.consumed_at IS NOT NULL OR NEW.tool_execution_run_id IS NOT NULL OR NEW.revoked_at IS NOT NULL THEN
      RAISE EXCEPTION 'Confirmation must start unused' USING ERRCODE = '23514';
    END IF;
    NEW.issued_at := observed_now;
    IF NEW.expires_at <= observed_now THEN
      RAISE EXCEPTION 'Confirmation already expired' USING ERRCODE = '23514';
    END IF;
  ELSE
    IF ROW(NEW.id, NEW.public_id, NEW.tenant_id, NEW.call_session_id, NEW.tool_code,
      NEW.contract_version, NEW.intent_digest, NEW.token_hash, NEW.confirmation_event_ref,
      NEW.issued_at, NEW.expires_at) IS DISTINCT FROM
      ROW(OLD.id, OLD.public_id, OLD.tenant_id, OLD.call_session_id, OLD.tool_code,
      OLD.contract_version, OLD.intent_digest, OLD.token_hash, OLD.confirmation_event_ref,
      OLD.issued_at, OLD.expires_at) THEN
      RAISE EXCEPTION 'Confirmation identity and intent are immutable' USING ERRCODE = '23514';
    END IF;
    IF OLD.consumed_at IS NOT NULL OR OLD.revoked_at IS NOT NULL THEN
      IF ROW(NEW.consumed_at, NEW.tool_execution_run_id, NEW.revoked_at) IS DISTINCT FROM
        ROW(OLD.consumed_at, OLD.tool_execution_run_id, OLD.revoked_at) THEN
        RAISE EXCEPTION 'Confirmation terminal state is immutable' USING ERRCODE = '23514';
      END IF;
      RETURN NEW;
    END IF;
    IF NEW.tool_execution_run_id IS NOT NULL THEN
      IF observed_now >= OLD.expires_at OR NEW.revoked_at IS NOT NULL THEN
        RAISE EXCEPTION 'Confirmation expired or revoked' USING ERRCODE = '23514';
      END IF;
      NEW.consumed_at := observed_now;
    ELSIF NEW.consumed_at IS NOT NULL THEN
      RAISE EXCEPTION 'Confirmation consumption requires an execution' USING ERRCODE = '23514';
    END IF;
    IF NEW.revoked_at IS NOT NULL THEN
      NEW.revoked_at := observed_now;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER caller_tool_confirmation_guard BEFORE INSERT OR UPDATE
ON public.caller_tool_confirmations FOR EACH ROW EXECUTE FUNCTION public.caller_guard_tool_confirmation();
