SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_refresh_receipts) THEN
  RAISE EXCEPTION 'Cannot discard HubSpot refresh receipts; retain evidence and roll back application only';
 END IF;
END $$;
DROP TABLE public.caller_hubspot_refresh_receipts;
DROP FUNCTION public.guard_hubspot_refresh_receipt();
