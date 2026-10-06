DROP INDEX IF EXISTS public.call_recordings_call_status_created_at_idx;
DROP INDEX IF EXISTS public.call_recordings_tenant_provider_recording_unique_idx;

DROP TABLE IF EXISTS public.call_recordings;

DROP INDEX IF EXISTS public.call_transcripts_call_segment_idx;

DROP TABLE IF EXISTS public.call_transcripts;

DROP INDEX IF EXISTS public.call_events_tenant_event_type_occurred_at_idx;
DROP INDEX IF EXISTS public.call_events_call_occurred_at_idx;

DROP TABLE IF EXISTS public.call_events;

DROP INDEX IF EXISTS public.calls_tenant_phone_number_started_at_idx;
DROP INDEX IF EXISTS public.calls_tenant_ai_agent_started_at_idx;
DROP INDEX IF EXISTS public.calls_tenant_status_started_at_idx;

DROP TABLE IF EXISTS public.calls;
