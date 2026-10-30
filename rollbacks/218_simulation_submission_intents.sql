SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_simulation_submission_intents) THEN
  RAISE EXCEPTION 'Cannot discard simulation submission evidence; retain table and roll back application only';
 END IF;
END $$;
DROP TRIGGER caller_simulation_submission_retry_guard ON public.background_jobs;
DROP FUNCTION public.guard_simulation_submission_retry();
DROP TABLE public.caller_simulation_submission_intents;
DROP FUNCTION public.guard_simulation_submission_intent();
