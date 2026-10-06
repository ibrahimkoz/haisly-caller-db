CREATE TABLE public.metric_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  ai_agent_id bigint,
  metric_code text NOT NULL,
  aggregation_window text NOT NULL DEFAULT 'hour',
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  dimension_key text,
  dimension_values jsonb NOT NULL DEFAULT '{}'::jsonb,
  metric_value numeric(20,6) NOT NULL,
  sample_count bigint,
  unit text,
  source text NOT NULL DEFAULT 'system',
  quality_status text NOT NULL DEFAULT 'final',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT metric_snapshots_public_id_unique UNIQUE (public_id),
  CONSTRAINT metric_snapshots_tenant_scope_metric_window_dimension_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    ai_agent_id,
    metric_code,
    aggregation_window,
    window_start,
    dimension_key
  ),
  CONSTRAINT metric_snapshots_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT metric_snapshots_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT metric_snapshots_ai_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT metric_snapshots_metric_code_format_check CHECK (
    metric_code ~ '^[a-z][a-z0-9_.:]{1,119}$'
  ),
  CONSTRAINT metric_snapshots_aggregation_window_check CHECK (aggregation_window IN (
    'minute',
    'hour',
    'day',
    'week',
    'month',
    'custom'
  )),
  CONSTRAINT metric_snapshots_window_bounds_check CHECK (window_end > window_start),
  CONSTRAINT metric_snapshots_dimension_key_not_blank_check CHECK (
    dimension_key IS NULL OR btrim(dimension_key) <> ''
  ),
  CONSTRAINT metric_snapshots_dimension_values_object_check CHECK (
    jsonb_typeof(dimension_values) = 'object'
  ),
  CONSTRAINT metric_snapshots_sample_count_non_negative_check CHECK (
    sample_count IS NULL OR sample_count >= 0
  ),
  CONSTRAINT metric_snapshots_unit_not_blank_check CHECK (
    unit IS NULL OR btrim(unit) <> ''
  ),
  CONSTRAINT metric_snapshots_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT metric_snapshots_quality_status_check CHECK (quality_status IN (
    'draft',
    'partial',
    'final',
    'corrected'
  )),
  CONSTRAINT metric_snapshots_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX metric_snapshots_tenant_metric_window_start_idx
  ON public.metric_snapshots (tenant_id, metric_code, window_start DESC);

CREATE INDEX metric_snapshots_tenant_env_metric_window_start_idx
  ON public.metric_snapshots (tenant_id, tenant_environment_id, metric_code, window_start DESC)
  WHERE tenant_environment_id IS NOT NULL;

CREATE INDEX metric_snapshots_tenant_agent_metric_window_start_idx
  ON public.metric_snapshots (tenant_id, ai_agent_id, metric_code, window_start DESC)
  WHERE ai_agent_id IS NOT NULL;

CREATE TABLE public.report_definitions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  visibility_scope text NOT NULL DEFAULT 'tenant_admin',
  output_format text NOT NULL DEFAULT 'json',
  query_spec jsonb NOT NULL DEFAULT '{}'::jsonb,
  default_filters jsonb NOT NULL DEFAULT '{}'::jsonb,
  schedule_timezone text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT report_definitions_public_id_unique UNIQUE (public_id),
  CONSTRAINT report_definitions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT report_definitions_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT report_definitions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT report_definitions_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT report_definitions_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT report_definitions_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT report_definitions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT report_definitions_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT report_definitions_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT report_definitions_visibility_scope_check CHECK (visibility_scope IN (
    'tenant_admin',
    'operations',
    'billing',
    'platform_internal'
  )),
  CONSTRAINT report_definitions_output_format_check CHECK (output_format IN (
    'json',
    'csv',
    'xlsx',
    'pdf'
  )),
  CONSTRAINT report_definitions_query_spec_object_check CHECK (jsonb_typeof(query_spec) = 'object'),
  CONSTRAINT report_definitions_default_filters_object_check CHECK (
    jsonb_typeof(default_filters) = 'object'
  ),
  CONSTRAINT report_definitions_schedule_timezone_not_blank_check CHECK (
    schedule_timezone IS NULL OR btrim(schedule_timezone) <> ''
  ),
  CONSTRAINT report_definitions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX report_definitions_tenant_status_updated_at_idx
  ON public.report_definitions (tenant_id, status, updated_at DESC);

CREATE INDEX report_definitions_tenant_env_visibility_idx
  ON public.report_definitions (tenant_id, tenant_environment_id, visibility_scope, status);

