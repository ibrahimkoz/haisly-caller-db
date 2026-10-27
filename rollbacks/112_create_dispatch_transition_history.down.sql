SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_dispatch_intents IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.caller_dispatch_transitions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_transitions) THEN RAISE EXCEPTION 'Dispatch transition history exists; use a forward fix.'; END IF;
END $$;
DROP TRIGGER caller_dispatch_history ON public.caller_dispatch_intents;
DROP FUNCTION public.record_dispatch_transition();
DROP TABLE public.caller_dispatch_transitions;
DROP FUNCTION public.guard_dispatch_transition_history();
