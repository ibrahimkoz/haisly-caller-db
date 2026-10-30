DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_authorization_receipts) THEN RAISE EXCEPTION 'Refusing to discard OAuth authorization receipts'; END IF;
END $$;
DROP TABLE public.caller_hubspot_authorization_receipts;
DROP FUNCTION public.guard_hubspot_authorization_receipt();
ALTER TABLE public.caller_hubspot_oauth_states DROP CONSTRAINT caller_hubspot_oauth_states_id_tenant_unique;
