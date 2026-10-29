SET LOCAL lock_timeout='5s';
CREATE TRIGGER caller_00_test_submission_phone BEFORE UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW WHEN (OLD.state='prepared' AND NEW.state='submitting')
 EXECUTE FUNCTION public.guard_shared_outbound_phone_admission();
CREATE TRIGGER caller_01_test_submission_cooldown BEFORE UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW WHEN (OLD.state='prepared' AND NEW.state='submitting')
 EXECUTE FUNCTION public.guard_test_dispatch_cooldown();
COMMENT ON TRIGGER caller_00_test_submission_phone ON public.caller_test_dispatch_intents IS 'Recheck open production and unresolved bound inbound calls immediately before first test submission.';
COMMENT ON TRIGGER caller_01_test_submission_cooldown ON public.caller_test_dispatch_intents IS 'Recheck known test5minute, production24hour and human inbound24hour cooldowns at first submission. Legacy/unbound history remains separate.';
