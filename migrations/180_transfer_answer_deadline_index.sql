SET LOCAL lock_timeout='5s';
CREATE INDEX caller_transfer_attempt_pending_deadline_idx
 ON public.caller_transfer_attempts(tenant_id,submitted_at,id) WHERE status='pending';
COMMENT ON INDEX public.caller_transfer_attempt_pending_deadline_idx IS 'Bounded tenant timeout scans; expiration moves to uncertain and does not release occupancy.';
