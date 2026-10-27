SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_snapshots IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_snapshots WHERE content_compilation_snapshot IS NOT NULL) THEN
  RAISE EXCEPTION 'Stored compilation artifacts exist; use a forward fix.';
 END IF;
END $$;
ALTER TABLE public.caller_campaign_snapshots
 DROP CONSTRAINT caller_snapshot_compilation_check, DROP COLUMN content_compilation_snapshot;
