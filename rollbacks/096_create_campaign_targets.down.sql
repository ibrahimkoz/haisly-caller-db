SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_targets,public.caller_campaign_target_sources IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_targets) THEN
  RAISE EXCEPTION 'Campaign targets exist; preserve history and use a forward fix.';
 END IF;
END $$;
DROP TABLE public.caller_campaign_target_sources;
DROP TABLE public.caller_campaign_targets;
DROP FUNCTION public.guard_caller_campaign_target_source();
DROP FUNCTION public.guard_caller_campaign_target();
ALTER TABLE public.caller_campaign_snapshots DROP CONSTRAINT caller_campaign_snapshot_scope;
