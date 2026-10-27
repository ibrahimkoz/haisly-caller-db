SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_job_reviews (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 reviewer_user_id bigint NOT NULL,
 version integer NOT NULL CHECK(version>0),
 attempt_no integer NOT NULL CHECK(attempt_no>=0),
 action text NOT NULL CHECK(action IN ('keep_closed','retry_unprepared')),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 2000),
 request_key text NOT NULL CHECK(length(request_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,background_job_id,version), UNIQUE(tenant_id,background_job_id,request_key),
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(reviewer_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_quality_job_review() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE job public.background_jobs%ROWTYPE; previous_version integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality job reviews are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO job FROM public.background_jobs WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NOT FOUND OR job.queue_name<>'caller-quality' OR job.job_type<>'quality.evaluate-initial'
  OR job.status<>'dead_letter' OR job.active_attempt_no<>NEW.attempt_no THEN
  RAISE EXCEPTION 'Quality review requires the current dead-letter attempt' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.users u JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=NEW.tenant_id
  JOIN public.user_roles ur ON ur.user_id=u.id AND ur.tenant_id=m.tenant_id
  JOIN public.roles r ON r.id=ur.role_id AND r.tenant_id=ur.tenant_id
  WHERE u.id=NEW.reviewer_user_id AND u.status='active' AND u.deleted_at IS NULL
   AND m.status='active' AND m.deleted_at IS NULL AND ur.status='active' AND ur.revoked_at IS NULL
   AND r.status='active' AND r.code='owner'
 ) THEN RAISE EXCEPTION 'Quality job review requires an active tenant owner' USING ERRCODE='23514'; END IF;
 SELECT coalesce(max(version),0) INTO previous_version FROM public.caller_quality_job_reviews
  WHERE tenant_id=NEW.tenant_id AND background_job_id=job.id;
 IF NEW.version<>previous_version+1 THEN RAISE EXCEPTION 'Quality job review version conflicts' USING ERRCODE='23514'; END IF;
 IF NEW.action='retry_unprepared' AND (NOT job.retry_safe OR job.active_attempt_no>=job.max_attempts
  OR EXISTS(SELECT 1 FROM public.job_attempts WHERE tenant_id=NEW.tenant_id AND background_job_id=job.id AND attempt_no>=job.max_attempts)
  OR EXISTS(SELECT 1 FROM public.caller_quality_evaluation_inputs WHERE tenant_id=NEW.tenant_id AND background_job_id=job.id)
  OR EXISTS(SELECT 1 FROM public.caller_quality_assessment_revisions q JOIN public.caller_runtime_release_bindings b ON b.id=q.runtime_binding_id AND b.tenant_id=q.tenant_id WHERE q.tenant_id=NEW.tenant_id AND b.public_id::text=job.payload->>'binding_public_id')
  OR EXISTS(SELECT 1 FROM public.caller_quality_evaluation_results WHERE tenant_id=NEW.tenant_id AND background_job_id=job.id)) THEN
  RAISE EXCEPTION 'Quality retry requires an unprepared job within its existing attempt limit' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_job_review_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_job_reviews
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_job_review();
