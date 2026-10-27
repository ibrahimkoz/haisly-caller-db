SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_survey_follow_up_rules) THEN
  RAISE EXCEPTION 'Refusing to discard configured campaign follow-up rules';
 END IF;
END $$;
DROP TABLE public.caller_campaign_survey_follow_up_rules;
DROP FUNCTION public.caller_guard_survey_follow_up_rule();
