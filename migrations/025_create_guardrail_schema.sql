CREATE TABLE public.guardrail_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guardrail_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT guardrail_policies_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT guardrail_policies_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT guardrail_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT guardrail_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT guardrail_policies_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT guardrail_policies_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT guardrail_policies_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT guardrail_policies_status_check CHECK (status IN (
    'draft',
    'active',
    'deprecated',
    'disabled'
  )),
  CONSTRAINT guardrail_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX guardrail_policies_tenant_status_updated_at_idx
  ON public.guardrail_policies (tenant_id, status, updated_at DESC);

CREATE TABLE public.guardrail_policy_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  guardrail_policy_id bigint NOT NULL,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  rules_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  published_at timestamptz,
  archived_at timestamptz,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guardrail_policy_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT guardrail_policy_versions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT guardrail_policy_versions_policy_version_unique UNIQUE (guardrail_policy_id, version_no),
  CONSTRAINT guardrail_policy_versions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT guardrail_policy_versions_policy_tenant_fk FOREIGN KEY (guardrail_policy_id, tenant_id)
    REFERENCES public.guardrail_policies (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT guardrail_policy_versions_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT guardrail_policy_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT guardrail_policy_versions_status_check CHECK (status IN (
    'draft',
    'published',
    'archived'
  )),
  CONSTRAINT guardrail_policy_versions_rules_object_check CHECK (jsonb_typeof(rules_config) = 'object'),
  CONSTRAINT guardrail_policy_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT guardrail_policy_versions_archived_requires_status_check CHECK (
    archived_at IS NULL OR status = 'archived'
  )
);

CREATE INDEX guardrail_policy_versions_tenant_status_updated_at_idx
  ON public.guardrail_policy_versions (tenant_id, status, updated_at DESC);

CREATE TABLE public.agent_guardrail_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  guardrail_policy_id bigint NOT NULL,
  guardrail_policy_version_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_guardrail_bindings_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_guardrail_bindings_tenant_env_agent_policy_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    ai_agent_id,
    guardrail_policy_id
  ),
  CONSTRAINT agent_guardrail_bindings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_guardrail_bindings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_guardrail_bindings_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_guardrail_bindings_policy_tenant_fk FOREIGN KEY (guardrail_policy_id, tenant_id)
    REFERENCES public.guardrail_policies (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_guardrail_bindings_policy_version_tenant_fk FOREIGN KEY (guardrail_policy_version_id, tenant_id)
    REFERENCES public.guardrail_policy_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_guardrail_bindings_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_guardrail_bindings_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT agent_guardrail_bindings_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT agent_guardrail_bindings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX agent_guardrail_bindings_tenant_env_status_priority_idx
  ON public.agent_guardrail_bindings (tenant_id, tenant_environment_id, status, priority ASC);

CREATE TABLE public.policy_evaluation_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  call_session_id bigint,
  guardrail_policy_id bigint,
  guardrail_policy_version_id bigint,
  source text NOT NULL,
  evaluation_result text NOT NULL,
  matched_rule_code text,
  confidence numeric(5,4),
  input_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_snapshot jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT policy_evaluation_logs_public_id_unique UNIQUE (public_id),
  CONSTRAINT policy_evaluation_logs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT policy_evaluation_logs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT policy_evaluation_logs_call_session_tenant_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT policy_evaluation_logs_policy_tenant_fk FOREIGN KEY (guardrail_policy_id, tenant_id)
    REFERENCES public.guardrail_policies (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT policy_evaluation_logs_policy_version_tenant_fk FOREIGN KEY (guardrail_policy_version_id, tenant_id)
    REFERENCES public.guardrail_policy_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT policy_evaluation_logs_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT policy_evaluation_logs_result_check CHECK (evaluation_result IN (
    'allow',
    'deny',
    'escalate',
    'review',
    'error'
  )),
  CONSTRAINT policy_evaluation_logs_rule_code_not_blank_check CHECK (
    matched_rule_code IS NULL OR btrim(matched_rule_code) <> ''
  ),
  CONSTRAINT policy_evaluation_logs_confidence_range_check CHECK (
    confidence IS NULL OR (confidence >= 0 AND confidence <= 1)
  ),
  CONSTRAINT policy_evaluation_logs_input_object_check CHECK (jsonb_typeof(input_snapshot) = 'object'),
  CONSTRAINT policy_evaluation_logs_output_shape_check CHECK (
    output_snapshot IS NULL OR jsonb_typeof(output_snapshot) IN ('object', 'array')
  ),
  CONSTRAINT policy_evaluation_logs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX policy_evaluation_logs_tenant_result_occurred_at_idx
  ON public.policy_evaluation_logs (tenant_id, evaluation_result, occurred_at DESC);

CREATE INDEX policy_evaluation_logs_tenant_policy_occurred_at_idx
  ON public.policy_evaluation_logs (tenant_id, guardrail_policy_id, occurred_at DESC)
  WHERE guardrail_policy_id IS NOT NULL;
