SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_release_simulation_results (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 release_artifact_id bigint NOT NULL,
 simulation_run_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 job_attempt_id bigint NOT NULL,
 suite_version text NOT NULL CHECK(suite_version='caller-publication-v1'),
 external_writes_stubbed boolean NOT NULL CHECK(external_writes_stubbed),
 results jsonb NOT NULL CHECK(jsonb_typeof(results)='array' AND jsonb_array_length(results)=6 AND octet_length(results::text)<=4096),
 started_at timestamptz NOT NULL,
 completed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(completed_at>=started_at),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,simulation_run_id), UNIQUE(tenant_id,background_job_id),
 FOREIGN KEY(release_artifact_id,tenant_id) REFERENCES public.caller_release_artifacts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(simulation_run_id,tenant_id) REFERENCES public.simulation_runs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(job_attempt_id,tenant_id) REFERENCES public.job_attempts(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_release_simulation_history_idx ON public.caller_release_simulation_results(tenant_id,release_artifact_id,completed_at DESC);
COMMENT ON TABLE public.caller_release_simulation_results IS 'Immutable dedicated-worker results bound to release and live attempt; not publication authorization. Legacy mutable simulation metadata is not certification.';
CREATE FUNCTION public.guard_release_simulation_result() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE job public.background_jobs%ROWTYPE; run public.simulation_runs%ROWTYPE;
 release public.caller_release_artifacts%ROWTYPE; attempt public.job_attempts%ROWTYPE;
 item jsonb; scenario text; seen text[]:='{}';
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Release simulation results are immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO job FROM public.background_jobs WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NOT FOUND OR job.queue_name<>'caller-release-simulation' OR job.job_type<>'caller.release-simulate.v1'
  OR job.status<>'running' OR job.lease_expires_at IS NULL OR job.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Release simulation result requires dedicated active lease' USING ERRCODE='23514'; END IF;
 SELECT * INTO attempt FROM public.job_attempts WHERE id=NEW.job_attempt_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR attempt.background_job_id<>job.id OR attempt.attempt_no<>job.active_attempt_no OR attempt.status<>'running' THEN
  RAISE EXCEPTION 'Release simulation result attempt mismatch' USING ERRCODE='23514'; END IF;
 SELECT * INTO release FROM public.caller_release_artifacts WHERE id=NEW.release_artifact_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Release simulation artifact missing' USING ERRCODE='23514'; END IF;
 SELECT * INTO run FROM public.simulation_runs WHERE id=NEW.simulation_run_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR run.tenant_environment_id<>release.tenant_environment_id OR run.run_mode<>'publish_gate'
  OR run.status<>'running' OR run.gate_decision<>'pending' OR run.started_at IS NULL OR run.completed_at IS NOT NULL THEN
  RAISE EXCEPTION 'Release simulation run is not active in release environment' USING ERRCODE='23514'; END IF;
 IF NOT COALESCE(job.payload->>'schema_version'='1'
  AND job.payload->>'release_public_id'=release.public_id::text
  AND job.payload->>'simulation_run_public_id'=run.public_id::text
  AND job.payload->>'suite_version'=NEW.suite_version,false) THEN
  RAISE EXCEPTION 'Release simulation job binding mismatch' USING ERRCODE='23514'; END IF;
 IF jsonb_typeof(NEW.results)<>'array' OR jsonb_array_length(NEW.results)<>6 THEN
  RAISE EXCEPTION 'Release simulation needs six results' USING ERRCODE='23514'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(NEW.results) LOOP
  scenario:=item->>'scenario';
  IF NOT COALESCE(jsonb_typeof(item)='object' AND item ?& ARRAY['scenario','result']
   AND (item-ARRAY['scenario','result'])='{}'::jsonb
   AND scenario=ANY(ARRAY['refusal','do_not_call','uncertain_answer','incorrect_information','tool_error','transfer'])
   AND item->>'result'=ANY(ARRAY['passed','failed','skipped']),false)
   OR scenario=ANY(seen) THEN
   RAISE EXCEPTION 'Invalid or duplicate release simulation scenario' USING ERRCODE='23514'; END IF;
  seen:=array_append(seen,scenario);
 END LOOP;
 IF job.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Release simulation lease expired during persistence' USING ERRCODE='23514'; END IF;
 NEW.started_at:=run.started_at;
 NEW.completed_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_release_simulation_result_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_release_simulation_results
 FOR EACH ROW EXECUTE FUNCTION public.guard_release_simulation_result();
