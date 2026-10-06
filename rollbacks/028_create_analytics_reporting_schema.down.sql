DROP INDEX IF EXISTS public.report_deliveries_tenant_scheduled_status_idx;
DROP INDEX IF EXISTS public.report_deliveries_tenant_definition_status_idx;
DROP INDEX IF EXISTS public.report_deliveries_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.report_deliveries;

DROP INDEX IF EXISTS public.scheduled_reports_tenant_env_status_updated_at_idx;
DROP INDEX IF EXISTS public.scheduled_reports_tenant_status_next_run_idx;

DROP TABLE IF EXISTS public.scheduled_reports;

DROP INDEX IF EXISTS public.report_definitions_tenant_env_visibility_idx;
DROP INDEX IF EXISTS public.report_definitions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.report_definitions;

DROP INDEX IF EXISTS public.metric_snapshots_tenant_agent_metric_window_start_idx;
DROP INDEX IF EXISTS public.metric_snapshots_tenant_env_metric_window_start_idx;
DROP INDEX IF EXISTS public.metric_snapshots_tenant_metric_window_start_idx;

DROP TABLE IF EXISTS public.metric_snapshots;
