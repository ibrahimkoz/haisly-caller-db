SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_campaign_targets_state_check;
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_campaign_targets_state_check CHECK(state IN ('held','canceled'));
ALTER TABLE public.caller_campaign_targets ADD COLUMN canceled_at timestamptz;
ALTER TABLE public.caller_campaign_targets ADD COLUMN canceled_by_stop_request_id bigint REFERENCES public.caller_campaign_stop_requests(id) ON DELETE RESTRICT;
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_target_cancellation_pair CHECK(
 (state='held' AND canceled_at IS NULL AND canceled_by_stop_request_id IS NULL) OR
 (state='canceled' AND canceled_at IS NOT NULL AND canceled_by_stop_request_id IS NOT NULL)
);
CREATE INDEX caller_campaign_target_pending_cancel ON public.caller_campaign_targets(tenant_id,campaign_id,id) WHERE state='held';
CREATE FUNCTION public.guard_target_cancellation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE stop_id bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT id INTO stop_id FROM public.caller_campaign_stop_requests WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id AND intent='cancel';
 IF TG_OP='INSERT' THEN
  IF stop_id IS NOT NULL OR NEW.state<>'held' OR NEW.canceled_at IS NOT NULL OR NEW.canceled_by_stop_request_id IS NOT NULL THEN
   RAISE EXCEPTION 'Canceled campaign cannot receive new targets' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF OLD.state='canceled' THEN
  IF ROW(NEW.state,NEW.canceled_at,NEW.canceled_by_stop_request_id,NEW.snapshot_id) IS DISTINCT FROM ROW(OLD.state,OLD.canceled_at,OLD.canceled_by_stop_request_id,OLD.snapshot_id) THEN
   RAISE EXCEPTION 'Canceled targets cannot reopen or change cancellation provenance' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF NEW.state='canceled' THEN
  IF stop_id IS NULL THEN RAISE EXCEPTION 'Target cancellation requires campaign cancel request' USING ERRCODE='23514'; END IF;
  NEW.canceled_at:=clock_timestamp();
  NEW.canceled_by_stop_request_id:=stop_id;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_target_cancellation_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_targets FOR EACH ROW EXECUTE FUNCTION public.guard_target_cancellation();
