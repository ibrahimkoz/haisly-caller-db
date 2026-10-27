SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_marketing_result_revisions) THEN RAISE EXCEPTION 'Marketing result history prevents rollback'; END IF; END $$;
DROP TABLE public.caller_marketing_result_revisions;
DROP FUNCTION public.guard_marketing_result_revision();
