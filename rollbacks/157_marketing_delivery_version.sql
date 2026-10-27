SET LOCAL lock_timeout = '5s';
DROP INDEX public.caller_marketing_delivery_failures;
DROP TRIGGER marketing_delivery_version ON public.caller_marketing_action_deliveries;
DROP FUNCTION public.bump_marketing_delivery_version();
ALTER TABLE public.caller_marketing_action_deliveries DROP COLUMN version;
