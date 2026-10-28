SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_release_simulation_results) THEN RAISE EXCEPTION 'Cannot remove release simulation evidence'; END IF;
END $$;
DROP TABLE public.caller_release_simulation_results;
DROP FUNCTION public.guard_release_simulation_result();
DROP INDEX public.caller_release_simulation_job_run_unique;
