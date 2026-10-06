CREATE TABLE public.call_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  call_id bigint,
  ai_agent_id bigint,
  agent_config_version_id bigint,
  runtime_session_ref text NOT NULL,
  status text NOT NULL DEFAULT 'initiated',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_sessions_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_sessions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT call_sessions_tenant_runtime_ref_unique UNIQUE (tenant_id, runtime_session_ref),
  CONSTRAINT call_sessions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_sessions_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_sessions_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT call_sessions_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT call_sessions_agent_config_version_tenant_fk FOREIGN KEY (agent_config_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT call_sessions_runtime_ref_not_blank_check CHECK (btrim(runtime_session_ref) <> ''),
  CONSTRAINT call_sessions_status_check CHECK (status IN (
    'initiated',
    'active',
    'handoff',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT call_sessions_duration_non_negative_check CHECK (
    duration_seconds IS NULL OR duration_seconds >= 0
  ),
  CONSTRAINT call_sessions_ended_after_started_check CHECK (
    ended_at IS NULL OR ended_at >= started_at
  ),
  CONSTRAINT call_sessions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX call_sessions_tenant_status_started_at_idx
  ON public.call_sessions (tenant_id, status, started_at DESC);

CREATE INDEX call_sessions_tenant_call_started_at_idx
  ON public.call_sessions (tenant_id, call_id, started_at DESC)
  WHERE call_id IS NOT NULL;

CREATE TABLE public.call_session_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_session_id bigint NOT NULL,
  event_type text NOT NULL,
  source text,
  idempotency_key text,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_session_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_session_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_session_events_session_tenant_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_session_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT call_session_events_source_not_blank_check CHECK (
    source IS NULL OR btrim(source) <> ''
  ),
  CONSTRAINT call_session_events_idempotency_key_not_blank_check CHECK (
    idempotency_key IS NULL OR btrim(idempotency_key) <> ''
  ),
  CONSTRAINT call_session_events_event_payload_object_check CHECK (jsonb_typeof(event_payload) = 'object')
);

CREATE UNIQUE INDEX call_session_events_session_idempotency_unique_idx
  ON public.call_session_events (call_session_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX call_session_events_session_occurred_at_idx
  ON public.call_session_events (call_session_id, occurred_at ASC);

CREATE INDEX call_session_events_tenant_event_type_occurred_idx
  ON public.call_session_events (tenant_id, event_type, occurred_at DESC);

CREATE TABLE public.call_tool_executions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_session_id bigint NOT NULL,
  tool_execution_run_id bigint,
  tool_definition_id bigint NOT NULL,
  tool_version_id bigint NOT NULL,
  request_ref text NOT NULL,
  status text NOT NULL DEFAULT 'requested',
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_payload jsonb,
  error_payload jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_tool_executions_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_tool_executions_tenant_session_request_unique UNIQUE (
    tenant_id,
    call_session_id,
    request_ref
  ),
  CONSTRAINT call_tool_executions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_tool_executions_session_tenant_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_tool_executions_execution_run_tenant_fk FOREIGN KEY (tool_execution_run_id, tenant_id)
    REFERENCES public.tool_execution_runs (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT call_tool_executions_definition_tenant_fk FOREIGN KEY (tool_definition_id, tenant_id)
    REFERENCES public.tool_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_tool_executions_version_tenant_fk FOREIGN KEY (tool_version_id, tenant_id)
    REFERENCES public.tool_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_tool_executions_request_ref_not_blank_check CHECK (btrim(request_ref) <> ''),
  CONSTRAINT call_tool_executions_status_check CHECK (status IN (
    'requested',
    'in_progress',
    'succeeded',
    'failed',
    'cancelled'
  )),
  CONSTRAINT call_tool_executions_input_payload_object_check CHECK (jsonb_typeof(input_payload) = 'object'),
  CONSTRAINT call_tool_executions_output_payload_shape_check CHECK (
    output_payload IS NULL OR jsonb_typeof(output_payload) IN ('object', 'array')
  ),
  CONSTRAINT call_tool_executions_error_payload_shape_check CHECK (
    error_payload IS NULL OR jsonb_typeof(error_payload) IN ('object', 'array')
  ),
  CONSTRAINT call_tool_executions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT call_tool_executions_completed_after_requested_check CHECK (
    completed_at IS NULL OR completed_at >= requested_at
  )
);

CREATE INDEX call_tool_executions_session_status_requested_at_idx
  ON public.call_tool_executions (call_session_id, status, requested_at DESC);

CREATE INDEX call_tool_executions_tenant_status_requested_at_idx
  ON public.call_tool_executions (tenant_id, status, requested_at DESC);
