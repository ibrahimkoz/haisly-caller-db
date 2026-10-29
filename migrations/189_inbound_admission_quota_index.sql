SET LOCAL lock_timeout='5s';
CREATE INDEX caller_inbound_greeting_quota_window_idx ON public.caller_inbound_greeting_pins(tenant_id,created_at) INCLUDE(inbound_binding_id);
