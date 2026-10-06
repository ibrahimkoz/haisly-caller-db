CREATE TABLE public.agent_config_improvement_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  agent_config_version_id bigint NOT NULL,
  requested_by_user_id bigint NOT NULL,
  provider text NOT NULL,
  model text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  source_hash text NOT NULL,
  source_snapshot jsonb NOT NULL,
  proposal_snapshot jsonb,
  warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
  provider_response_id text,
  input_tokens integer,
  output_tokens integer,
  failure_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  applied_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  CONSTRAINT agent_config_improvement_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_config_improvement_runs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_improvement_runs_version_tenant_fk FOREIGN KEY (
    agent_config_version_id,
    tenant_id
  ) REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_improvement_runs_requester_tenant_fk FOREIGN KEY (
    requested_by_user_id,
    tenant_id
  ) REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT agent_config_improvement_runs_provider_not_blank_check CHECK (btrim(provider) <> ''),
  CONSTRAINT agent_config_improvement_runs_model_not_blank_check CHECK (btrim(model) <> ''),
  CONSTRAINT agent_config_improvement_runs_status_check CHECK (status IN (
    'pending',
    'completed',
    'failed',
    'applied',
    'expired'
  )),
  CONSTRAINT agent_config_improvement_runs_source_hash_check CHECK (
    source_hash ~ '^[a-f0-9]{64}$'
  ),
  CONSTRAINT agent_config_improvement_runs_source_snapshot_object_check CHECK (
    jsonb_typeof(source_snapshot) = 'object'
  ),
  CONSTRAINT agent_config_improvement_runs_proposal_snapshot_object_check CHECK (
    proposal_snapshot IS NULL OR jsonb_typeof(proposal_snapshot) = 'object'
  ),
  CONSTRAINT agent_config_improvement_runs_warnings_array_check CHECK (
    jsonb_typeof(warnings) = 'array'
  ),
  CONSTRAINT agent_config_improvement_runs_input_tokens_non_negative_check CHECK (
    input_tokens IS NULL OR input_tokens >= 0
  ),
  CONSTRAINT agent_config_improvement_runs_output_tokens_non_negative_check CHECK (
    output_tokens IS NULL OR output_tokens >= 0
  ),
  CONSTRAINT agent_config_improvement_runs_failure_code_not_blank_check CHECK (
    failure_code IS NULL OR btrim(failure_code) <> ''
  ),
  CONSTRAINT agent_config_improvement_runs_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT agent_config_improvement_runs_completion_state_check CHECK (
    (status = 'pending' AND completed_at IS NULL AND applied_at IS NULL)
    OR (status = 'failed' AND completed_at IS NOT NULL AND applied_at IS NULL)
    OR (status = 'completed' AND completed_at IS NOT NULL AND applied_at IS NULL)
    OR (status = 'applied' AND completed_at IS NOT NULL AND applied_at IS NOT NULL)
    OR (status = 'expired' AND completed_at IS NOT NULL)
  )
);

CREATE INDEX agent_config_improvement_runs_tenant_version_created_idx
  ON public.agent_config_improvement_runs (
    tenant_id,
    agent_config_version_id,
    created_at DESC
  );

CREATE INDEX agent_config_improvement_runs_expiry_status_idx
  ON public.agent_config_improvement_runs (expires_at, status)
  WHERE status IN ('pending', 'completed');

COMMENT ON TABLE public.agent_config_improvement_runs IS
  'Tenant-scoped, expiring AI suggestions for draft agent configuration sections; proposals require explicit apply.';
