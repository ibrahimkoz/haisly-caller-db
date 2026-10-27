SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_dispatch_intents IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents) THEN RAISE EXCEPTION 'Dispatch history exists; retain cost protection and use a forward fix.'; END IF;
END $$;
DROP TRIGGER caller_dispatch_release_guard ON public.billing_reservations;
DROP FUNCTION public.guard_submitted_dispatch_release();
