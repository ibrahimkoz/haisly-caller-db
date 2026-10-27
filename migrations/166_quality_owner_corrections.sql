SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_quality_assessment_revisions
 ADD COLUMN assessment_source text NOT NULL DEFAULT 'model_assessment' CHECK(assessment_source IN ('model_assessment','owner_correction')),
 ADD COLUMN corrected_from_id bigint,
 ADD COLUMN reviewer_user_id bigint,
 ADD COLUMN correction_reason text,
 ADD CONSTRAINT caller_quality_correction_parent FOREIGN KEY(corrected_from_id,tenant_id) REFERENCES public.caller_quality_assessment_revisions(id,tenant_id) ON DELETE RESTRICT,
 ADD CONSTRAINT caller_quality_correction_actor FOREIGN KEY(reviewer_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 ADD CONSTRAINT caller_quality_correction_fields CHECK(
  (assessment_source='model_assessment' AND corrected_from_id IS NULL AND reviewer_user_id IS NULL AND correction_reason IS NULL)
  OR (assessment_source='owner_correction' AND corrected_from_id IS NOT NULL AND reviewer_user_id IS NOT NULL AND correction_reason IS NOT NULL AND length(btrim(correction_reason)) BETWEEN 1 AND 2000));
CREATE INDEX caller_quality_correction_parent_idx ON public.caller_quality_assessment_revisions(tenant_id,corrected_from_id) WHERE corrected_from_id IS NOT NULL;
CREATE FUNCTION public.guard_quality_owner_correction() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE base public.caller_quality_assessment_revisions%ROWTYPE;
BEGIN
 IF NEW.assessment_source='model_assessment' THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO base FROM public.caller_quality_assessment_revisions
 WHERE tenant_id=NEW.tenant_id AND id=NEW.corrected_from_id AND runtime_binding_id=NEW.runtime_binding_id
  AND version=NEW.version-1 FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quality correction requires the immediately preceding bound revision' USING ERRCODE='23514'; END IF;
 IF NEW.assessment->'weights' IS DISTINCT FROM base.assessment->'weights'
  OR NEW.assessment->'critical_checks' IS DISTINCT FROM base.assessment->'critical_checks' THEN
  RAISE EXCEPTION 'Quality correction cannot change weights or mandatory checks' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.users u JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=NEW.tenant_id
  JOIN public.user_roles ur ON ur.user_id=u.id AND ur.tenant_id=m.tenant_id
  JOIN public.roles r ON r.id=ur.role_id AND r.tenant_id=ur.tenant_id
  WHERE u.id=NEW.reviewer_user_id AND u.status='active' AND u.deleted_at IS NULL
   AND m.status='active' AND m.deleted_at IS NULL AND ur.status='active' AND ur.revoked_at IS NULL
   AND r.status='active' AND r.code='owner'
 ) THEN RAISE EXCEPTION 'Quality correction requires an active tenant owner' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_correction_guard BEFORE INSERT ON public.caller_quality_assessment_revisions
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_owner_correction();
