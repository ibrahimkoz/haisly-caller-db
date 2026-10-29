SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_phone_suppression_events) THEN
 RAISE EXCEPTION 'Cannot rollback retained phone suppression history'; END IF; END $$;
DROP TABLE public.caller_phone_suppression_events;
DROP FUNCTION public.guard_phone_suppression_event();
