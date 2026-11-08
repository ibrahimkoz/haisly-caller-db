-- Campaign instructions are the only tenant-authored assistant configuration.
-- Removes legacy agent, guardrail-editor and knowledge-base modules.
SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_versions ADD COLUMN tenant_environment_id bigint;
ALTER TABLE public.caller_campaign_versions ADD CONSTRAINT caller_campaign_versions_environment_fk
 FOREIGN KEY(tenant_environment_id,tenant_id) REFERENCES public.tenant_environments(id,tenant_id) ON DELETE RESTRICT;
UPDATE public.caller_campaign_versions c SET tenant_environment_id=v.tenant_environment_id
 FROM public.agent_config_versions v WHERE v.id=c.agent_config_version_id AND v.tenant_id=c.tenant_id;
ALTER TABLE public.caller_campaign_versions DROP COLUMN agent_config_version_id;
CREATE INDEX caller_campaign_versions_environment_idx ON public.caller_campaign_versions(tenant_id,tenant_environment_id);
ALTER TABLE public.caller_campaign_snapshots DROP COLUMN agent_snapshot;
ALTER TABLE public.simulation_scenarios ALTER COLUMN ai_agent_id DROP NOT NULL;
ALTER TABLE public.simulation_runs ALTER COLUMN ai_agent_id DROP NOT NULL;
-- Preserve historical call/session IDs as inert metadata, with no live agent dependency.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT conrelid::regclass AS relation,conname FROM pg_constraint
 WHERE contype='f' AND confrelid IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace AND relname IN ('ai_agents','agent_config_versions','agent_config_bindings','agent_config_publish_requests','agent_config_improvement_runs','agent_config_section_values','industry_agent_templates','industry_agent_template_versions','industry_agent_template_sections','agent_guardrail_bindings','guardrail_policies','guardrail_policy_versions','policy_evaluation_logs','agent_knowledge_bindings','knowledge_collections','knowledge_sources','knowledge_source_versions','knowledge_chunks','knowledge_ingestion_jobs','caller_campaign_knowledge_pins','caller_knowledge_https_policies'))
 AND conrelid NOT IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace AND relname IN ('ai_agents','agent_config_versions','agent_config_bindings','agent_config_publish_requests','agent_config_improvement_runs','agent_config_section_values','industry_agent_templates','industry_agent_template_versions','industry_agent_template_sections','agent_guardrail_bindings','guardrail_policies','guardrail_policy_versions','policy_evaluation_logs','agent_knowledge_bindings','knowledge_collections','knowledge_sources','knowledge_source_versions','knowledge_chunks','knowledge_ingestion_jobs','caller_campaign_knowledge_pins','caller_knowledge_https_policies')) LOOP
  EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I',f.relation,f.conname);
 END LOOP;
