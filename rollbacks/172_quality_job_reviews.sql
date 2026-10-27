SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_job_reviews) THEN RAISE EXCEPTION 'Cannot drop recorded quality job owner reviews'; END IF;
END $$;
DROP TABLE public.caller_quality_job_reviews;
DROP FUNCTION public.guard_quality_job_review();
