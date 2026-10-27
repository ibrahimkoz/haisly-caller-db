DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_alerts) THEN RAISE EXCEPTION 'Quality alerts exist; preserve history and roll forward'; END IF;
END $$;
DROP TABLE public.caller_quality_alerts;
DROP FUNCTION public.guard_quality_alert();
