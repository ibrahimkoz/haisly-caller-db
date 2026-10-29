SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_01_test_dispatch_ownership ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_dispatch_ownership();
