DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_alert_reviews) THEN RAISE EXCEPTION 'Quality reviews exist; preserve history and roll forward'; END IF;
END $$;
DROP TABLE public.caller_quality_alert_reviews;
DROP FUNCTION public.guard_quality_alert_review();
