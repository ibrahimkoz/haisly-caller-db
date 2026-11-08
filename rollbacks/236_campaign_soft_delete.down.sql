SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_deletions) THEN
  RAISE EXCEPTION 'Restore a reviewed backup to reverse campaign deletion history; rollback must not silently restore deleted campaigns';
 END IF;
END $$;
DROP TABLE public.caller_campaign_deletions;
DROP FUNCTION public.guard_campaign_deletion();
