SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_dispatch_event_receipts IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_event_receipts) THEN RAISE EXCEPTION 'Dispatch event receipts exist; use a forward fix.'; END IF;
END $$;
DROP TABLE public.caller_dispatch_event_receipts;
DROP FUNCTION public.guard_dispatch_event_receipt();
