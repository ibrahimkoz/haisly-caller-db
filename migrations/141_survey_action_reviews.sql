SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_survey_action_reviews (
 tenant_id bigint NOT NULL,
 action_id bigint NOT NULL,
 survey_version integer NOT NULL CHECK(survey_version>0),
 decision text NOT NULL CHECK(decision IN ('approved','rejected')),
 reviewer_user_id bigint NOT NULL,
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 10 AND 500),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,action_id,survey_version),
 FOREIGN KEY(tenant_id,action_id,survey_version) REFERENCES public.caller_survey_follow_up_action_revisions(tenant_id,action_id,survey_version) ON DELETE CASCADE,
 FOREIGN KEY(reviewer_user_id,tenant_id) REFERENCES public.tenant_memberships(user_id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.caller_guard_survey_action_review() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'Survey review history is immutable' USING ERRCODE='23514'; END IF;
 PERFORM a.id FROM public.caller_survey_follow_up_actions a
 JOIN public.caller_survey_sessions s ON s.id=a.survey_id AND s.tenant_id=a.tenant_id
 WHERE a.id=NEW.action_id AND a.tenant_id=NEW.tenant_id AND a.last_survey_version=NEW.survey_version
 AND s.version=NEW.survey_version AND a.decision='review' AND a.follow_up_task_id IS NULL FOR UPDATE OF a FOR SHARE OF s;
 IF NOT FOUND THEN RAISE EXCEPTION 'Review requires a current pending action' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_survey_review_guard BEFORE INSERT OR UPDATE ON public.caller_survey_action_reviews
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_survey_action_review();
