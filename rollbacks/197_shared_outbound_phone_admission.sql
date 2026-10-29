SET LOCAL lock_timeout='5s';
-- Stop all outbound admissions before removing this cross-source safety gate.
DROP TRIGGER caller_00_phone_admission_guard ON public.caller_test_dispatch_intents;
DROP TRIGGER caller_00_phone_admission_guard ON public.caller_dispatch_intents;
DROP FUNCTION public.guard_shared_outbound_phone_admission();
