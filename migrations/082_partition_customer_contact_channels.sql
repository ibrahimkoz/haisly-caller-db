SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
ALTER TABLE public.customer_contacts ADD COLUMN customer_identity_revision integer;
UPDATE public.customer_contacts cc SET customer_identity_revision=c.identity_revision
FROM public.customers c WHERE c.id=cc.customer_id AND c.tenant_id=cc.tenant_id;
ALTER TABLE public.customer_contacts ALTER COLUMN customer_identity_revision SET NOT NULL;
ALTER TABLE public.customer_contacts ADD CONSTRAINT customer_contacts_revision_positive CHECK(customer_identity_revision>0);
ALTER TABLE public.customer_contacts DROP CONSTRAINT customer_contacts_customer_contact_unique;
ALTER TABLE public.customer_contacts ADD CONSTRAINT customer_contacts_customer_contact_unique
 UNIQUE(customer_id,customer_identity_revision,contact_type,normalized_value);
DROP INDEX public.customer_contacts_primary_per_type_unique_idx;
CREATE UNIQUE INDEX customer_contacts_primary_per_type_unique_idx
 ON public.customer_contacts(customer_id,customer_identity_revision,contact_type) WHERE is_primary;

CREATE FUNCTION public.snapshot_customer_contact_identity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE current_revision integer;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF (NEW.tenant_id,NEW.customer_id,NEW.customer_identity_revision) IS DISTINCT FROM
     (OLD.tenant_id,OLD.customer_id,OLD.customer_identity_revision) THEN
   RAISE EXCEPTION 'Contact channel identity is immutable' USING ERRCODE='23514', CONSTRAINT='caller_history_identity_guard';
  END IF;
 END IF;
 SELECT identity_revision INTO STRICT current_revision FROM public.customers
 WHERE tenant_id=NEW.tenant_id AND id=NEW.customer_id FOR SHARE;
 IF NEW.customer_identity_revision IS NOT NULL AND NEW.customer_identity_revision<>current_revision THEN
  RAISE EXCEPTION 'Historical contact channel cannot be changed or reassigned' USING ERRCODE='23514', CONSTRAINT='caller_history_identity_guard';
 END IF;
 NEW.customer_identity_revision:=current_revision;
 RETURN NEW;
END $$;
CREATE TRIGGER customer_contacts_snapshot_identity BEFORE INSERT OR UPDATE ON public.customer_contacts
 FOR EACH ROW EXECUTE FUNCTION public.snapshot_customer_contact_identity();
