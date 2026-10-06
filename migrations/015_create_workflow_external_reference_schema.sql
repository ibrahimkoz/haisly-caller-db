CREATE TABLE public.workflow_templates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT workflow_templates_public_id_unique UNIQUE (public_id),
  CONSTRAINT workflow_templates_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT workflow_templates_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT workflow_templates_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_templates_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT workflow_templates_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT workflow_templates_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT workflow_templates_status_check CHECK (status IN (
    'draft',
    'active',
    'deprecated',
    'disabled'
  )),
  CONSTRAINT workflow_templates_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX workflow_templates_tenant_status_updated_at_idx
  ON public.workflow_templates (tenant_id, status, updated_at DESC);

CREATE TABLE public.workflow_template_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  workflow_template_id bigint NOT NULL,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  trigger_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  steps_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT workflow_template_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT workflow_template_versions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT workflow_template_versions_template_version_unique UNIQUE (workflow_template_id, version_no),
  CONSTRAINT workflow_template_versions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_template_versions_template_tenant_fk FOREIGN KEY (workflow_template_id, tenant_id)
    REFERENCES public.workflow_templates (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_template_versions_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_template_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT workflow_template_versions_status_check CHECK (status IN (
    'draft',
    'published',
    'archived',
    'deprecated'
  )),
  CONSTRAINT workflow_template_versions_trigger_config_object_check CHECK (jsonb_typeof(trigger_config) = 'object'),
  CONSTRAINT workflow_template_versions_steps_config_object_check CHECK (jsonb_typeof(steps_config) = 'object'),
  CONSTRAINT workflow_template_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT workflow_template_versions_archived_requires_status_check CHECK (
    archived_at IS NULL OR status IN ('archived', 'deprecated')
  )
);

CREATE INDEX workflow_template_versions_tenant_status_updated_at_idx
  ON public.workflow_template_versions (tenant_id, status, updated_at DESC);

CREATE INDEX workflow_template_versions_template_status_version_idx
  ON public.workflow_template_versions (workflow_template_id, status, version_no DESC);

CREATE TABLE public.tenant_workflow_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  workflow_template_id bigint NOT NULL,
  workflow_template_version_id bigint NOT NULL,
  ai_agent_id bigint,
  binding_scope text NOT NULL DEFAULT 'tenant',
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_workflow_bindings_public_id_unique UNIQUE (public_id),
  CONSTRAINT tenant_workflow_bindings_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tenant_workflow_bindings_scope_template_agent_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    binding_scope,
    workflow_template_id,
    ai_agent_id
  ),
  CONSTRAINT tenant_workflow_bindings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_workflow_bindings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_workflow_bindings_template_tenant_fk FOREIGN KEY (workflow_template_id, tenant_id)
    REFERENCES public.workflow_templates (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_workflow_bindings_template_version_tenant_fk FOREIGN KEY (workflow_template_version_id, tenant_id)
    REFERENCES public.workflow_template_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_workflow_bindings_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_workflow_bindings_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tenant_workflow_bindings_scope_check CHECK (binding_scope IN (
    'tenant',
    'agent'
  )),
  CONSTRAINT tenant_workflow_bindings_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT tenant_workflow_bindings_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT tenant_workflow_bindings_scope_agent_requires_agent_check CHECK (
    (binding_scope = 'agent' AND ai_agent_id IS NOT NULL)
    OR (binding_scope = 'tenant' AND ai_agent_id IS NULL)
  ),
  CONSTRAINT tenant_workflow_bindings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX tenant_workflow_bindings_tenant_scope_unique_idx
  ON public.tenant_workflow_bindings (tenant_id, tenant_environment_id, workflow_template_id)
  WHERE binding_scope = 'tenant' AND ai_agent_id IS NULL;

CREATE UNIQUE INDEX tenant_workflow_bindings_agent_scope_unique_idx
  ON public.tenant_workflow_bindings (tenant_id, tenant_environment_id, workflow_template_id, ai_agent_id)
  WHERE binding_scope = 'agent' AND ai_agent_id IS NOT NULL;

CREATE INDEX tenant_workflow_bindings_tenant_env_status_priority_idx
  ON public.tenant_workflow_bindings (tenant_id, tenant_environment_id, status, priority ASC);

CREATE TABLE public.workflow_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  workflow_template_id bigint NOT NULL,
  workflow_template_version_id bigint NOT NULL,
  tenant_workflow_binding_id bigint,
  call_id bigint,
  case_id bigint,
  lead_id bigint,
  customer_id bigint,
  trigger_source text NOT NULL,
  trigger_ref text,
  status text NOT NULL DEFAULT 'queued',
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_payload jsonb,
  error_payload jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT workflow_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT workflow_runs_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT workflow_runs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_runs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_runs_template_tenant_fk FOREIGN KEY (workflow_template_id, tenant_id)
    REFERENCES public.workflow_templates (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_runs_template_version_tenant_fk FOREIGN KEY (workflow_template_version_id, tenant_id)
    REFERENCES public.workflow_template_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_runs_binding_tenant_fk FOREIGN KEY (tenant_workflow_binding_id, tenant_id)
    REFERENCES public.tenant_workflow_bindings (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_runs_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_runs_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_runs_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_runs_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT workflow_runs_trigger_source_not_blank_check CHECK (btrim(trigger_source) <> ''),
  CONSTRAINT workflow_runs_trigger_ref_not_blank_check CHECK (
    trigger_ref IS NULL OR btrim(trigger_ref) <> ''
  ),
  CONSTRAINT workflow_runs_status_check CHECK (status IN (
    'queued',
    'running',
    'succeeded',
    'failed',
    'cancelled',
    'waiting'
  )),
  CONSTRAINT workflow_runs_input_payload_object_check CHECK (jsonb_typeof(input_payload) = 'object'),
  CONSTRAINT workflow_runs_output_payload_shape_check CHECK (
    output_payload IS NULL OR jsonb_typeof(output_payload) IN ('object', 'array')
  ),
  CONSTRAINT workflow_runs_error_payload_shape_check CHECK (
    error_payload IS NULL OR jsonb_typeof(error_payload) IN ('object', 'array')
  ),
  CONSTRAINT workflow_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT workflow_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  )
);

CREATE INDEX workflow_runs_tenant_status_created_at_idx
  ON public.workflow_runs (tenant_id, status, created_at DESC);

CREATE INDEX workflow_runs_tenant_template_version_status_idx
  ON public.workflow_runs (tenant_id, workflow_template_version_id, status, created_at DESC);

CREATE TABLE public.workflow_step_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  workflow_run_id bigint NOT NULL,
  step_index integer NOT NULL,
  step_code text NOT NULL,
  step_type text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempt_no integer NOT NULL DEFAULT 1,
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_payload jsonb,
  error_payload jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT workflow_step_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT workflow_step_runs_run_step_attempt_unique UNIQUE (workflow_run_id, step_index, attempt_no),
  CONSTRAINT workflow_step_runs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_step_runs_run_tenant_fk FOREIGN KEY (workflow_run_id, tenant_id)
    REFERENCES public.workflow_runs (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT workflow_step_runs_step_index_positive_check CHECK (step_index > 0),
  CONSTRAINT workflow_step_runs_step_code_not_blank_check CHECK (btrim(step_code) <> ''),
  CONSTRAINT workflow_step_runs_step_type_not_blank_check CHECK (btrim(step_type) <> ''),
  CONSTRAINT workflow_step_runs_status_check CHECK (status IN (
    'pending',
    'running',
    'succeeded',
    'failed',
    'skipped',
    'cancelled',
    'retryable'
  )),
  CONSTRAINT workflow_step_runs_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT workflow_step_runs_input_payload_object_check CHECK (jsonb_typeof(input_payload) = 'object'),
  CONSTRAINT workflow_step_runs_output_payload_shape_check CHECK (
    output_payload IS NULL OR jsonb_typeof(output_payload) IN ('object', 'array')
  ),
  CONSTRAINT workflow_step_runs_error_payload_shape_check CHECK (
    error_payload IS NULL OR jsonb_typeof(error_payload) IN ('object', 'array')
  ),
  CONSTRAINT workflow_step_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT workflow_step_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  )
);

