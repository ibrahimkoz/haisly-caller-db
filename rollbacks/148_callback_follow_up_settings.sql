SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_campaign_versions WHERE callback_team_id IS NOT NULL OR callback_due_business_days<>1) THEN RAISE EXCEPTION 'Rollback would lose callback follow-up configuration'; END IF; END $$;
DROP TRIGGER caller_callback_settings_guard ON public.caller_campaign_versions;
DROP FUNCTION public.guard_callback_follow_up_settings();
DROP INDEX public.caller_campaign_callback_team;
ALTER TABLE public.caller_campaign_versions DROP CONSTRAINT caller_callback_team_fk, DROP COLUMN callback_team_id, DROP COLUMN callback_due_business_days;
