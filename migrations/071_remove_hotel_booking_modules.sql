-- Outbound caller no longer serves hotel inventory/reservation APIs.
-- Back up before applying: dropped rows can only be recovered from a backup.
-- Retain shared integration history, but stop its automation and credentials.
UPDATE public.automation_rules
SET status = 'disabled', updated_at = now()
WHERE integration_id IN (SELECT id FROM public.integrations WHERE lower(provider) = 'hotelrunner');

UPDATE public.integration_mappings
SET status = 'inactive', updated_at = now()
WHERE integration_id IN (SELECT id FROM public.integrations WHERE lower(provider) = 'hotelrunner');

UPDATE public.integrations
SET status = 'disabled', updated_at = now()
WHERE lower(provider) = 'hotelrunner';

UPDATE public.provider_credentials
SET status = 'disabled', updated_at = now()
WHERE lower(provider) = 'hotelrunner';

DROP TABLE public.booking_reservation_requests;
DROP TABLE public.hotelrunner_reservation_outbox;
DROP TABLE public.resource_availability;
DROP TABLE public.resource_offers;
DROP TABLE public.bookable_resources;
DROP TABLE IF EXISTS public.hotelrunner_webhook_debug_logs;
