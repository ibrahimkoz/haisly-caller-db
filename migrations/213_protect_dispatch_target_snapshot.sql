SET LOCAL lock_timeout = '5s';
-- Keep prepared/uncertain requests bound to the version that reserved their cost.
-- Existing rows are not rewritten; stale prepared rows can still be canceled.
CREATE FUNCTION public.guard_target_dispatch_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.snapshot_id IS DISTINCT FROM OLD.snapshot_id AND EXISTS (
  SELECT 1 FROM public.caller_dispatch_intents d
  WHERE d.tenant_id=OLD.tenant_id AND d.target_id=OLD.id
    AND d.state IN ('prepared','submitting','uncertain','accepted')
 ) THEN
  RAISE EXCEPTION 'Targets with open dispatches cannot change campaign snapshot.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_target_dispatch_snapshot_guard BEFORE UPDATE OF snapshot_id
 ON public.caller_campaign_targets FOR EACH ROW EXECUTE FUNCTION public.guard_target_dispatch_snapshot();

CREATE FUNCTION public.guard_dispatch_submission_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target public.caller_campaign_targets%ROWTYPE;
BEGIN
 IF OLD.state='prepared' AND NEW.state='submitting' THEN
  SELECT * INTO target FROM public.caller_campaign_targets
   WHERE tenant_id=NEW.tenant_id AND id=NEW.target_id FOR SHARE;
  IF NOT FOUND OR target.state<>'held'
   OR (target.campaign_id,target.snapshot_id,target.customer_id,target.identity_revision)
      IS DISTINCT FROM (NEW.campaign_id,NEW.snapshot_id,NEW.customer_id,NEW.identity_revision) THEN
   RAISE EXCEPTION 'Dispatch target is canceled or its campaign snapshot changed.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_dispatch_submission_snapshot_guard BEFORE UPDATE OF state
 ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.guard_dispatch_submission_snapshot();
