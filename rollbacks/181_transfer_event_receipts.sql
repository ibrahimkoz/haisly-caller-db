SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_transfer_event_receipts) THEN RAISE EXCEPTION 'Cannot discard transfer evidence'; END IF;
END $$;
DROP TABLE public.caller_transfer_event_receipts;
DROP FUNCTION public.guard_caller_transfer_receipt();
