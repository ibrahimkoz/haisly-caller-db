SET LOCAL lock_timeout='5s';
CREATE INDEX caller_hubspot_oauth_state_history_scope_idx
 ON public.caller_hubspot_oauth_states(tenant_id,integration_id,id DESC);
