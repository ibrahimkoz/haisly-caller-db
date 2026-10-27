SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_survey_action_deliveries) THEN RAISE EXCEPTION 'Refusing to discard survey delivery receipts'; END IF;
END $$;
DROP TABLE public.caller_survey_action_deliveries;
