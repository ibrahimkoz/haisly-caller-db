SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_campaign_versions WHERE marketing_team_id IS NOT NULL OR marketing_due_business_days<>1 OR marketing_follow_up_mode<>'automatic') THEN RAISE EXCEPTION 'Rollback would lose marketing follow-up configuration'; END IF; END $$;
DROP TRIGGER caller_marketing_settings_guard ON public.caller_campaign_versions;
DROP FUNCTION public.guard_marketing_follow_up_settings();
DROP INDEX public.caller_campaign_marketing_team;
ALTER TABLE public.caller_campaign_versions DROP CONSTRAINT caller_marketing_team_fk, DROP COLUMN marketing_team_id, DROP COLUMN marketing_due_business_days, DROP COLUMN marketing_follow_up_mode;
