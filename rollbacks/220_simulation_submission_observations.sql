SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_simulation_submission_observations) THEN
  RAISE EXCEPTION 'Cannot discard simulation observations; retain evidence and roll back application only';
 END IF;
END $$;
DROP TABLE public.caller_simulation_submission_observations;
DROP FUNCTION public.guard_simulation_submission_observation();
