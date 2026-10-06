DROP INDEX IF EXISTS public.quota_usage_snapshots_tenant_status_window_start_idx;

DROP TABLE IF EXISTS public.quota_usage_snapshots;

DROP INDEX IF EXISTS public.quota_policies_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.quota_policies;

DROP INDEX IF EXISTS public.operational_incidents_status_severity_detected_at_idx;

DROP TABLE IF EXISTS public.operational_incidents;

DROP INDEX IF EXISTS public.alert_events_tenant_status_triggered_at_idx;
DROP INDEX IF EXISTS public.alert_events_status_triggered_at_idx;

DROP TABLE IF EXISTS public.alert_events;

DROP INDEX IF EXISTS public.alert_rules_status_severity_updated_at_idx;
DROP INDEX IF EXISTS public.alert_rules_scope_code_unique_idx;

DROP TABLE IF EXISTS public.alert_rules;

DROP INDEX IF EXISTS public.slo_definitions_status_updated_at_idx;
DROP INDEX IF EXISTS public.slo_definitions_scope_code_unique_idx;

DROP TABLE IF EXISTS public.slo_definitions;

DROP INDEX IF EXISTS public.export_jobs_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.export_jobs;

DROP INDEX IF EXISTS public.import_jobs_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.import_jobs;

DROP INDEX IF EXISTS public.search_index_jobs_tenant_status_queued_at_idx;

DROP TABLE IF EXISTS public.search_index_jobs;

DROP INDEX IF EXISTS public.backup_restore_drills_status_created_at_idx;

DROP TABLE IF EXISTS public.backup_restore_drills;

DROP INDEX IF EXISTS public.migration_jobs_status_created_at_idx;

DROP TABLE IF EXISTS public.migration_jobs;

DROP INDEX IF EXISTS public.feature_flags_scope_status_updated_at_idx;
DROP INDEX IF EXISTS public.feature_flags_environment_key_unique_idx;
DROP INDEX IF EXISTS public.feature_flags_tenant_key_unique_idx;
DROP INDEX IF EXISTS public.feature_flags_global_key_unique_idx;

DROP TABLE IF EXISTS public.feature_flags;
