SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_hubspot_oauth_states (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 integration_id bigint NOT NULL,
 actor_user_id bigint NOT NULL,
 session_id bigint NOT NULL,
 state_hash text NOT NULL UNIQUE CHECK(state_hash ~ '^[a-f0-9]{64}$'),
 configuration_hash text NOT NULL CHECK(configuration_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 FOREIGN KEY(integration_id,tenant_id) REFERENCES public.integrations(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(actor_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(session_id,tenant_id) REFERENCES public.sessions(id,tenant_id) ON DELETE RESTRICT,
 CHECK(expires_at>created_at AND expires_at<=created_at+interval '10 minutes')
);
CREATE INDEX caller_hubspot_oauth_states_expiry_idx ON public.caller_hubspot_oauth_states(expires_at);
CREATE FUNCTION public.guard_hubspot_oauth_state() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.created_at:=clock_timestamp(); NEW.expires_at:=NEW.created_at+interval '10 minutes';
  IF NEW.consumed_at IS NOT NULL THEN RAISE EXCEPTION 'OAuth state must start unused' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.integration_id,NEW.actor_user_id,NEW.session_id,NEW.state_hash,NEW.configuration_hash,NEW.created_at,NEW.expires_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.integration_id,OLD.actor_user_id,OLD.session_id,OLD.state_hash,OLD.configuration_hash,OLD.created_at,OLD.expires_at)
   OR OLD.consumed_at IS NOT NULL OR NEW.consumed_at IS NULL OR OLD.expires_at<=clock_timestamp() THEN
   RAISE EXCEPTION 'OAuth state is immutable, expired or already consumed' USING ERRCODE='23514'; END IF;
  NEW.consumed_at:=clock_timestamp();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sessions s WHERE s.id=NEW.session_id AND s.tenant_id=NEW.tenant_id AND s.user_id=NEW.actor_user_id
  AND s.status='active' AND s.revoked_at IS NULL AND s.expires_at>clock_timestamp()) THEN
  RAISE EXCEPTION 'OAuth state requires its active initiating session' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_oauth_state_guard BEFORE INSERT OR UPDATE ON public.caller_hubspot_oauth_states
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_oauth_state();
COMMENT ON TABLE public.caller_hubspot_oauth_states IS 'Short-lived session-bound OAuth CSRF state hashes. Raw state/code must not be logged. Commit consumption before token exchange. Not proof of provider ownership or connection readiness.';
