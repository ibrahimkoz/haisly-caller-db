-- Run only after all workers stop and running jobs are reconciled.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.background_jobs WHERE status = 'running') THEN
    RAISE EXCEPTION 'Reconcile running jobs before removing lease protection';
  END IF;
END $$;
DROP INDEX public.background_jobs_expired_lease_idx;
ALTER TABLE public.background_jobs
  DROP CONSTRAINT background_jobs_active_attempt_check,
  DROP COLUMN retry_safe,
  DROP COLUMN active_attempt_no,
  DROP COLUMN lease_expires_at;
