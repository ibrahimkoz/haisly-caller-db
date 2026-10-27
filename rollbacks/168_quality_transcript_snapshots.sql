SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_transcript_snapshots) THEN
  RAISE EXCEPTION 'Cannot drop captured quality transcript evidence';
 END IF;
END $$;
DROP TABLE public.caller_quality_transcript_snapshots;
DROP FUNCTION public.guard_quality_transcript_snapshot();
