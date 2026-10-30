SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_hubspot_contact_conflicts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 connection_id bigint NOT NULL,
 external_contact_id text NOT NULL CHECK(external_contact_id ~ '^[1-9][0-9]{0,99}$'),
 source_updated_at timestamptz NOT NULL CHECK(isfinite(source_updated_at)),
 customer_id bigint NOT NULL,
 customer_identity_revision integer NOT NULL CHECK(customer_identity_revision>0),
 reason text NOT NULL CHECK(reason IN ('contact_unavailable','identity_conflict','phone_conflict','duplicate_local_contact','external_identity_conflict','connection_conflict')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved','dismissed')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 resolved_by_user_id bigint,
 resolution_reason text CHECK(resolution_reason IS NULL OR length(btrim(resolution_reason)) BETWEEN 1 AND 1000),
 resolved_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,connection_id,external_contact_id,source_updated_at,customer_id,customer_identity_revision,reason),
 FOREIGN KEY(connection_id,tenant_id) REFERENCES public.caller_hubspot_connections(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(customer_id,tenant_id) REFERENCES public.customers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(resolved_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 CHECK((status='open' AND resolved_by_user_id IS NULL AND resolution_reason IS NULL AND resolved_at IS NULL)
  OR (status<>'open' AND resolved_by_user_id IS NOT NULL AND resolution_reason IS NOT NULL AND resolved_at IS NOT NULL))
);
CREATE INDEX caller_hubspot_contact_conflict_queue_idx
 ON public.caller_hubspot_contact_conflicts(tenant_id,status,id);
CREATE FUNCTION public.guard_hubspot_contact_conflict() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.status<>'open' OR NEW.version<>1 THEN
   RAISE EXCEPTION 'HubSpot contact conflict must start open at version one' USING ERRCODE='23514'; END IF;
  NEW.created_at:=clock_timestamp();
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.connection_id,NEW.external_contact_id,NEW.source_updated_at,
      NEW.customer_id,NEW.customer_identity_revision,NEW.reason,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.connection_id,OLD.external_contact_id,OLD.source_updated_at,
      OLD.customer_id,OLD.customer_identity_revision,OLD.reason,OLD.created_at)
   OR OLD.status<>'open' OR NEW.status='open' OR NEW.version::bigint<>OLD.version::bigint+1 THEN
   RAISE EXCEPTION 'HubSpot conflict resolution must preserve evidence and close once' USING ERRCODE='23514'; END IF;
  NEW.resolved_at:=clock_timestamp();
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_contact_conflict_guard BEFORE INSERT OR UPDATE ON public.caller_hubspot_contact_conflicts
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_contact_conflict();
COMMENT ON TABLE public.caller_hubspot_contact_conflicts IS
 'Deduplicated CRM identity conflict observations. Contains references, not copied phone/name/token payloads. Resolution requires a separate authorized transaction; status alone must not rebind identities or clear DNC. Replaying a closed observation does not reopen it.';
