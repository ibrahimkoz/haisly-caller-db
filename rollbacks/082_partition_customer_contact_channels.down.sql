DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.customer_contacts cc JOIN public.customers c
 ON c.id=cc.customer_id AND c.tenant_id=cc.tenant_id WHERE cc.customer_identity_revision<>c.identity_revision) THEN
  RAISE EXCEPTION 'Historical contact channels exist; use a forward fix';
 END IF;
END $$;
DROP TRIGGER customer_contacts_snapshot_identity ON public.customer_contacts;
DROP FUNCTION public.snapshot_customer_contact_identity();
ALTER TABLE public.customer_contacts DROP CONSTRAINT customer_contacts_customer_contact_unique;
ALTER TABLE public.customer_contacts ADD CONSTRAINT customer_contacts_customer_contact_unique UNIQUE(customer_id,contact_type,normalized_value);
DROP INDEX public.customer_contacts_primary_per_type_unique_idx;
CREATE UNIQUE INDEX customer_contacts_primary_per_type_unique_idx ON public.customer_contacts(customer_id,contact_type) WHERE is_primary;
ALTER TABLE public.customer_contacts DROP COLUMN customer_identity_revision;
