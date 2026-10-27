SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_quality_policies) THEN RAISE EXCEPTION 'Cannot remove recorded quality policy provenance'; END IF;
END $$;
DROP TRIGGER caller_quality_weights_guard ON public.caller_quality_assessment_revisions;
DROP FUNCTION public.guard_model_quality_weights();
DROP TRIGGER caller_snapshot_quality_guard ON public.caller_campaign_snapshots;
DROP FUNCTION public.guard_snapshot_quality_weights();
ALTER TABLE public.caller_campaign_snapshots DROP COLUMN quality_policy_id, DROP COLUMN quality_weights;
DROP TABLE public.caller_quality_policies;
DROP FUNCTION public.guard_caller_quality_policy();
DROP FUNCTION public.valid_caller_quality_weights(jsonb);
