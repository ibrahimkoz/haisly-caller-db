SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_02_test_dispatch_contact ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_dispatch_contact();
