SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_marketing_interest_confirmations) THEN RAISE EXCEPTION 'Marketing confirmation history prevents rollback'; END IF; END $$;
DROP TABLE public.caller_marketing_interest_confirmations;
DROP FUNCTION public.guard_marketing_interest_confirmation();
