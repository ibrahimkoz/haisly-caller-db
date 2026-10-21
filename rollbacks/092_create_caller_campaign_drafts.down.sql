SET LOCAL lock_timeout = '5s';
-- Do not silently discard authored customer content during rollback.
LOCK TABLE public.caller_campaigns IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.caller_campaigns) THEN
  RAISE EXCEPTION 'Campaign drafts exist; preserve data and use a forward fix.';
 END IF;
END $$;
DROP TABLE public.caller_campaign_source_lists;
DROP TABLE public.caller_campaign_versions;
DROP TABLE public.caller_campaigns;
