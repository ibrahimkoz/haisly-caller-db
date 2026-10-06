CREATE TABLE public.feature_flags (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  scope_type text NOT NULL DEFAULT 'global',
  flag_key text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'disabled',
  rollout_percentage integer NOT NULL DEFAULT 0,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT feature_flags_public_id_unique UNIQUE (public_id),
  CONSTRAINT feature_flags_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT feature_flags_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT feature_flags_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT feature_flags_scope_type_check CHECK (scope_type IN (
    'global',
    'tenant',
    'environment'
  )),
  CONSTRAINT feature_flags_scope_columns_check CHECK (
    (scope_type = 'global' AND tenant_id IS NULL AND tenant_environment_id IS NULL)
    OR (scope_type = 'tenant' AND tenant_id IS NOT NULL AND tenant_environment_id IS NULL)
    OR (scope_type = 'environment' AND tenant_id IS NOT NULL AND tenant_environment_id IS NOT NULL)
  ),
  CONSTRAINT feature_flags_key_not_blank_check CHECK (btrim(flag_key) <> ''),
  CONSTRAINT feature_flags_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT feature_flags_status_check CHECK (status IN (
    'enabled',
    'disabled',
    'gradual'
  )),
  CONSTRAINT feature_flags_rollout_range_check CHECK (
    rollout_percentage >= 0 AND rollout_percentage <= 100
  ),
  CONSTRAINT feature_flags_conditions_object_check CHECK (jsonb_typeof(conditions) = 'object'),
  CONSTRAINT feature_flags_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX feature_flags_global_key_unique_idx
  ON public.feature_flags (flag_key)
  WHERE scope_type = 'global';

CREATE UNIQUE INDEX feature_flags_tenant_key_unique_idx
  ON public.feature_flags (tenant_id, flag_key)
  WHERE scope_type = 'tenant';

CREATE UNIQUE INDEX feature_flags_environment_key_unique_idx
  ON public.feature_flags (tenant_id, tenant_environment_id, flag_key)
  WHERE scope_type = 'environment';

CREATE INDEX feature_flags_scope_status_updated_at_idx
  ON public.feature_flags (scope_type, status, updated_at DESC);

CREATE TABLE public.migration_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  job_name text NOT NULL,
  target_version text NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  strategy text NOT NULL DEFAULT 'online',
  lock_key text,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_platform_admin_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT migration_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT migration_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT migration_jobs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT migration_jobs_created_by_platform_admin_fk FOREIGN KEY (created_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT migration_jobs_name_not_blank_check CHECK (btrim(job_name) <> ''),
  CONSTRAINT migration_jobs_target_version_not_blank_check CHECK (btrim(target_version) <> ''),
  CONSTRAINT migration_jobs_status_check CHECK (status IN (
    'queued',
    'running',
    'succeeded',
    'failed',
    'rolled_back',
    'cancelled'
  )),
  CONSTRAINT migration_jobs_strategy_check CHECK (strategy IN (
    'online',
    'offline',
    'blue_green'
  )),
  CONSTRAINT migration_jobs_lock_key_not_blank_check CHECK (
    lock_key IS NULL OR btrim(lock_key) <> ''
  ),
  CONSTRAINT migration_jobs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT migration_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT migration_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX migration_jobs_status_created_at_idx
  ON public.migration_jobs (status, created_at DESC);

CREATE TABLE public.backup_restore_drills (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  drill_type text NOT NULL,
  status text NOT NULL DEFAULT 'planned',
  backup_ref text,
  restore_target_ref text,
  rpo_seconds integer,
  rto_seconds integer,
  findings jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_platform_admin_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT backup_restore_drills_public_id_unique UNIQUE (public_id),
  CONSTRAINT backup_restore_drills_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT backup_restore_drills_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT backup_restore_drills_created_by_platform_admin_fk FOREIGN KEY (created_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT backup_restore_drills_type_check CHECK (drill_type IN (
    'backup',
    'restore',
    'failover'
  )),
  CONSTRAINT backup_restore_drills_status_check CHECK (status IN (
    'planned',
    'running',
    'succeeded',
    'failed',
    'cancelled'
  )),
  CONSTRAINT backup_restore_drills_backup_ref_not_blank_check CHECK (
    backup_ref IS NULL OR btrim(backup_ref) <> ''
  ),
  CONSTRAINT backup_restore_drills_restore_target_not_blank_check CHECK (
    restore_target_ref IS NULL OR btrim(restore_target_ref) <> ''
  ),
  CONSTRAINT backup_restore_drills_rpo_non_negative_check CHECK (
    rpo_seconds IS NULL OR rpo_seconds >= 0
  ),
  CONSTRAINT backup_restore_drills_rto_non_negative_check CHECK (
    rto_seconds IS NULL OR rto_seconds >= 0
  ),
  CONSTRAINT backup_restore_drills_findings_object_check CHECK (jsonb_typeof(findings) = 'object'),
  CONSTRAINT backup_restore_drills_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT backup_restore_drills_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX backup_restore_drills_status_created_at_idx
  ON public.backup_restore_drills (status, created_at DESC);

CREATE TABLE public.search_index_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  entity_type text NOT NULL,
  entity_public_id uuid,
  operation text NOT NULL DEFAULT 'upsert',
  status text NOT NULL DEFAULT 'queued',
  attempt_no integer NOT NULL DEFAULT 1,
  max_attempts integer NOT NULL DEFAULT 5,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_message text,
  queued_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT search_index_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT search_index_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT search_index_jobs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT search_index_jobs_entity_type_not_blank_check CHECK (btrim(entity_type) <> ''),
  CONSTRAINT search_index_jobs_operation_check CHECK (operation IN (
    'upsert',
    'delete',
    'full_reindex'
  )),
  CONSTRAINT search_index_jobs_status_check CHECK (status IN (
    'queued',
    'processing',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT search_index_jobs_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT search_index_jobs_max_attempts_positive_check CHECK (max_attempts > 0),
  CONSTRAINT search_index_jobs_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT search_index_jobs_error_message_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT search_index_jobs_processed_after_queued_check CHECK (
    processed_at IS NULL OR processed_at >= queued_at
  ),
  CONSTRAINT search_index_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX search_index_jobs_tenant_status_queued_at_idx
  ON public.search_index_jobs (tenant_id, status, queued_at ASC);

CREATE TABLE public.import_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  job_type text NOT NULL,
  source_format text NOT NULL,
  source_ref text NOT NULL,
  artifact_id bigint,
  status text NOT NULL DEFAULT 'queued',
  total_rows integer,
  processed_rows integer,
  error_rows integer,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  requested_by_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT import_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT import_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT import_jobs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT import_jobs_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT import_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT import_jobs_job_type_not_blank_check CHECK (btrim(job_type) <> ''),
  CONSTRAINT import_jobs_source_format_check CHECK (source_format IN (
    'csv',
    'xlsx',
    'json',
    'xml',
    'custom'
  )),
  CONSTRAINT import_jobs_source_ref_not_blank_check CHECK (btrim(source_ref) <> ''),
  CONSTRAINT import_jobs_status_check CHECK (status IN (
    'queued',
    'processing',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT import_jobs_total_rows_non_negative_check CHECK (
    total_rows IS NULL OR total_rows >= 0
  ),
  CONSTRAINT import_jobs_processed_rows_non_negative_check CHECK (
    processed_rows IS NULL OR processed_rows >= 0
  ),
  CONSTRAINT import_jobs_error_rows_non_negative_check CHECK (
    error_rows IS NULL OR error_rows >= 0
  ),
  CONSTRAINT import_jobs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT import_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT import_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX import_jobs_tenant_status_created_at_idx
  ON public.import_jobs (tenant_id, status, created_at DESC);

CREATE TABLE public.export_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  job_type text NOT NULL,
  output_format text NOT NULL,
  destination_ref text,
  artifact_id bigint,
  status text NOT NULL DEFAULT 'queued',
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  requested_by_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT export_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT export_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT export_jobs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT export_jobs_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT export_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT export_jobs_job_type_not_blank_check CHECK (btrim(job_type) <> ''),
  CONSTRAINT export_jobs_output_format_check CHECK (output_format IN (
    'csv',
    'xlsx',
    'json',
    'pdf',
    'zip',
    'custom'
  )),
  CONSTRAINT export_jobs_destination_ref_not_blank_check CHECK (
    destination_ref IS NULL OR btrim(destination_ref) <> ''
  ),
  CONSTRAINT export_jobs_status_check CHECK (status IN (
    'queued',
    'processing',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT export_jobs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT export_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT export_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX export_jobs_tenant_status_created_at_idx
  ON public.export_jobs (tenant_id, status, created_at DESC);

CREATE TABLE public.slo_definitions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  code text NOT NULL,
  name text NOT NULL,
  service_scope text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  objective_percentage numeric(5,2) NOT NULL,
  evaluation_window text NOT NULL DEFAULT '30d',
  target_latency_ms integer,
  error_budget_policy jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_platform_admin_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT slo_definitions_public_id_unique UNIQUE (public_id),
  CONSTRAINT slo_definitions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT slo_definitions_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT slo_definitions_created_by_platform_admin_fk FOREIGN KEY (created_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT slo_definitions_scope_columns_check CHECK (
    (tenant_id IS NULL AND tenant_environment_id IS NULL)
    OR (tenant_id IS NOT NULL)
  ),
  CONSTRAINT slo_definitions_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT slo_definitions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT slo_definitions_service_scope_not_blank_check CHECK (btrim(service_scope) <> ''),
  CONSTRAINT slo_definitions_status_check CHECK (status IN (
    'active',
    'paused',
    'retired'
  )),
  CONSTRAINT slo_definitions_objective_range_check CHECK (
    objective_percentage > 0 AND objective_percentage <= 100
  ),
  CONSTRAINT slo_definitions_evaluation_window_not_blank_check CHECK (
    btrim(evaluation_window) <> ''
  ),
  CONSTRAINT slo_definitions_target_latency_non_negative_check CHECK (
    target_latency_ms IS NULL OR target_latency_ms >= 0
  ),
  CONSTRAINT slo_definitions_error_budget_policy_object_check CHECK (
    jsonb_typeof(error_budget_policy) = 'object'
  ),
  CONSTRAINT slo_definitions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX slo_definitions_scope_code_unique_idx
  ON public.slo_definitions (tenant_id, tenant_environment_id, code);

CREATE INDEX slo_definitions_status_updated_at_idx
  ON public.slo_definitions (status, updated_at DESC);

CREATE TABLE public.alert_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  slo_definition_id bigint,
  code text NOT NULL,
  name text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'active',
  condition_spec jsonb NOT NULL DEFAULT '{}'::jsonb,
  channel_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_platform_admin_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT alert_rules_public_id_unique UNIQUE (public_id),
  CONSTRAINT alert_rules_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT alert_rules_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT alert_rules_slo_definition_fk FOREIGN KEY (slo_definition_id)
    REFERENCES public.slo_definitions (id)
    ON DELETE SET NULL,
  CONSTRAINT alert_rules_created_by_platform_admin_fk FOREIGN KEY (created_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT alert_rules_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT alert_rules_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT alert_rules_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT alert_rules_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT alert_rules_condition_spec_object_check CHECK (jsonb_typeof(condition_spec) = 'object'),
  CONSTRAINT alert_rules_channel_config_object_check CHECK (jsonb_typeof(channel_config) = 'object'),
  CONSTRAINT alert_rules_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX alert_rules_scope_code_unique_idx
  ON public.alert_rules (tenant_id, tenant_environment_id, code);

CREATE INDEX alert_rules_status_severity_updated_at_idx
  ON public.alert_rules (status, severity, updated_at DESC);

CREATE TABLE public.alert_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  alert_rule_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'triggered',
  summary text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  triggered_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  acknowledged_by_platform_admin_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT alert_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT alert_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT alert_events_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT alert_events_alert_rule_fk FOREIGN KEY (alert_rule_id)
    REFERENCES public.alert_rules (id)
    ON DELETE CASCADE,
  CONSTRAINT alert_events_acknowledged_by_platform_admin_fk FOREIGN KEY (acknowledged_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT alert_events_status_check CHECK (status IN (
    'triggered',
    'acknowledged',
    'resolved',
    'suppressed'
  )),
  CONSTRAINT alert_events_summary_not_blank_check CHECK (btrim(summary) <> ''),
  CONSTRAINT alert_events_detail_object_check CHECK (jsonb_typeof(detail) = 'object'),
  CONSTRAINT alert_events_acknowledged_after_triggered_check CHECK (
    acknowledged_at IS NULL OR acknowledged_at >= triggered_at
  ),
  CONSTRAINT alert_events_resolved_after_triggered_check CHECK (
    resolved_at IS NULL OR resolved_at >= triggered_at
  ),
  CONSTRAINT alert_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX alert_events_status_triggered_at_idx
  ON public.alert_events (status, triggered_at DESC);

CREATE INDEX alert_events_tenant_status_triggered_at_idx
  ON public.alert_events (tenant_id, status, triggered_at DESC)
  WHERE tenant_id IS NOT NULL;

CREATE TABLE public.operational_incidents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  tenant_environment_id bigint,
  alert_event_id bigint,
  source text NOT NULL,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  owner_platform_admin_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT operational_incidents_public_id_unique UNIQUE (public_id),
  CONSTRAINT operational_incidents_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT operational_incidents_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT operational_incidents_alert_event_fk FOREIGN KEY (alert_event_id)
    REFERENCES public.alert_events (id)
    ON DELETE SET NULL,
  CONSTRAINT operational_incidents_owner_platform_admin_fk FOREIGN KEY (owner_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT operational_incidents_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT operational_incidents_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT operational_incidents_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT operational_incidents_status_check CHECK (status IN (
    'open',
    'investigating',
    'mitigated',
    'resolved',
    'cancelled'
  )),
  CONSTRAINT operational_incidents_detail_object_check CHECK (jsonb_typeof(detail) = 'object'),
  CONSTRAINT operational_incidents_resolved_after_detected_check CHECK (
    resolved_at IS NULL OR resolved_at >= detected_at
  ),
  CONSTRAINT operational_incidents_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX operational_incidents_status_severity_detected_at_idx
  ON public.operational_incidents (status, severity, detected_at DESC);

CREATE TABLE public.quota_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  quota_code text NOT NULL,
  quota_scope text NOT NULL DEFAULT 'tenant',
  period_unit text NOT NULL DEFAULT 'month',
  hard_limit numeric(20,6) NOT NULL,
  soft_limit_percentage numeric(5,2),
  enforcement_mode text NOT NULL DEFAULT 'warn',
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT quota_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT quota_policies_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT quota_policies_tenant_scope_code_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    quota_code
  ),
  CONSTRAINT quota_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT quota_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT quota_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT quota_policies_quota_code_not_blank_check CHECK (btrim(quota_code) <> ''),
  CONSTRAINT quota_policies_scope_check CHECK (quota_scope IN (
    'tenant',
    'environment',
    'agent',
    'feature'
  )),
  CONSTRAINT quota_policies_period_unit_check CHECK (period_unit IN (
    'minute',
    'hour',
    'day',
    'week',
    'month'
  )),
  CONSTRAINT quota_policies_hard_limit_positive_check CHECK (hard_limit > 0),
  CONSTRAINT quota_policies_soft_limit_range_check CHECK (
    soft_limit_percentage IS NULL OR (soft_limit_percentage > 0 AND soft_limit_percentage <= 100)
  ),
  CONSTRAINT quota_policies_enforcement_mode_check CHECK (enforcement_mode IN (
    'warn',
    'throttle',
    'block'
  )),
  CONSTRAINT quota_policies_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT quota_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX quota_policies_tenant_status_updated_at_idx
  ON public.quota_policies (tenant_id, status, updated_at DESC);

CREATE TABLE public.quota_usage_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  quota_policy_id bigint NOT NULL,
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  used_amount numeric(20,6) NOT NULL DEFAULT 0,
  usage_percentage numeric(6,3),
  status text NOT NULL DEFAULT 'within_limit',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT quota_usage_snapshots_public_id_unique UNIQUE (public_id),
  CONSTRAINT quota_usage_snapshots_tenant_policy_window_unique UNIQUE (
    tenant_id,
    quota_policy_id,
    window_start
  ),
  CONSTRAINT quota_usage_snapshots_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT quota_usage_snapshots_quota_policy_tenant_fk FOREIGN KEY (quota_policy_id, tenant_id)
    REFERENCES public.quota_policies (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT quota_usage_snapshots_window_bounds_check CHECK (window_end > window_start),
  CONSTRAINT quota_usage_snapshots_used_amount_non_negative_check CHECK (used_amount >= 0),
  CONSTRAINT quota_usage_snapshots_usage_percentage_range_check CHECK (
    usage_percentage IS NULL OR usage_percentage >= 0
  ),
  CONSTRAINT quota_usage_snapshots_status_check CHECK (status IN (
    'within_limit',
    'near_limit',
    'over_limit'
  )),
  CONSTRAINT quota_usage_snapshots_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX quota_usage_snapshots_tenant_status_window_start_idx
  ON public.quota_usage_snapshots (tenant_id, status, window_start DESC);
