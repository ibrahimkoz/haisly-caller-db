SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_00_test_submission_phone ON public.caller_test_dispatch_intents;
DROP TRIGGER caller_01_test_submission_cooldown ON public.caller_test_dispatch_intents;
