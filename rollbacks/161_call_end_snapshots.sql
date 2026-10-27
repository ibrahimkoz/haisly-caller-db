DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_call_end_snapshots) THEN RAISE EXCEPTION 'Call end snapshots exist; retain provenance and roll forward'; END IF;
END $$;
DROP TABLE public.caller_call_end_snapshots;
DROP FUNCTION public.guard_call_end_snapshot();
