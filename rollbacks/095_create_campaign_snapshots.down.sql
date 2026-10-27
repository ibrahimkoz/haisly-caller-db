SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_snapshots IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_snapshots) THEN
  RAISE EXCEPTION 'Campaign snapshots exist; preserve history and use a forward fix.';
 END IF;
END $$;
DROP TABLE public.caller_campaign_snapshots;
DROP FUNCTION public.reject_caller_campaign_snapshot_mutation();
