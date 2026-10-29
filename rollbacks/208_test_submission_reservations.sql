SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_03_test_submission_reservations ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_submission_reservations();
