SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_025_test_submission_capacity_policy ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_submission_capacity_policy();
