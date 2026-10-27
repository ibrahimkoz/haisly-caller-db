SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_action_reviews) THEN RAISE EXCEPTION 'Refusing to discard review history'; END IF;
END $$;
DROP TABLE public.caller_survey_action_reviews;
DROP FUNCTION public.caller_guard_survey_action_review();
