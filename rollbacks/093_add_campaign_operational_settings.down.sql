SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_versions) THEN
  RAISE EXCEPTION 'Campaign versions exist; preserve operational settings and use a forward fix.';
 END IF;
END $$;
ALTER TABLE public.caller_campaign_versions
 DROP COLUMN agent_config_version_id, DROP COLUMN max_call_minutes,
 DROP COLUMN requested_concurrency, DROP COLUMN max_attempts,
 DROP COLUMN window_end_minute, DROP COLUMN window_start_minute,
 DROP COLUMN weekday_mask, DROP COLUMN ends_at, DROP COLUMN starts_at, DROP COLUMN timezone;
