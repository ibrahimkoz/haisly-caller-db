-- Bounded historical reads: one latest-version seek per frozen survey question.
SET LOCAL lock_timeout = '5s';
CREATE INDEX caller_survey_revision_question_version_idx
 ON public.caller_survey_answer_revisions(tenant_id,session_id,question_key,recorded_version DESC);
