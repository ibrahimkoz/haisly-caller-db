DROP INDEX IF EXISTS public.artifact_deletion_jobs_tenant_status_requested_at_idx;
DROP INDEX IF EXISTS public.artifact_deletion_jobs_artifact_status_requested_at_idx;

DROP TABLE IF EXISTS public.artifact_deletion_jobs;

DROP INDEX IF EXISTS public.artifact_redaction_jobs_tenant_status_requested_at_idx;
DROP INDEX IF EXISTS public.artifact_redaction_jobs_artifact_status_requested_at_idx;

DROP TABLE IF EXISTS public.artifact_redaction_jobs;

DROP INDEX IF EXISTS public.artifact_access_events_tenant_action_occurred_at_idx;
DROP INDEX IF EXISTS public.artifact_access_events_artifact_occurred_at_idx;

DROP TABLE IF EXISTS public.artifact_access_events;

DROP INDEX IF EXISTS public.artifacts_tenant_status_created_at_idx;
DROP INDEX IF EXISTS public.artifacts_tenant_owner_entity_created_at_idx;

DROP TABLE IF EXISTS public.artifacts;
