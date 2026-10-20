-- Stop legacy workers before enabling leases. Expired non-retry-safe work is
-- quarantined: a lost acknowledgement must never blindly repeat an external call.
ALTER TABLE public.background_jobs
  ADD COLUMN lease_expires_at timestamptz,
  ADD COLUMN active_attempt_no integer NOT NULL DEFAULT 0,
  ADD COLUMN retry_safe boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT background_jobs_active_attempt_check CHECK (active_attempt_no >= 0);

UPDATE public.background_jobs AS j
SET active_attempt_no = a.attempt_no
FROM (SELECT background_job_id, max(attempt_no) AS attempt_no FROM public.job_attempts GROUP BY background_job_id) AS a
WHERE j.id = a.background_job_id;

-- Legacy running work gets a bounded reconciliation grace period.
UPDATE public.background_jobs SET lease_expires_at = now() + interval '5 minutes'
WHERE status = 'running';

CREATE INDEX background_jobs_expired_lease_idx
ON public.background_jobs (tenant_id, lease_expires_at) WHERE status = 'running';
