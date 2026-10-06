DROP INDEX IF EXISTS public.pii_redaction_jobs_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.pii_redaction_jobs;

DROP INDEX IF EXISTS public.data_deletion_requests_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.data_deletion_requests;

DROP INDEX IF EXISTS public.data_export_requests_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.data_export_requests;

DROP INDEX IF EXISTS public.consent_records_tenant_result_captured_at_idx;
DROP INDEX IF EXISTS public.consent_records_tenant_call_captured_at_idx;

DROP TABLE IF EXISTS public.consent_records;

DROP INDEX IF EXISTS public.consent_policies_tenant_env_status_effective_idx;

DROP TABLE IF EXISTS public.consent_policies;

DROP INDEX IF EXISTS public.retention_policies_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.retention_policies;
