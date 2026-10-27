SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_sessions LIMIT 1) THEN
  RAISE EXCEPTION 'Survey sessions exist; use a forward fix instead of destructive rollback.';
 END IF;
END $$;
DROP TABLE public.caller_survey_answer_revisions;
DROP TABLE public.caller_survey_sessions;
DROP FUNCTION public.guard_caller_survey_answer_revision();
DROP FUNCTION public.guard_caller_survey_session();
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_target_snapshot_scope;
