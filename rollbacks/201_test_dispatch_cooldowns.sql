SET LOCAL lock_timeout='5s';
-- Stop test admissions before removing the preparation cooldown guard.
DROP TRIGGER caller_01_test_cooldown_guard ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_dispatch_cooldown();
