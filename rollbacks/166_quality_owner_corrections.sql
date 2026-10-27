DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_assessment_revisions WHERE assessment_source='owner_correction') THEN
  RAISE EXCEPTION 'Owner corrections exist; preserve provenance and roll forward';
 END IF;
END $$;
DROP TRIGGER caller_quality_correction_guard ON public.caller_quality_assessment_revisions;
DROP FUNCTION public.guard_quality_owner_correction();
DROP INDEX public.caller_quality_correction_parent_idx;
ALTER TABLE public.caller_quality_assessment_revisions DROP CONSTRAINT caller_quality_correction_fields,
 DROP CONSTRAINT caller_quality_correction_parent, DROP CONSTRAINT caller_quality_correction_actor,
 DROP COLUMN assessment_source, DROP COLUMN corrected_from_id, DROP COLUMN reviewer_user_id, DROP COLUMN correction_reason;
