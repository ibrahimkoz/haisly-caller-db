SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_target_snapshot_scope UNIQUE(id,snapshot_id,tenant_id);
CREATE TABLE public.caller_survey_sessions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 target_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 revision_count integer NOT NULL DEFAULT 0 CHECK(revision_count>=0),
 state text NOT NULL DEFAULT 'active' CHECK(state IN ('active','partial','completed','declined')),
 clarified_questions jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(clarified_questions)='array' AND jsonb_array_length(clarified_questions)<=100),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id), UNIQUE(target_id,tenant_id),
 FOREIGN KEY(target_id,snapshot_id,tenant_id) REFERENCES public.caller_campaign_targets(id,snapshot_id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_survey_sessions_tenant_idx ON public.caller_survey_sessions(tenant_id,public_id);
CREATE TABLE public.caller_survey_answer_revisions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL,
 session_id bigint NOT NULL,
 sequence integer NOT NULL CHECK(sequence>0),
 question_key text NOT NULL CHECK(question_key ~ '^[A-Za-z][A-Za-z0-9_-]{0,63}$'),
 answer jsonb NOT NULL CHECK(jsonb_typeof(answer)='object' AND octet_length(answer::text)<=65536),
 recorded_version integer NOT NULL CHECK(recorded_version>1),
 invalidated_version integer,
 disposition text NOT NULL CHECK(disposition IN ('active','superseded','dependency_changed')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(session_id,sequence),
 CHECK((disposition='active' AND invalidated_version IS NULL) OR (disposition<>'active' AND invalidated_version>recorded_version)),
 CHECK(COALESCE((answer->>'status'='skipped' AND NOT answer ? 'value') OR (answer->>'status'='answered' AND answer ? 'value' AND jsonb_typeof(answer->'value') IN ('string','number','boolean','array')),false)),
 FOREIGN KEY(session_id,tenant_id) REFERENCES public.caller_survey_sessions(id,tenant_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX caller_survey_answer_active_idx ON public.caller_survey_answer_revisions(session_id,question_key) WHERE disposition='active';
CREATE INDEX caller_survey_answer_history_idx ON public.caller_survey_answer_revisions(tenant_id,session_id,sequence);
CREATE FUNCTION public.guard_caller_survey_session() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Survey session history cannot be deleted.' USING ERRCODE='23514';
 ELSIF TG_OP='INSERT' THEN
  PERFORM t.id FROM public.caller_campaign_targets t
   JOIN public.caller_campaign_snapshots s ON s.id=t.snapshot_id AND s.tenant_id=t.tenant_id
   JOIN public.customers c ON c.id=t.customer_id AND c.tenant_id=t.tenant_id
   WHERE t.id=NEW.target_id AND t.tenant_id=NEW.tenant_id AND t.snapshot_id=NEW.snapshot_id
    AND t.attempt_count>0 AND t.identity_revision=c.identity_revision AND s.document->>'campaign_type'='survey'
   FOR SHARE OF t,c;
  IF NOT FOUND OR NEW.version<>1 OR NEW.revision_count<>0 OR NEW.state<>'active' THEN
   RAISE EXCEPTION 'Survey session requires a started current-identity survey target.' USING ERRCODE='23514';
  END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.target_id,NEW.snapshot_id,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.target_id,OLD.snapshot_id,OLD.created_at)
   OR NEW.version<>OLD.version+1 OR NEW.revision_count<OLD.revision_count OR NEW.revision_count>OLD.revision_count+1
   OR OLD.state='declined' THEN
   RAISE EXCEPTION 'Survey binding, version or terminal state cannot be rewritten.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_session_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_survey_sessions FOR EACH ROW EXECUTE FUNCTION public.guard_caller_survey_session();
CREATE FUNCTION public.guard_caller_survey_answer_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE session_version integer; counter integer;
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Survey answer history cannot be deleted.' USING ERRCODE='23514';
 END IF;
 SELECT version,revision_count INTO session_version,counter FROM public.caller_survey_sessions
  WHERE id=NEW.session_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Survey session not found.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.recorded_version<>session_version OR NEW.sequence<>counter OR NEW.disposition<>'active' THEN
   RAISE EXCEPTION 'Answer revision must belong to the current session command.' USING ERRCODE='23514';
  END IF;
  PERFORM 1 FROM public.caller_survey_sessions se JOIN public.caller_campaign_snapshots s
   ON s.id=se.snapshot_id AND s.tenant_id=se.tenant_id,
   jsonb_array_elements(s.document->'survey'->'questions') q
   WHERE se.id=NEW.session_id AND se.tenant_id=NEW.tenant_id AND q->>'key'=NEW.question_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Question is outside the fixed survey version.' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.tenant_id,NEW.session_id,NEW.sequence,NEW.question_key,NEW.answer,NEW.recorded_version,NEW.created_at)
    IS DISTINCT FROM (OLD.id,OLD.tenant_id,OLD.session_id,OLD.sequence,OLD.question_key,OLD.answer,OLD.recorded_version,OLD.created_at)
    OR OLD.disposition<>'active' OR NEW.disposition='active' OR NEW.invalidated_version IS DISTINCT FROM session_version THEN
   RAISE EXCEPTION 'Historical answer values are immutable.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_answer_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_survey_answer_revisions FOR EACH ROW EXECUTE FUNCTION public.guard_caller_survey_answer_revision();
