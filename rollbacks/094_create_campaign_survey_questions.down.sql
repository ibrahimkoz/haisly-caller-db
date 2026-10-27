SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_survey_questions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_questions) THEN
  RAISE EXCEPTION 'Survey questions exist; preserve authoring data and use a forward fix.';
 END IF;
END $$;
DROP TABLE public.caller_survey_questions;
