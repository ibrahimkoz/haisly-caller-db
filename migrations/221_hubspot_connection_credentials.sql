SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_hubspot_connections (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 integration_id bigint NOT NULL,
 provider_credential_id bigint NOT NULL,
 hub_id bigint NOT NULL CHECK(hub_id BETWEEN 1 AND 9007199254740991),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 credential_revision integer NOT NULL DEFAULT 1 CHECK(credential_revision>0),
 state text NOT NULL DEFAULT 'unverified' CHECK(state IN ('unverified','reconnect_required','disconnected')),
 token_expires_at timestamptz NOT NULL,
 scopes jsonb NOT NULL CHECK(jsonb_typeof(scopes)='array' AND octet_length(scopes::text)<=65536),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,integration_id), UNIQUE(tenant_id,provider_credential_id),
 FOREIGN KEY(integration_id,tenant_id) REFERENCES public.integrations(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_credential_id,tenant_id) REFERENCES public.provider_credentials(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_hubspot_connection_credentials() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE scope jsonb;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.version<>1 OR NEW.credential_revision<>1 OR NEW.state<>'unverified' THEN
   RAISE EXCEPTION 'HubSpot connection must start unverified at revision one' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.integration_id,NEW.provider_credential_id,NEW.hub_id,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.integration_id,OLD.provider_credential_id,OLD.hub_id,OLD.created_at) THEN
   RAISE EXCEPTION 'HubSpot connection identity is immutable' USING ERRCODE='23514'; END IF;
  IF NEW.version::bigint<>OLD.version::bigint+1 OR NEW.credential_revision::bigint NOT IN (OLD.credential_revision::bigint,OLD.credential_revision::bigint+1) THEN
   RAISE EXCEPTION 'HubSpot connection revision must advance sequentially' USING ERRCODE='23514'; END IF;
  IF (NEW.token_expires_at,NEW.scopes) IS DISTINCT FROM (OLD.token_expires_at,OLD.scopes) AND NEW.credential_revision=OLD.credential_revision THEN
   RAISE EXCEPTION 'HubSpot token metadata requires a credential revision' USING ERRCODE='23514'; END IF;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.integrations i WHERE i.id=NEW.integration_id AND i.tenant_id=NEW.tenant_id AND lower(btrim(i.provider))='hubspot')
 OR NOT EXISTS(SELECT 1 FROM public.provider_credentials p WHERE p.id=NEW.provider_credential_id AND p.tenant_id=NEW.tenant_id AND p.provider='hubspot'
  AND p.encryption_key_version ~ '^v2:[A-Za-z0-9_-]{1,64}$') THEN
  RAISE EXCEPTION 'HubSpot connection requires matching bound credentials and integration' USING ERRCODE='23514'; END IF;
 IF jsonb_array_length(NEW.scopes)>256 THEN RAISE EXCEPTION 'Too many HubSpot scopes' USING ERRCODE='23514'; END IF;
 FOR scope IN SELECT value FROM jsonb_array_elements(NEW.scopes) LOOP
  IF jsonb_typeof(scope)<>'string' OR NOT ((scope#>>'{}') ~ '^[A-Za-z0-9_.:-]{1,200}$') THEN
   RAISE EXCEPTION 'Invalid HubSpot scope' USING ERRCODE='23514'; END IF;
 END LOOP;
 NEW.updated_at:=clock_timestamp();
 IF TG_OP='INSERT' THEN NEW.created_at:=NEW.updated_at; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_connection_guard BEFORE INSERT OR UPDATE ON public.caller_hubspot_connections
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_connection_credentials();
COMMENT ON TABLE public.caller_hubspot_connections IS 'Tenant-bound OAuth credential metadata. Unverified tokens do not activate integration or CRM sync. Secrets remain only in provider_credentials ciphertext.';
