SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_provider_receipts) THEN RAISE EXCEPTION 'Cannot drop recorded quality provider receipts'; END IF;
END $$;
DROP TABLE public.caller_quality_provider_receipts;
DROP FUNCTION public.guard_quality_provider_receipt();
