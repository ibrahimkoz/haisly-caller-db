SET LOCAL lock_timeout='5s';
CREATE INDEX caller_hubspot_consumed_state_scope_idx
 ON public.caller_hubspot_oauth_states(tenant_id,integration_id,id)
 WHERE consumed_at IS NOT NULL;
