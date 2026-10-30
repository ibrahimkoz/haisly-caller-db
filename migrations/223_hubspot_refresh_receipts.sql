SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_hubspot_refresh_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 refresh_intent_id bigint NOT NULL,
 outcome text NOT NULL CHECK(outcome IN ('issued','uncertain','rejected','not_started')),
 reason text,
 result_hash text NOT NULL CHECK(result_hash ~ '^[a-f0-9]{64}$'),
 connection_version integer NOT NULL CHECK(connection_version>0),
 credential_revision integer NOT NULL CHECK(credential_revision>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,refresh_intent_id),
 FOREIGN KEY(refresh_intent_id,tenant_id) REFERENCES public.caller_hubspot_refresh_intents(id,tenant_id) ON DELETE RESTRICT,
 CHECK((outcome='issued' AND reason IS NULL)
  OR (outcome='uncertain' AND reason IS NOT NULL AND reason IN ('transport','http_response','invalid_response','account_mismatch'))
  OR (outcome='rejected' AND reason IS NOT NULL AND reason IN ('invalid_grant','invalid_client','invalid_scope','unauthorized_client','access_denied'))
  OR (outcome='not_started' AND reason IS NOT NULL AND reason IN ('disabled','not_configured','invalid_grant_input','aborted')))
);
CREATE FUNCTION public.guard_hubspot_refresh_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE i public.caller_hubspot_refresh_intents%ROWTYPE; c public.caller_hubspot_connections%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'HubSpot refresh receipt is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO i FROM public.caller_hubspot_refresh_intents WHERE id=NEW.refresh_intent_id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'HubSpot refresh intent missing' USING ERRCODE='23514'; END IF;
 SELECT * INTO c FROM public.caller_hubspot_connections WHERE id=i.connection_id AND tenant_id=i.tenant_id;
 IF NOT FOUND OR NEW.connection_version::bigint<>i.connection_version::bigint+1 OR c.version<>NEW.connection_version
  OR c.credential_revision<>NEW.credential_revision THEN
  RAISE EXCEPTION 'HubSpot refresh receipt revision mismatch' USING ERRCODE='23514'; END IF;
 IF NEW.outcome='issued' THEN
  IF NEW.credential_revision::bigint<>i.credential_revision::bigint+1 OR c.state<>'unverified' THEN
   RAISE EXCEPTION 'Issued HubSpot tokens require persisted unverified revision' USING ERRCODE='23514'; END IF;
 ELSE
  IF NEW.credential_revision<>i.credential_revision OR c.state<>'reconnect_required' THEN
   RAISE EXCEPTION 'Unsuccessful HubSpot refresh requires reconnection' USING ERRCODE='23514'; END IF;
 END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_refresh_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_hubspot_refresh_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_refresh_receipt();
COMMENT ON TABLE public.caller_hubspot_refresh_receipts IS 'Immutable normalized refresh outcome, atomically linked to applied connection revision. Secret-bearing reply fingerprint is internal only; plaintext tokens never stored here.';
