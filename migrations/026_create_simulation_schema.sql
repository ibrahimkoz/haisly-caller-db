CREATE TABLE public.simulation_scenarios (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft',
  trigger_mode text NOT NULL DEFAULT 'manual',
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  expected_outcomes jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT simulation_scenarios_public_id_unique UNIQUE (public_id),
  CONSTRAINT simulation_scenarios_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT simulation_scenarios_tenant_env_code_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    code
  ),
  CONSTRAINT simulation_scenarios_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_scenarios_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_scenarios_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_scenarios_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT simulation_scenarios_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT simulation_scenarios_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT simulation_scenarios_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT simulation_scenarios_status_check CHECK (status IN (
    'draft',
    'active',
    'archived'
  )),
  CONSTRAINT simulation_scenarios_trigger_mode_check CHECK (trigger_mode IN (
    'manual',
    'publish_gate',
    'scheduled'
  )),
  CONSTRAINT simulation_scenarios_input_payload_object_check CHECK (
    jsonb_typeof(input_payload) = 'object'
  ),
  CONSTRAINT simulation_scenarios_expected_outcomes_object_check CHECK (
    jsonb_typeof(expected_outcomes) = 'object'
  ),
  CONSTRAINT simulation_scenarios_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX simulation_scenarios_tenant_env_status_updated_at_idx
  ON public.simulation_scenarios (tenant_id, tenant_environment_id, status, updated_at DESC);

CREATE INDEX simulation_scenarios_tenant_agent_status_idx
  ON public.simulation_scenarios (tenant_id, ai_agent_id, status);

CREATE TABLE public.simulation_assertions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  simulation_scenario_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  assertion_type text NOT NULL,
  severity text NOT NULL DEFAULT 'error',
  expected_expression jsonb NOT NULL DEFAULT '{}'::jsonb,
  expected_value jsonb,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT simulation_assertions_public_id_unique UNIQUE (public_id),
  CONSTRAINT simulation_assertions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT simulation_assertions_scenario_code_unique UNIQUE (simulation_scenario_id, code),
  CONSTRAINT simulation_assertions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_assertions_scenario_tenant_fk FOREIGN KEY (simulation_scenario_id, tenant_id)
    REFERENCES public.simulation_scenarios (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_assertions_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT simulation_assertions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT simulation_assertions_type_check CHECK (assertion_type IN (
    'intent',
    'output',
    'tool_call',
    'guardrail',
    'latency',
    'custom'
  )),
  CONSTRAINT simulation_assertions_severity_check CHECK (severity IN (
    'info',
    'warning',
    'error',
    'critical'
  )),
  CONSTRAINT simulation_assertions_expression_object_check CHECK (
    jsonb_typeof(expected_expression) = 'object'
  ),
  CONSTRAINT simulation_assertions_expected_value_shape_check CHECK (
    expected_value IS NULL OR jsonb_typeof(expected_value) IN ('object', 'array', 'string', 'number', 'boolean')
  ),
  CONSTRAINT simulation_assertions_status_check CHECK (status IN (
    'active',
    'disabled'
  )),
  CONSTRAINT simulation_assertions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX simulation_assertions_tenant_scenario_status_idx
  ON public.simulation_assertions (tenant_id, simulation_scenario_id, status);

CREATE TABLE public.simulation_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  simulation_scenario_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  agent_config_version_id bigint,
  requested_by_user_id bigint,
  run_mode text NOT NULL DEFAULT 'manual',
  status text NOT NULL DEFAULT 'queued',
  gate_decision text NOT NULL DEFAULT 'pending',
  gate_reason text,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT simulation_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT simulation_runs_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT simulation_runs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_runs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_runs_scenario_tenant_fk FOREIGN KEY (simulation_scenario_id, tenant_id)
    REFERENCES public.simulation_scenarios (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_runs_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_runs_agent_config_version_tenant_fk FOREIGN KEY (agent_config_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT simulation_runs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT simulation_runs_run_mode_check CHECK (run_mode IN (
    'manual',
    'publish_gate',
    'regression'
  )),
  CONSTRAINT simulation_runs_status_check CHECK (status IN (
    'queued',
    'running',
    'passed',
    'failed',
    'cancelled',
    'error'
  )),
  CONSTRAINT simulation_runs_gate_decision_check CHECK (gate_decision IN (
    'pending',
    'not_required',
    'pass',
    'fail',
    'waived'
  )),
  CONSTRAINT simulation_runs_gate_reason_not_blank_check CHECK (
    gate_reason IS NULL OR btrim(gate_reason) <> ''
  ),
  CONSTRAINT simulation_runs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT simulation_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT simulation_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT simulation_runs_gate_decision_requires_terminal_state_check CHECK (
    gate_decision IN ('pending', 'not_required')
    OR status IN ('passed', 'failed', 'cancelled', 'error')
  )
);

CREATE INDEX simulation_runs_tenant_env_status_created_at_idx
  ON public.simulation_runs (tenant_id, tenant_environment_id, status, created_at DESC);

CREATE INDEX simulation_runs_tenant_scenario_created_at_idx
  ON public.simulation_runs (tenant_id, simulation_scenario_id, created_at DESC);

CREATE INDEX simulation_runs_tenant_gate_decision_completed_at_idx
  ON public.simulation_runs (tenant_id, gate_decision, completed_at DESC);

CREATE TABLE public.simulation_run_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  simulation_run_id bigint NOT NULL,
  simulation_assertion_id bigint,
  event_type text NOT NULL,
  event_level text NOT NULL DEFAULT 'info',
  event_status text,
  message text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT simulation_run_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT simulation_run_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_run_events_run_tenant_fk FOREIGN KEY (simulation_run_id, tenant_id)
    REFERENCES public.simulation_runs (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT simulation_run_events_assertion_tenant_fk FOREIGN KEY (simulation_assertion_id, tenant_id)
    REFERENCES public.simulation_assertions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT simulation_run_events_event_type_check CHECK (event_type IN (
    'run_started',
    'run_completed',
    'assertion_evaluated',
    'assertion_failed',
    'gate_evaluated',
    'log'
  )),
  CONSTRAINT simulation_run_events_event_level_check CHECK (event_level IN (
    'debug',
    'info',
    'warning',
    'error'
  )),
  CONSTRAINT simulation_run_events_event_status_check CHECK (
    event_status IS NULL OR event_status IN ('queued', 'running', 'passed', 'failed', 'cancelled', 'error')
  ),
  CONSTRAINT simulation_run_events_message_not_blank_check CHECK (
    message IS NULL OR btrim(message) <> ''
  ),
  CONSTRAINT simulation_run_events_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT simulation_run_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX simulation_run_events_tenant_run_occurred_at_idx
  ON public.simulation_run_events (tenant_id, simulation_run_id, occurred_at DESC);

CREATE INDEX simulation_run_events_tenant_type_occurred_at_idx
  ON public.simulation_run_events (tenant_id, event_type, occurred_at DESC);
