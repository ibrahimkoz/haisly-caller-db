SET LOCAL lock_timeout='5s';
-- Stop provider event ingestion first. Never discard recorded evidence.
LOCK TABLE public.caller_test_dispatch_event_receipts IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_event_receipts) THEN
  RAISE EXCEPTION 'Test provider receipts exist; preserve history and roll forward'; END IF;
END $$;
DROP TABLE public.caller_test_dispatch_event_receipts;
DROP FUNCTION public.guard_test_dispatch_event_receipt();
