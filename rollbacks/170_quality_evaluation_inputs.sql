SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_evaluation_inputs) THEN RAISE EXCEPTION 'Cannot drop prepared quality evaluation inputs'; END IF;
END $$;
DROP TABLE public.caller_quality_evaluation_inputs;
DROP FUNCTION public.guard_quality_evaluation_input();
