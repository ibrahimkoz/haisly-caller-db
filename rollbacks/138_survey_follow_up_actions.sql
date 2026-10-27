SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_follow_up_actions) THEN RAISE EXCEPTION 'Refusing to discard survey actions'; END IF;
END $$;
DROP TABLE public.caller_survey_follow_up_action_revisions;
DROP TABLE public.caller_survey_follow_up_actions;
DROP FUNCTION public.caller_guard_survey_action_revision();
DROP FUNCTION public.caller_guard_survey_action();
ALTER TABLE public.caller_survey_sessions DROP CONSTRAINT caller_survey_action_scope;
