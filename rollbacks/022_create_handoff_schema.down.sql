DROP INDEX IF EXISTS public.handoff_events_tenant_event_type_occurred_idx;
DROP INDEX IF EXISTS public.handoff_events_request_occurred_at_idx;

DROP TABLE IF EXISTS public.handoff_events;

DROP INDEX IF EXISTS public.handoff_requests_queue_status_priority_idx;
DROP INDEX IF EXISTS public.handoff_requests_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.handoff_requests;

DROP INDEX IF EXISTS public.human_agent_presence_tenant_env_status_seen_idx;

DROP TABLE IF EXISTS public.human_agent_presence;

DROP INDEX IF EXISTS public.handoff_queues_tenant_env_status_priority_idx;

DROP TABLE IF EXISTS public.handoff_queues;
