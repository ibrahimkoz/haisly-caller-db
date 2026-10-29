SET LOCAL lock_timeout='5s';
LOCK TABLE public.caller_test_otp_deliveries IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_otp_deliveries) THEN RAISE EXCEPTION 'OTP delivery history exists; roll forward'; END IF;
END $$;
DROP TABLE public.caller_test_otp_deliveries;
DROP FUNCTION public.guard_test_otp_delivery();
ALTER TABLE public.caller_test_number_challenges DROP CONSTRAINT caller_test_number_challenge_id_tenant_unique;
