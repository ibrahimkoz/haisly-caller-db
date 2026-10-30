SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_simulation_submission_intents (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL UNIQUE,
 tenant_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 job_attempt_id bigint NOT NULL,
 release_artifact_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 release_hash text NOT NULL CHECK(release_hash ~ '^[a-f0-9]{64}$'),
 definition_hash text NOT NULL CHECK(definition_hash ~ '^[a-f0-9]{64}$'),
 binding jsonb NOT NULL CHECK(jsonb_typeof(binding)='object' AND octet_length(binding::text)<=8192),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,background_job_id),
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(job_attempt_id,tenant_id) REFERENCES public.job_attempts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(release_artifact_id,tenant_id) REFERENCES public.caller_release_artifacts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_simulation_submission_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE j public.background_jobs%ROWTYPE; r public.caller_release_artifacts%ROWTYPE; item jsonb; seen text[]:='{}'; tests text[]:='{}';
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Simulation submission intent is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO j FROM public.background_jobs WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NOT FOUND OR j.queue_name<>'caller-release-simulation' OR j.job_type<>'caller.release-simulate.v1'
  OR j.status<>'running' OR j.retry_safe OR j.lease_expires_at IS NULL OR j.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Simulation submission requires a nonretryable active job' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.job_attempts a WHERE a.id=NEW.job_attempt_id AND a.tenant_id=NEW.tenant_id
  AND a.background_job_id=j.id AND a.attempt_no=j.active_attempt_no AND a.status='running') THEN
  RAISE EXCEPTION 'Simulation submission attempt mismatch' USING ERRCODE='23514'; END IF;
 SELECT * INTO r FROM public.caller_release_artifacts WHERE id=NEW.release_artifact_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND OR r.release_hash<>NEW.release_hash OR NOT COALESCE(j.payload->>'release_public_id'=r.public_id::text
  AND j.metadata->>'release_hash'=NEW.release_hash AND j.metadata->>'definition_hash'=NEW.definition_hash,false) THEN
  RAISE EXCEPTION 'Simulation submission release mismatch' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.telephony_provider_accounts p WHERE p.id=NEW.provider_account_id AND p.tenant_id=NEW.tenant_id
  AND p.tenant_environment_id=r.tenant_environment_id AND p.provider_code='elevenlabs' AND p.status='active') THEN
  RAISE EXCEPTION 'Simulation submission provider mismatch' USING ERRCODE='23514'; END IF;
 IF NOT COALESCE(NEW.binding ?& ARRAY['agent_id','branch_id','version_id','correlation_id','tests']
  AND NEW.binding-ARRAY['agent_id','branch_id','version_id','correlation_id','tests']='{}'::jsonb
  AND NEW.binding->>'correlation_id'=NEW.public_id::text
  AND NEW.binding->>'agent_id' ~ '^[A-Za-z0-9_-]{1,128}$'
  AND NEW.binding->>'branch_id' ~ '^[A-Za-z0-9_-]{1,128}$'
  AND NEW.binding->>'version_id' ~ '^[A-Za-z0-9_-]{1,128}$'
  AND jsonb_typeof(NEW.binding->'tests')='array',false) THEN
  RAISE EXCEPTION 'Simulation submission binding invalid' USING ERRCODE='23514'; END IF;
 IF jsonb_array_length(NEW.binding->'tests')<>6 THEN RAISE EXCEPTION 'Six simulation tests required' USING ERRCODE='23514'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(NEW.binding->'tests') LOOP
  IF NOT COALESCE(jsonb_typeof(item)='object' AND item ?& ARRAY['scenario','test_id'] AND item-ARRAY['scenario','test_id']='{}'::jsonb
   AND item->>'scenario' IN ('refusal','do_not_call','uncertain_answer','incorrect_information','tool_error','transfer')
   AND item->>'test_id' ~ '^[A-Za-z0-9_-]{1,128}$',false)
   OR item->>'scenario'=ANY(seen) OR item->>'test_id'=ANY(tests) THEN
   RAISE EXCEPTION 'Simulation test mapping invalid' USING ERRCODE='23514'; END IF;
  seen:=array_append(seen,item->>'scenario'); tests:=array_append(tests,item->>'test_id');
 END LOOP;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_simulation_submission_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_simulation_submission_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_simulation_submission_intent();
CREATE FUNCTION public.guard_simulation_submission_retry() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_simulation_submission_intents i WHERE i.tenant_id=OLD.tenant_id AND i.background_job_id=OLD.id)
 AND (NEW.retry_safe OR NEW.status IN ('queued','failed') OR NEW.active_attempt_no IS DISTINCT FROM OLD.active_attempt_no) THEN
  RAISE EXCEPTION 'Recorded simulation submission cannot be retried' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_simulation_submission_retry_guard BEFORE UPDATE ON public.background_jobs
 FOR EACH ROW EXECUTE FUNCTION public.guard_simulation_submission_retry();
COMMENT ON TABLE public.caller_simulation_submission_intents IS 'One irreversible send boundary per simulation job. Missing response is ambiguous, not permission to resend. Not provider isolation or publication evidence.';
