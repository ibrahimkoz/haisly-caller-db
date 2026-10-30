SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_contact_bindings) THEN
  RAISE EXCEPTION 'Preserve CRM identity bindings; roll back application instead of removing populated schema';
 END IF;
END $$;
DROP TABLE public.caller_hubspot_contact_bindings;
DROP FUNCTION public.guard_hubspot_contact_binding();
ALTER TABLE public.caller_hubspot_connections DROP CONSTRAINT caller_hubspot_connection_account_key;
