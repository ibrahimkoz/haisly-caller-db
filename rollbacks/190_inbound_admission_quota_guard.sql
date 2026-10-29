SET LOCAL lock_timeout='5s';
DROP TRIGGER caller_inbound_greeting_admission_guard ON public.caller_inbound_greeting_pins;
DROP FUNCTION public.guard_inbound_admission_quota();
DROP TRIGGER caller_quota_configuration_lock ON public.quota_policies;
DROP FUNCTION public.lock_caller_quota_configuration();
