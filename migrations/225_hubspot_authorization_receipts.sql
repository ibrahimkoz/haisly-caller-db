SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_hubspot_oauth_states ADD CONSTRAINT caller_hubspot_oauth_states_id_tenant_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_hubspot_authorization_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 oauth_state_id bigint NOT NULL,
 connection_id bigint,
 outcome text NOT NULL CHECK(outcome IN ('issued','denied','uncertain','rejected','not_started')),
 reason text,
 required_scopes_satisfied boolean,
 result_hash text NOT NULL CHECK(result_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,oauth_state_id),
 FOREIGN KEY(oauth_state_id,tenant_id) REFERENCES public.caller_hubspot_oauth_states(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(connection_id,tenant_id) REFERENCES public.caller_hubspot_connections(id,tenant_id) ON DELETE RESTRICT,
 CHECK((outcome='issued' AND reason IS NULL AND connection_id IS NOT NULL AND required_scopes_satisfied IS NOT NULL)
  OR (outcome<>'issued' AND connection_id IS NULL AND required_scopes_satisfied IS NULL AND reason IS NOT NULL AND (
   (outcome='denied' AND reason IN ('access_denied','provider_error')) OR
   (outcome='uncertain' AND reason IN ('transport','http_response','invalid_response','account_mismatch')) OR
   (outcome='rejected' AND reason IN ('invalid_grant','invalid_client','invalid_scope','unauthorized_client','access_denied')) OR
   (outcome='not_started' AND reason IN ('disabled','not_configured','invalid_grant_input','aborted')))))
);
CREATE FUNCTION public.guard_hubspot_authorization_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE s public.caller_hubspot_oauth_states%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'OAuth authorization receipt is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO s FROM public.caller_hubspot_oauth_states WHERE id=NEW.oauth_state_id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND OR s.consumed_at IS NULL THEN RAISE EXCEPTION 'OAuth authorization requires consumed state' USING ERRCODE='23514'; END IF;
 IF NEW.outcome='issued' AND NOT EXISTS(SELECT 1 FROM public.caller_hubspot_connections c
   WHERE c.id=NEW.connection_id AND c.tenant_id=NEW.tenant_id AND c.integration_id=s.integration_id
   AND c.version=1 AND c.credential_revision=1 AND c.state='unverified') THEN
  RAISE EXCEPTION 'OAuth authorization requires initial unverified credentials' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_authorization_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_hubspot_authorization_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_authorization_receipt();
COMMENT ON TABLE public.caller_hubspot_authorization_receipts IS 'Immutable initial OAuth outcome. Issued tokens persist encrypted with the receipt; scope satisfaction alone never certifies account/subscription or activates CRM.';
