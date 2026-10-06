CREATE TABLE public.tool_definitions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  tool_type text NOT NULL DEFAULT 'http',
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tool_definitions_public_id_unique UNIQUE (public_id),
  CONSTRAINT tool_definitions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tool_definitions_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT tool_definitions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tool_definitions_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT tool_definitions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT tool_definitions_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT tool_definitions_tool_type_check CHECK (tool_type IN (
    'http',
    'function',
    'workflow',
    'integration',
    'system'
  )),
  CONSTRAINT tool_definitions_status_check CHECK (status IN (
    'draft',
    'active',
    'deprecated',
    'disabled'
  )),
  CONSTRAINT tool_definitions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX tool_definitions_tenant_status_updated_at_idx
  ON public.tool_definitions (tenant_id, status, updated_at DESC);

CREATE TABLE public.tool_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tool_definition_id bigint NOT NULL,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  input_schema jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_schema jsonb NOT NULL DEFAULT '{}'::jsonb,
  execution_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tool_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT tool_versions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tool_versions_definition_version_unique UNIQUE (tool_definition_id, version_no),
  CONSTRAINT tool_versions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tool_versions_definition_tenant_fk FOREIGN KEY (tool_definition_id, tenant_id)
    REFERENCES public.tool_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tool_versions_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT tool_versions_status_check CHECK (status IN (
    'draft',
    'published',
    'archived',
    'deprecated'
  )),
  CONSTRAINT tool_versions_input_schema_object_check CHECK (jsonb_typeof(input_schema) = 'object'),
  CONSTRAINT tool_versions_output_schema_object_check CHECK (jsonb_typeof(output_schema) = 'object'),
  CONSTRAINT tool_versions_execution_config_object_check CHECK (jsonb_typeof(execution_config) = 'object'),
  CONSTRAINT tool_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT tool_versions_archived_requires_status_check CHECK (
    archived_at IS NULL OR status IN ('archived', 'deprecated')
  )
);

CREATE INDEX tool_versions_tenant_status_updated_at_idx
  ON public.tool_versions (tenant_id, status, updated_at DESC);

CREATE INDEX tool_versions_definition_status_version_idx
  ON public.tool_versions (tool_definition_id, status, version_no DESC);

CREATE TABLE public.tenant_tool_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  tool_definition_id bigint NOT NULL,
  tool_version_id bigint NOT NULL,
  ai_agent_id bigint,
  binding_scope text NOT NULL DEFAULT 'tenant',
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_tool_bindings_public_id_unique UNIQUE (public_id),
  CONSTRAINT tenant_tool_bindings_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tenant_tool_bindings_tenant_env_scope_definition_agent_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    binding_scope,
    tool_definition_id,
    ai_agent_id
  ),
  CONSTRAINT tenant_tool_bindings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_tool_bindings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_tool_bindings_definition_tenant_fk FOREIGN KEY (tool_definition_id, tenant_id)
    REFERENCES public.tool_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_tool_bindings_version_tenant_fk FOREIGN KEY (tool_version_id, tenant_id)
    REFERENCES public.tool_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_tool_bindings_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_tool_bindings_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tenant_tool_bindings_scope_check CHECK (binding_scope IN (
    'tenant',
    'agent'
  )),
  CONSTRAINT tenant_tool_bindings_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT tenant_tool_bindings_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT tenant_tool_bindings_scope_agent_requires_agent_check CHECK (
    (binding_scope = 'agent' AND ai_agent_id IS NOT NULL)
    OR (binding_scope = 'tenant' AND ai_agent_id IS NULL)
  ),
  CONSTRAINT tenant_tool_bindings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX tenant_tool_bindings_tenant_scope_unique_idx
  ON public.tenant_tool_bindings (tenant_id, tenant_environment_id, tool_definition_id)
  WHERE binding_scope = 'tenant' AND ai_agent_id IS NULL;

CREATE UNIQUE INDEX tenant_tool_bindings_agent_scope_unique_idx
  ON public.tenant_tool_bindings (tenant_id, tenant_environment_id, tool_definition_id, ai_agent_id)
  WHERE binding_scope = 'agent' AND ai_agent_id IS NOT NULL;

CREATE INDEX tenant_tool_bindings_tenant_env_status_priority_idx
  ON public.tenant_tool_bindings (tenant_id, tenant_environment_id, status, priority ASC);

CREATE TABLE public.tool_execution_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  tool_definition_id bigint NOT NULL,
  tool_version_id bigint NOT NULL,
  tenant_tool_binding_id bigint,
  call_id bigint,
  case_id bigint,
  lead_id bigint,
  requested_by_user_id bigint,
  requested_by_service_account_id bigint,
  idempotency_key_id bigint,
  execution_key text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempt_no integer NOT NULL DEFAULT 1,
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_payload jsonb,
  error_payload jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tool_execution_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT tool_execution_runs_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tool_execution_runs_tenant_execution_key_unique UNIQUE (tenant_id, execution_key),
  CONSTRAINT tool_execution_runs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tool_execution_runs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tool_execution_runs_definition_tenant_fk FOREIGN KEY (tool_definition_id, tenant_id)
    REFERENCES public.tool_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tool_execution_runs_version_tenant_fk FOREIGN KEY (tool_version_id, tenant_id)
    REFERENCES public.tool_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT tool_execution_runs_binding_tenant_fk FOREIGN KEY (tenant_tool_binding_id, tenant_id)
    REFERENCES public.tenant_tool_bindings (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_requested_by_service_account_tenant_fk FOREIGN KEY (requested_by_service_account_id, tenant_id)
    REFERENCES public.service_accounts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_idempotency_key_tenant_fk FOREIGN KEY (idempotency_key_id, tenant_id)
    REFERENCES public.idempotency_keys (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT tool_execution_runs_execution_key_not_blank_check CHECK (btrim(execution_key) <> ''),
  CONSTRAINT tool_execution_runs_status_check CHECK (status IN (
    'pending',
    'in_progress',
    'succeeded',
    'failed',
    'cancelled',
    'retryable'
  )),
  CONSTRAINT tool_execution_runs_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT tool_execution_runs_actor_required_check CHECK (
    requested_by_user_id IS NOT NULL OR requested_by_service_account_id IS NOT NULL
  ),
  CONSTRAINT tool_execution_runs_input_payload_object_check CHECK (jsonb_typeof(input_payload) = 'object'),
  CONSTRAINT tool_execution_runs_output_payload_shape_check CHECK (
    output_payload IS NULL OR jsonb_typeof(output_payload) IN ('object', 'array')
  ),
  CONSTRAINT tool_execution_runs_error_payload_shape_check CHECK (
    error_payload IS NULL OR jsonb_typeof(error_payload) IN ('object', 'array')
  ),
  CONSTRAINT tool_execution_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT tool_execution_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  )
);

CREATE INDEX tool_execution_runs_tenant_status_created_at_idx
  ON public.tool_execution_runs (tenant_id, status, created_at DESC);

CREATE INDEX tool_execution_runs_tenant_tool_version_status_idx
  ON public.tool_execution_runs (tenant_id, tool_version_id, status, created_at DESC);

CREATE INDEX tool_execution_runs_tenant_idempotency_idx
  ON public.tool_execution_runs (tenant_id, idempotency_key_id)
  WHERE idempotency_key_id IS NOT NULL;