CREATE INDEX workflow_step_runs_run_status_step_idx
  ON public.workflow_step_runs (workflow_run_id, status, step_index ASC, created_at ASC);

CREATE INDEX workflow_step_runs_tenant_status_created_at_idx
  ON public.workflow_step_runs (tenant_id, status, created_at DESC);

CREATE TABLE public.external_object_references (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  workflow_run_id bigint,
  call_id bigint,
  case_id bigint,
  lead_id bigint,
  customer_id bigint,
  source_system text NOT NULL,
  entity_type text NOT NULL,
  external_object_id text NOT NULL,
  outcome_status text NOT NULL DEFAULT 'pending',
  outcome_code text,
  request_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  response_snapshot jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT external_object_references_public_id_unique UNIQUE (public_id),
  CONSTRAINT external_object_references_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT external_object_references_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT external_object_references_workflow_run_tenant_fk FOREIGN KEY (workflow_run_id, tenant_id)
    REFERENCES public.workflow_runs (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT external_object_references_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT external_object_references_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT external_object_references_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT external_object_references_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT external_object_references_source_system_not_blank_check CHECK (btrim(source_system) <> ''),
  CONSTRAINT external_object_references_entity_type_not_blank_check CHECK (btrim(entity_type) <> ''),
  CONSTRAINT external_object_references_external_object_id_not_blank_check CHECK (btrim(external_object_id) <> ''),
  CONSTRAINT external_object_references_outcome_status_check CHECK (outcome_status IN (
    'pending',
    'succeeded',
    'failed',
    'partial'
  )),
  CONSTRAINT external_object_references_outcome_code_not_blank_check CHECK (
    outcome_code IS NULL OR btrim(outcome_code) <> ''
  ),
  CONSTRAINT external_object_references_request_snapshot_object_check CHECK (jsonb_typeof(request_snapshot) = 'object'),
  CONSTRAINT external_object_references_response_snapshot_shape_check CHECK (
    response_snapshot IS NULL OR jsonb_typeof(response_snapshot) IN ('object', 'array')
  ),
  CONSTRAINT external_object_references_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX external_object_references_tenant_source_entity_occurred_idx
  ON public.external_object_references (tenant_id, source_system, entity_type, occurred_at DESC);

CREATE INDEX external_object_references_tenant_workflow_run_occurred_idx
  ON public.external_object_references (tenant_id, workflow_run_id, occurred_at DESC)
  WHERE workflow_run_id IS NOT NULL;
