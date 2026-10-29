SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_transfer_failure_actions) THEN RAISE EXCEPTION 'Cannot discard transfer follow-up provenance'; END IF;
END $$;
DROP TABLE public.caller_transfer_failure_actions;
DROP FUNCTION public.guard_transfer_failure_action();
