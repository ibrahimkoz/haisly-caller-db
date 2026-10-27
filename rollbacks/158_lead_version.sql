SET LOCAL lock_timeout = '5s';
DROP INDEX public.caller_lead_owner_read;
DROP TRIGGER caller_lead_version ON public.leads;
DROP FUNCTION public.bump_caller_lead_version();
ALTER TABLE public.leads DROP COLUMN version;
