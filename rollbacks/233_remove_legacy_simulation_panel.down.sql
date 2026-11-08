-- Restores schema only. Deleted legacy records require the pre-migration backup.
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
