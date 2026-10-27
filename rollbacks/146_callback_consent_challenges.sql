SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_callback_consent_challenges) THEN RAISE EXCEPTION 'Rollback would delete callback consent evidence'; END IF;
END $$;
DROP TABLE public.caller_callback_consent_challenges;
DROP FUNCTION public.guard_callback_consent_challenge();
