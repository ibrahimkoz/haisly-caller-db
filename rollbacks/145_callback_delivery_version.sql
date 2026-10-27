SET LOCAL lock_timeout = '5s';
DROP INDEX public.caller_callback_expiration_scan;
DROP TRIGGER callback_delivery_version ON public.caller_callback_expiration_deliveries;
DROP FUNCTION public.bump_callback_delivery_version();
ALTER TABLE public.caller_callback_expiration_deliveries DROP COLUMN version;
