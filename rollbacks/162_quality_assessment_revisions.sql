DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_assessment_revisions) THEN
  RAISE EXCEPTION 'Quality revisions exist; retain evaluation provenance and roll forward';
 END IF;
END $$;
DROP TABLE public.caller_quality_assessment_revisions;
DROP FUNCTION public.guard_quality_assessment_revision();
