-- HubSpot is no longer part of Caller. Back up before applying.
-- Keep generic integration/audit history and all native contacts, leads and tasks.
SET LOCAL lock_timeout = '5s';

UPDATE public.automation_rules SET status = 'disabled', updated_at = now()
WHERE integration_id IN (SELECT id FROM public.integrations WHERE lower(btrim(provider)) = 'hubspot');
UPDATE public.integration_mappings SET status = 'inactive', updated_at = now()
WHERE integration_id IN (SELECT id FROM public.integrations WHERE lower(btrim(provider)) = 'hubspot');
UPDATE public.integrations SET status = 'disabled', configuration = '{}'::jsonb,
  credentials_ref = NULL, updated_at = now()
WHERE lower(btrim(provider)) = 'hubspot';

DROP TABLE public.caller_hubspot_contact_conflicts;
DROP TABLE public.caller_hubspot_contact_bindings;
DROP TABLE public.caller_hubspot_authorization_receipts;
DROP TABLE public.caller_hubspot_oauth_states;
DROP TABLE public.caller_hubspot_refresh_receipts;
DROP TABLE public.caller_hubspot_refresh_intents;
DROP TABLE public.caller_hubspot_connections;

DROP FUNCTION public.guard_hubspot_contact_conflict();
DROP FUNCTION public.guard_hubspot_contact_binding();
DROP FUNCTION public.guard_hubspot_authorization_receipt();
DROP FUNCTION public.guard_hubspot_oauth_state();
DROP FUNCTION public.guard_hubspot_refresh_receipt();
DROP FUNCTION public.guard_hubspot_refresh_intent();
DROP FUNCTION public.guard_hubspot_connection_credentials();

DELETE FROM public.provider_credentials WHERE lower(btrim(provider)) = 'hubspot';
