DROP INDEX IF EXISTS public.job_attempts_tenant_status_started_at_idx;
DROP INDEX IF EXISTS public.job_attempts_job_status_started_at_idx;

DROP TABLE IF EXISTS public.job_attempts;

DROP INDEX IF EXISTS public.background_jobs_queue_status_priority_idx;
DROP INDEX IF EXISTS public.background_jobs_tenant_status_available_at_idx;
DROP INDEX IF EXISTS public.background_jobs_tenant_queue_dedupe_unique_idx;

DROP TABLE IF EXISTS public.background_jobs;

DROP INDEX IF EXISTS public.inbox_events_source_topic_received_at_idx;
DROP INDEX IF EXISTS public.inbox_events_tenant_status_received_at_idx;

DROP TABLE IF EXISTS public.inbox_events;

DROP INDEX IF EXISTS public.outbox_events_status_available_at_idx;
DROP INDEX IF EXISTS public.outbox_events_tenant_status_available_at_idx;

DROP TABLE IF EXISTS public.outbox_events;
