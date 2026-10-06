DROP INDEX IF EXISTS public.call_tool_executions_tenant_status_requested_at_idx;
DROP INDEX IF EXISTS public.call_tool_executions_session_status_requested_at_idx;

DROP TABLE IF EXISTS public.call_tool_executions;

DROP INDEX IF EXISTS public.call_session_events_tenant_event_type_occurred_idx;
DROP INDEX IF EXISTS public.call_session_events_session_occurred_at_idx;
DROP INDEX IF EXISTS public.call_session_events_session_idempotency_unique_idx;

DROP TABLE IF EXISTS public.call_session_events;

DROP INDEX IF EXISTS public.call_sessions_tenant_call_started_at_idx;
DROP INDEX IF EXISTS public.call_sessions_tenant_status_started_at_idx;

DROP TABLE IF EXISTS public.call_sessions;
