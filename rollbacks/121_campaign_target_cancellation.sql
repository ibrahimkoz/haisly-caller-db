SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_targets WHERE state='canceled') THEN RAISE EXCEPTION 'Target cancellation history requires forward remediation'; END IF;
END $$;
DROP TRIGGER caller_target_cancellation_guard ON public.caller_campaign_targets;
DROP FUNCTION public.guard_target_cancellation();
DROP INDEX public.caller_campaign_target_pending_cancel;
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_target_cancellation_pair;
ALTER TABLE public.caller_campaign_targets DROP COLUMN canceled_at;
ALTER TABLE public.caller_campaign_targets DROP COLUMN canceled_by_stop_request_id;
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_campaign_targets_state_check;
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_campaign_targets_state_check CHECK(state='held');
