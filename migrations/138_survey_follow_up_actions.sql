SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_survey_sessions ADD CONSTRAINT caller_survey_action_scope UNIQUE(id,target_id,snapshot_id,tenant_id);
CREATE TABLE public.caller_survey_follow_up_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 survey_id bigint NOT NULL,
 target_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 question_key text NOT NULL CHECK(question_key ~ '^[A-Za-z][A-Za-z0-9_-]{0,63}$'),
 team_id bigint NOT NULL,
 follow_up_task_id bigint,
 last_survey_version integer NOT NULL CHECK(last_survey_version>0),
 decision text NOT NULL CHECK(decision IN ('automatic_task','review','identity_unavailable','declined','unanswered','skipped','above_threshold')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id),
 UNIQUE(tenant_id,target_id,snapshot_id,question_key),
 UNIQUE(tenant_id,follow_up_task_id),
 FOREIGN KEY(survey_id,target_id,snapshot_id,tenant_id) REFERENCES public.caller_survey_sessions(id,target_id,snapshot_id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(follow_up_task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_survey_action_pending_idx ON public.caller_survey_follow_up_actions(tenant_id,decision,id) WHERE follow_up_task_id IS NULL;
CREATE TABLE public.caller_survey_follow_up_action_revisions (
 tenant_id bigint NOT NULL,
 action_id bigint NOT NULL,
 survey_version integer NOT NULL CHECK(survey_version>0),
 decision text NOT NULL CHECK(decision IN ('automatic_task','review','identity_unavailable','declined','unanswered','skipped','above_threshold')),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,action_id,survey_version),
 FOREIGN KEY(action_id,tenant_id) REFERENCES public.caller_survey_follow_up_actions(id,tenant_id) ON DELETE CASCADE
);
CREATE FUNCTION public.caller_guard_survey_action() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.survey_id,NEW.target_id,NEW.snapshot_id,NEW.question_key,NEW.team_id,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.survey_id,OLD.target_id,OLD.snapshot_id,OLD.question_key,OLD.team_id,OLD.created_at) THEN
   RAISE EXCEPTION 'Survey action identity is immutable' USING ERRCODE='23514';
  END IF;
  IF NEW.last_survey_version<OLD.last_survey_version OR (NEW.last_survey_version=OLD.last_survey_version AND NEW.decision<>OLD.decision) THEN
   RAISE EXCEPTION 'Survey action decision version must advance' USING ERRCODE='23514';
  END IF;
  IF OLD.follow_up_task_id IS NOT NULL AND NEW.follow_up_task_id IS DISTINCT FROM OLD.follow_up_task_id THEN
   RAISE EXCEPTION 'Survey action task cannot be replaced' USING ERRCODE='23514';
  END IF;
 END IF;
 PERFORM s.id FROM public.caller_survey_sessions s
 WHERE s.id=NEW.survey_id AND s.tenant_id=NEW.tenant_id AND s.version>=NEW.last_survey_version FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Survey action version exceeds survey history' USING ERRCODE='23514'; END IF;
 NEW.updated_at := clock_timestamp();
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_action_guard BEFORE INSERT OR UPDATE ON public.caller_survey_follow_up_actions
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_survey_action();
CREATE FUNCTION public.caller_guard_survey_action_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'Survey action history is immutable' USING ERRCODE='23514'; END IF;
 PERFORM id FROM public.caller_survey_follow_up_actions WHERE id=NEW.action_id AND tenant_id=NEW.tenant_id
  AND last_survey_version=NEW.survey_version AND decision=NEW.decision FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Survey action history must match current decision' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_action_revision_guard BEFORE INSERT OR UPDATE ON public.caller_survey_follow_up_action_revisions
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_survey_action_revision();
