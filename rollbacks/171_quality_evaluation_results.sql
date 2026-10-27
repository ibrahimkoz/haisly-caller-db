SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_evaluation_results) THEN RAISE EXCEPTION 'Cannot drop recorded quality evaluation result provenance'; END IF;
END $$;
DROP TRIGGER caller_quality_job_completion_guard ON public.background_jobs;
DROP FUNCTION public.guard_quality_job_completion();
DROP TABLE public.caller_quality_evaluation_results;
DROP FUNCTION public.guard_quality_evaluation_result();

ALTER TABLE public.job_attempts DROP CONSTRAINT job_attempts_id_tenant_id_unique;
