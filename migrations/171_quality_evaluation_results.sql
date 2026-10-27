SET LOCAL lock_timeout='5s';
ALTER TABLE public.job_attempts ADD CONSTRAINT job_attempts_id_tenant_id_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_quality_evaluation_results (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 prepared_input_id bigint NOT NULL,
 assessment_id bigint NOT NULL,
 job_attempt_id bigint NOT NULL,
 response_hash text NOT NULL CHECK(response_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,background_job_id), UNIQUE(tenant_id,prepared_input_id), UNIQUE(tenant_id,assessment_id),
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(prepared_input_id,tenant_id) REFERENCES public.caller_quality_evaluation_inputs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(assessment_id,tenant_id) REFERENCES public.caller_quality_assessment_revisions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(job_attempt_id,tenant_id) REFERENCES public.job_attempts(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_quality_evaluation_result() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE job public.background_jobs%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality evaluation results are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO job FROM public.background_jobs WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NOT FOUND OR job.queue_name<>'caller-quality' OR job.job_type<>'quality.evaluate-initial' OR job.status<>'running'
  OR job.lease_expires_at IS NULL OR job.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Quality result requires active job lease' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.job_attempts a
  JOIN public.caller_quality_evaluation_inputs i ON i.background_job_id=a.background_job_id AND i.tenant_id=a.tenant_id
  JOIN public.caller_quality_assessment_revisions q ON q.runtime_binding_id=i.runtime_binding_id AND q.tenant_id=i.tenant_id
  WHERE a.tenant_id=NEW.tenant_id AND a.id=NEW.job_attempt_id AND a.background_job_id=job.id AND a.status='running' AND a.attempt_no=job.active_attempt_no
   AND i.id=NEW.prepared_input_id AND q.id=NEW.assessment_id AND q.version=i.expected_version+1
   AND q.assessment_source='model_assessment' AND q.evaluator_ref=i.evaluator_ref
   AND q.request_key='quality-job:'||job.public_id::text) THEN
  RAISE EXCEPTION 'Quality result does not match prepared input and active attempt' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_result_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_evaluation_results
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_evaluation_result();
CREATE FUNCTION public.guard_quality_job_completion() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.queue_name='caller-quality' AND NEW.job_type='quality.evaluate-initial' AND NEW.status='succeeded' THEN
  IF NOT EXISTS(SELECT 1 FROM public.caller_quality_evaluation_results r
   JOIN public.job_attempts a ON a.id=r.job_attempt_id AND a.tenant_id=r.tenant_id
   WHERE r.tenant_id=NEW.tenant_id AND r.background_job_id=NEW.id AND a.attempt_no=NEW.active_attempt_no AND a.status='succeeded') THEN
   RAISE EXCEPTION 'Quality job completion requires a committed evaluation result' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_job_completion_guard BEFORE INSERT OR UPDATE ON public.background_jobs
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_job_completion();
