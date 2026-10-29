SET LOCAL lock_timeout='5s';
LOCK TABLE public.caller_test_dispatch_intents IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_intents) THEN RAISE EXCEPTION 'Test dispatch history must be preserved before rollback'; END IF;
END $$;
DROP TABLE public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_dispatch_intent();