CREATE TABLE public.scheduled_reports (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  report_definition_id bigint NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  schedule_kind text NOT NULL DEFAULT 'cron',
  schedule_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  recipient_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_format text NOT NULL DEFAULT 'pdf',
  last_run_at timestamptz,
  next_run_at timestamptz,
  last_delivery_status text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_reports_public_id_unique UNIQUE (public_id),
  CONSTRAINT scheduled_reports_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT scheduled_reports_tenant_definition_name_unique UNIQUE (
    tenant_id,
    report_definition_id,
    name
  ),
  CONSTRAINT scheduled_reports_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT scheduled_reports_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT scheduled_reports_definition_tenant_fk FOREIGN KEY (report_definition_id, tenant_id)
    REFERENCES public.report_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT scheduled_reports_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT scheduled_reports_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT scheduled_reports_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled',
    'archived'
  )),
  CONSTRAINT scheduled_reports_schedule_kind_check CHECK (schedule_kind IN (
    'cron',
    'interval',
    'manual'
  )),
  CONSTRAINT scheduled_reports_schedule_config_object_check CHECK (jsonb_typeof(schedule_config) = 'object'),
  CONSTRAINT scheduled_reports_recipient_config_object_check CHECK (jsonb_typeof(recipient_config) = 'object'),
  CONSTRAINT scheduled_reports_output_format_check CHECK (output_format IN (
    'json',
    'csv',
    'xlsx',
    'pdf'
  )),
  CONSTRAINT scheduled_reports_last_delivery_status_check CHECK (
    last_delivery_status IS NULL
    OR last_delivery_status IN ('queued', 'processing', 'delivered', 'failed', 'cancelled')
  ),
  CONSTRAINT scheduled_reports_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX scheduled_reports_tenant_status_next_run_idx
  ON public.scheduled_reports (tenant_id, status, next_run_at ASC);

CREATE INDEX scheduled_reports_tenant_env_status_updated_at_idx
  ON public.scheduled_reports (tenant_id, tenant_environment_id, status, updated_at DESC);

CREATE TABLE public.report_deliveries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  report_definition_id bigint NOT NULL,
  scheduled_report_id bigint,
  artifact_id bigint,
  triggered_by_user_id bigint,
  destination_channel text NOT NULL,
  destination_ref text,
  output_format text NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  generation_params jsonb NOT NULL DEFAULT '{}'::jsonb,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  failure_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT report_deliveries_public_id_unique UNIQUE (public_id),
  CONSTRAINT report_deliveries_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT report_deliveries_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT report_deliveries_definition_tenant_fk FOREIGN KEY (report_definition_id, tenant_id)
    REFERENCES public.report_definitions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT report_deliveries_scheduled_report_tenant_fk FOREIGN KEY (scheduled_report_id, tenant_id)
    REFERENCES public.scheduled_reports (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT report_deliveries_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT report_deliveries_triggered_by_user_tenant_fk FOREIGN KEY (triggered_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT report_deliveries_destination_channel_check CHECK (destination_channel IN (
    'email',
    'slack',
    'webhook',
    'download',
    'internal'
  )),
  CONSTRAINT report_deliveries_destination_ref_not_blank_check CHECK (
    destination_ref IS NULL OR btrim(destination_ref) <> ''
  ),
  CONSTRAINT report_deliveries_output_format_check CHECK (output_format IN (
    'json',
    'csv',
    'xlsx',
    'pdf'
  )),
  CONSTRAINT report_deliveries_status_check CHECK (status IN (
    'queued',
    'processing',
    'delivered',
    'failed',
    'cancelled'
  )),
  CONSTRAINT report_deliveries_generation_params_object_check CHECK (
    jsonb_typeof(generation_params) = 'object'
  ),
  CONSTRAINT report_deliveries_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT report_deliveries_failure_reason_not_blank_check CHECK (
    failure_reason IS NULL OR btrim(failure_reason) <> ''
  ),
  CONSTRAINT report_deliveries_delivered_after_requested_check CHECK (
    delivered_at IS NULL OR delivered_at >= requested_at
  ),
  CONSTRAINT report_deliveries_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT report_deliveries_failed_requires_reason_check CHECK (
    status <> 'failed' OR failure_reason IS NOT NULL
  )
);

CREATE INDEX report_deliveries_tenant_status_requested_at_idx
  ON public.report_deliveries (tenant_id, status, requested_at DESC);

CREATE INDEX report_deliveries_tenant_definition_status_idx
  ON public.report_deliveries (tenant_id, report_definition_id, status, updated_at DESC);

CREATE INDEX report_deliveries_tenant_scheduled_status_idx
  ON public.report_deliveries (tenant_id, scheduled_report_id, status, requested_at DESC)
  WHERE scheduled_report_id IS NOT NULL;
