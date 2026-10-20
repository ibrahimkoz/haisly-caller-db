DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.customers WHERE canonical_phone IS NOT NULL) THEN
   RAISE EXCEPTION 'Canonical identities exist; do not remove their legacy-write guard';
 END IF;
END $$;
DROP TRIGGER customer_contacts_guard_canonical_identity ON public.customer_contacts;
DROP TRIGGER customers_guard_canonical_identity ON public.customers;
DROP FUNCTION public.guard_canonical_contact_identity();
DROP INDEX public.customer_contacts_canonical_claim_idx;
DROP INDEX public.customers_primary_phone_claim_idx;
