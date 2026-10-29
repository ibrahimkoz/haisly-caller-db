SET LOCAL lock_timeout='5s';
CREATE INDEX caller_capacity_legacy_call_idx ON public.calls(tenant_id,id)
 WHERE ended_at IS NULL OR status IN ('ringing','in_progress');
CREATE INDEX caller_capacity_legacy_session_idx ON public.call_sessions(tenant_id,call_id,id)
 WHERE ended_at IS NULL OR status IN ('initiated','active','handoff');
