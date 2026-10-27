SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_evaluation_inputs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 transcript_snapshot_id bigint NOT NULL,
 evaluator_ref text NOT NULL CHECK(evaluator_ref ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 protocol_version text NOT NULL CHECK(protocol_version='quality-evaluator-v1'),
 context_hash text NOT NULL CHECK(context_hash ~ '^[a-f0-9]{64}$'),
 expected_version integer NOT NULL DEFAULT 0 CHECK(expected_version=0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,background_job_id),
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(transcript_snapshot_id,tenant_id) REFERENCES public.caller_quality_transcript_snapshots(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_quality_input_binding_idx ON public.caller_quality_evaluation_inputs(tenant_id,runtime_binding_id);
CREATE FUNCTION public.guard_quality_evaluation_input() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE job public.background_jobs%ROWTYPE; binding_public uuid; end_public uuid; environment_public uuid;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality evaluation inputs are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO job FROM public.background_jobs WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NOT FOUND OR job.queue_name<>'caller-quality' OR job.job_type<>'quality.evaluate-initial'
  OR job.status<>'running' OR job.lease_expires_at IS NULL OR job.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Quality evaluation requires an active job lease' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.job_attempts WHERE tenant_id=NEW.tenant_id AND background_job_id=job.id AND attempt_no=job.active_attempt_no AND status='running') THEN
  RAISE EXCEPTION 'Quality evaluation requires an active attempt' USING ERRCODE='23514';
 END IF;
 SELECT b.public_id,e.public_id,env.public_id INTO binding_public,end_public,environment_public
 FROM public.caller_runtime_release_bindings b
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.tenant_environments env ON env.id=s.tenant_environment_id AND env.tenant_id=b.tenant_id
 JOIN public.caller_call_end_snapshots e ON e.runtime_binding_id=b.id AND e.tenant_id=b.tenant_id AND e.call_id=s.call_id
 JOIN public.caller_quality_transcript_snapshots t ON t.runtime_binding_id=b.id AND t.tenant_id=b.tenant_id AND t.call_id=e.call_id
 WHERE b.tenant_id=NEW.tenant_id AND b.id=NEW.runtime_binding_id AND t.id=NEW.transcript_snapshot_id;
 IF NOT FOUND OR job.payload IS DISTINCT FROM jsonb_build_object('schema_version',1,'protocol_version',NEW.protocol_version,
   'binding_public_id',binding_public,'end_public_id',end_public,'environment_public_id',environment_public) THEN
  RAISE EXCEPTION 'Quality evaluation input does not match its bound job' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.caller_quality_assessment_revisions WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id) THEN
  RAISE EXCEPTION 'Initial quality evaluation cannot replace an existing assessment' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_input_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_evaluation_inputs
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_evaluation_input();
