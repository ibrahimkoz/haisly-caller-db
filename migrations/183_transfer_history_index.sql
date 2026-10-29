SET LOCAL lock_timeout='5s';
CREATE INDEX caller_transfer_attempt_policy_history_idx ON public.caller_transfer_attempts(tenant_id,team_policy_id,id DESC);