END $$;
DROP TABLE public.ai_agents, public.agent_config_versions, public.agent_config_bindings, public.agent_config_publish_requests, public.agent_config_improvement_runs, public.agent_config_section_values, public.industry_agent_templates, public.industry_agent_template_versions, public.industry_agent_template_sections, public.agent_guardrail_bindings, public.guardrail_policies, public.guardrail_policy_versions, public.policy_evaluation_logs, public.agent_knowledge_bindings, public.knowledge_collections, public.knowledge_sources, public.knowledge_source_versions, public.knowledge_chunks, public.knowledge_ingestion_jobs, public.caller_campaign_knowledge_pins, public.caller_knowledge_https_policies;
DROP FUNCTION IF EXISTS public.prevent_published_agent_config_snapshot_mutation();
DROP FUNCTION IF EXISTS public.validate_agent_config_section_value_mutation();
DROP FUNCTION IF EXISTS public.prevent_agent_config_template_version_mutation();
DROP FUNCTION IF EXISTS public.guard_campaign_knowledge_pin();
DROP FUNCTION IF EXISTS public.guard_knowledge_content_seal();
DROP FUNCTION IF EXISTS public.guard_sealed_knowledge_chunk();
CREATE OR REPLACE FUNCTION public.guard_inbound_greeting_pin() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Inbound greeting is retired in outbound-only Caller' USING ERRCODE='23514'; END $$;
CREATE OR REPLACE FUNCTION public.caller_guard_runtime_release_binding()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE matched boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'Runtime release binding is immutable' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id, 0));
  SELECT true INTO matched
    FROM public.call_sessions s
    JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
    JOIN public.caller_dispatch_intents d ON d.id=NEW.dispatch_id AND d.tenant_id=s.tenant_id
    JOIN public.caller_release_artifacts r ON r.id=NEW.release_artifact_id AND r.tenant_id=s.tenant_id
    JOIN public.caller_campaign_snapshots snap ON snap.id=r.snapshot_id AND snap.tenant_id=s.tenant_id
    JOIN public.tenant_environments v ON v.id=s.tenant_environment_id AND v.tenant_id=s.tenant_id
    JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=s.tenant_id
    WHERE s.id=NEW.call_session_id AND s.tenant_id=NEW.tenant_id
      AND s.status IN ('initiated','active') AND s.ended_at IS NULL
      AND c.direction='outbound' AND c.status IN ('ringing','in_progress') AND c.ended_at IS NULL
      AND d.state='accepted' AND c.provider_call_id=d.provider_call_ref
      AND c.phone_number_id=d.outbound_phone_number_id AND r.outbound_phone_number_id=d.outbound_phone_number_id
      AND r.snapshot_id=d.snapshot_id AND r.tenant_environment_id=s.tenant_environment_id
      AND v.public_id::text=snap.document->'settings'->>'tenant_environment_public_id'
      AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
    FOR SHARE OF s,c,d,r,snap,v,person;
  IF NOT COALESCE(matched,false) THEN
    RAISE EXCEPTION 'Runtime release does not match accepted dispatch and call identity' USING ERRCODE='23514';
  END IF;
  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.guard_release_simulation_result()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
  AND job.payload->>'suite_version'=NEW.suite_version
  AND job.metadata->>'release_hash'=release.release_hash
  AND run.requested_by_user_id IS NOT NULL AND run.requested_by_user_id=job.created_by_user_id,false) THEN
  RAISE EXCEPTION 'Release simulation job binding mismatch' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.tenant_environments v
  JOIN public.caller_campaign_snapshots s ON s.tenant_id=v.tenant_id AND s.id=release.snapshot_id
  WHERE v.tenant_id=NEW.tenant_id AND v.id=run.tenant_environment_id
   AND v.public_id::text=s.document->'settings'->>'tenant_environment_public_id') THEN
  RAISE EXCEPTION 'Release simulation campaign environment mismatch' USING ERRCODE='23514'; END IF;
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
END $function$;


ALTER TABLE public.caller_campaign_snapshots DROP CONSTRAINT caller_snapshot_compilation_check;
ALTER TABLE public.caller_campaign_snapshots
 ADD CONSTRAINT caller_snapshot_compilation_check CHECK (
  content_compilation_snapshot IS NULL OR COALESCE((
   identity_snapshot IS NOT NULL
   AND jsonb_typeof(content_compilation_snapshot) = 'object'
   AND octet_length(content_compilation_snapshot::text) <= 2097152
   AND content_compilation_snapshot ?& ARRAY['content','summary']
   AND (content_compilation_snapshot - 'content' - 'summary') = '{}'::jsonb
   AND jsonb_typeof(content_compilation_snapshot->'summary') = 'object'
   AND (content_compilation_snapshot->'summary') ?& ARRAY['compiler_version','release_certified','status','content_hash','binding_hash','blocker']
   AND content_compilation_snapshot->'summary'->>'compiler_version' IN ('caller-content-v1','caller-content-v2')
   AND content_compilation_snapshot->'summary'->'release_certified' = 'false'::jsonb
   AND (
    (content_compilation_snapshot->'summary'->>'status' = 'compiled'
     AND jsonb_typeof(content_compilation_snapshot->'content') = 'object'
     AND content_compilation_snapshot->'content'->>'compiler_version' IN ('caller-content-v1','caller-content-v2')
     AND content_compilation_snapshot->'content'->'identity' = identity_snapshot
     AND content_compilation_snapshot->'summary'->>'content_hash' ~ '^[a-f0-9]{64}$'
     AND content_compilation_snapshot->'summary'->>'binding_hash' ~ '^[a-f0-9]{64}$'
     AND content_compilation_snapshot->'summary'->'blocker' = 'null'::jsonb)
    OR
    (content_compilation_snapshot->'summary'->>'status' = 'blocked'
     AND content_compilation_snapshot->'content' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->'content_hash' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->'binding_hash' = 'null'::jsonb
     AND content_compilation_snapshot->'summary'->>'blocker' IN ('caller_snapshot_identity_missing','caller_base_instructions_required','caller_content_invalid'))
   )
  ), false)
 );
