SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_hubspot_refresh_intents (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 connection_id bigint NOT NULL,
 connection_version integer NOT NULL CHECK(connection_version>0),
 credential_revision integer NOT NULL CHECK(credential_revision>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,connection_id,credential_revision),
 FOREIGN KEY(connection_id,tenant_id) REFERENCES public.caller_hubspot_connections(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_hubspot_refresh_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE c public.caller_hubspot_connections%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'HubSpot refresh intent is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO c FROM public.caller_hubspot_connections WHERE id=NEW.connection_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR c.version<>NEW.connection_version OR c.credential_revision<>NEW.credential_revision OR c.state<>'unverified' THEN
  RAISE EXCEPTION 'HubSpot refresh intent requires the current usable connection revision' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.integrations i WHERE i.id=c.integration_id AND i.tenant_id=c.tenant_id
  AND lower(btrim(i.provider))='hubspot' AND i.status<>'disabled')
 OR NOT EXISTS(SELECT 1 FROM public.provider_credentials p WHERE p.id=c.provider_credential_id AND p.tenant_id=c.tenant_id
  AND p.provider='hubspot' AND p.status IN ('active','disabled') AND p.encryption_key_version ~ '^v2:[A-Za-z0-9_-]{1,64}$') THEN
  RAISE EXCEPTION 'HubSpot refresh intent scope is unavailable' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_refresh_intent_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_hubspot_refresh_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_refresh_intent();
COMMENT ON TABLE public.caller_hubspot_refresh_intents IS 'Durable single-send marker per credential revision. Commit before token POST. Missing response never permits automatic resend; retain for recovery.';
