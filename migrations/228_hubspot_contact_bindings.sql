SET LOCAL lock_timeout='5s';
-- HubSpot record IDs are scoped to a portal. Connection identity already binds
-- an immutable portal; retain that namespace in uniqueness across integrations.
ALTER TABLE public.caller_hubspot_connections
 ADD CONSTRAINT caller_hubspot_connection_account_key UNIQUE(id,tenant_id,hub_id);
CREATE TABLE public.caller_hubspot_contact_bindings (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 connection_id bigint NOT NULL,
 hub_id bigint NOT NULL,
 external_contact_id text NOT NULL CHECK(external_contact_id ~ '^[1-9][0-9]{0,99}$'),
 customer_id bigint NOT NULL,
 customer_identity_revision integer NOT NULL CHECK(customer_identity_revision>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,hub_id,external_contact_id),
 UNIQUE(tenant_id,hub_id,customer_id),
 FOREIGN KEY(connection_id,tenant_id,hub_id)
  REFERENCES public.caller_hubspot_connections(id,tenant_id,hub_id) ON DELETE RESTRICT,
 FOREIGN KEY(customer_id,tenant_id) REFERENCES public.customers(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_hubspot_contact_binding_connection_idx
 ON public.caller_hubspot_contact_bindings(tenant_id,connection_id,id);
CREATE FUNCTION public.guard_hubspot_contact_binding() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE revision integer;
BEGIN
 IF TG_OP='UPDATE' THEN
  RAISE EXCEPTION 'HubSpot contact identity binding is immutable' USING ERRCODE='23514';
 END IF;
 SELECT identity_revision INTO revision FROM public.customers
  WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF revision IS NULL OR revision<>NEW.customer_identity_revision THEN
  RAISE EXCEPTION 'HubSpot contact binding requires current tenant contact identity' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_hubspot_contact_binding_guard
 BEFORE INSERT OR UPDATE ON public.caller_hubspot_contact_bindings
 FOR EACH ROW EXECUTE FUNCTION public.guard_hubspot_contact_binding();
COMMENT ON TABLE public.caller_hubspot_contact_bindings IS
 'Stable tenant/HubSpot portal/contact identity. Duplicate external records for one local contact require conflict review; never silently merge. Binding does not grant call consent or enroll campaign targets. Import must recheck the captured customer identity revision. Explicit erasure cleanup may delete bindings.';
