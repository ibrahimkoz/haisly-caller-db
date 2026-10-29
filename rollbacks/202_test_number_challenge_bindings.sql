SET LOCAL lock_timeout='5s';
LOCK TABLE public.caller_test_number_challenges,public.otp_challenges IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_number_challenges) OR EXISTS(SELECT 1 FROM public.otp_challenges WHERE purpose='caller_test_number') THEN
  RAISE EXCEPTION 'Test ownership challenge history exists; roll forward'; END IF;
END $$;
DROP TRIGGER caller_test_bound_otp_guard ON public.otp_challenges;
DROP FUNCTION public.guard_bound_test_otp();
DROP TABLE public.caller_test_number_challenges;
DROP FUNCTION public.guard_test_number_challenge();
ALTER TABLE public.otp_challenges DROP CONSTRAINT otp_challenges_id_tenant_unique;
ALTER TABLE public.otp_challenges DROP CONSTRAINT otp_challenges_purpose_check;
ALTER TABLE public.otp_challenges ADD CONSTRAINT otp_challenges_purpose_check CHECK(purpose IN ('login_mfa','email_verification','password_reset','phone_verification'));
