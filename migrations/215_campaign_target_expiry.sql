SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_targets ADD COLUMN expired_at timestamptz;
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_campaign_targets_state_check;
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_campaign_targets_state_check CHECK(state IN ('held','canceled','expired'));
ALTER TABLE public.caller_campaign_targets DROP CONSTRAINT caller_target_cancellation_pair;
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_target_cancellation_pair CHECK(
 (state IN ('held','expired') AND canceled_at IS NULL AND canceled_by_stop_request_id IS NULL) OR
 (state='canceled' AND canceled_at IS NOT NULL AND canceled_by_stop_request_id IS NOT NULL));
ALTER TABLE public.caller_campaign_targets ADD CONSTRAINT caller_target_expiry_pair CHECK(
 (state='expired' AND expired_at IS NOT NULL AND isfinite(expired_at)) OR
 (state<>'expired' AND expired_at IS NULL));
CREATE FUNCTION public.guard_target_expiry() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE deadline timestamptz;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='INSERT' THEN
  IF NEW.state='expired' OR NEW.expired_at IS NOT NULL THEN RAISE EXCEPTION 'Targets cannot start expired' USING ERRCODE='23514'; END IF;
  RETURN NEW;
 END IF;
 IF OLD.state='expired' THEN
  IF NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Expired targets are immutable' USING ERRCODE='23514'; END IF;
  RETURN NEW;
 END IF;
 IF NEW.state='expired' THEN
  IF OLD.state<>'held' OR NEW.snapshot_id<>OLD.snapshot_id OR NEW.attempt_count<>OLD.attempt_count THEN
   RAISE EXCEPTION 'Only unchanged held targets may expire' USING ERRCODE='23514';
  END IF;
  SELECT (document->'settings'->>'ends_at')::timestamptz INTO deadline FROM public.caller_campaign_snapshots WHERE id=OLD.snapshot_id AND tenant_id=OLD.tenant_id AND campaign_id=OLD.campaign_id;
  IF deadline IS NULL OR deadline>clock_timestamp() THEN RAISE EXCEPTION 'Campaign deadline has not elapsed' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=OLD.tenant_id AND target_id=OLD.id AND state IN ('prepared','submitting','uncertain','accepted'))
   OR EXISTS(SELECT 1 FROM public.caller_callback_plans WHERE tenant_id=OLD.tenant_id AND target_id=OLD.id AND state='pending') THEN
   RAISE EXCEPTION 'Unresolved dispatch or callback prevents target expiry' USING ERRCODE='23514';
  END IF;
  NEW.expired_at:=clock_timestamp();
 ELSIF NEW.expired_at IS DISTINCT FROM OLD.expired_at THEN
  RAISE EXCEPTION 'Expiry timestamp is server controlled' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_target_expiry_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_targets FOR EACH ROW EXECUTE FUNCTION public.guard_target_expiry();
CREATE FUNCTION public.guard_expired_target_callback() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 PERFORM id FROM public.caller_campaign_targets WHERE id=NEW.target_id AND tenant_id=NEW.tenant_id AND state='held' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Callback requires a held target' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_expired_target_callback_guard BEFORE INSERT ON public.caller_callback_plans FOR EACH ROW EXECUTE FUNCTION public.guard_expired_target_callback();
CREATE OR REPLACE FUNCTION public.guard_campaign_stop_state() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE stop public.caller_campaign_stop_requests%ROWTYPE;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'draft' OR NEW.current_stop_request_id IS NOT NULL THEN RAISE EXCEPTION 'Campaign must start as draft' USING ERRCODE='23514'; END IF;
  RETURN NEW;
 END IF;
 IF OLD.state='canceled' AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Canceled campaigns are immutable; clone to start again' USING ERRCODE='23514'; END IF;
 IF NEW.state=OLD.state AND NEW.current_stop_request_id IS NOT DISTINCT FROM OLD.current_stop_request_id THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO stop FROM public.caller_campaign_stop_requests WHERE id=NEW.current_stop_request_id AND campaign_id=NEW.id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND OR NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'Campaign state requires a stop request and next version' USING ERRCODE='23514'; END IF;
 IF NEW.current_stop_request_id IS DISTINCT FROM OLD.current_stop_request_id THEN
  IF NEW.state='pausing' AND stop.expected_campaign_version=OLD.version AND stop.supersedes_request_id IS NOT DISTINCT FROM OLD.current_stop_request_id
   AND (OLD.state='draft' OR (OLD.state IN ('pausing','paused') AND stop.intent='cancel')) THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Invalid active stop replacement' USING ERRCODE='23514';
 END IF;
 IF OLD.state='pausing' AND NEW.state='paused' AND stop.intent='pause' THEN
  IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.id AND state IN ('prepared','submitting','uncertain','accepted')) THEN
   RAISE EXCEPTION 'Unresolved calls prevent paused state' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF OLD.state='pausing' AND NEW.state='canceled' AND stop.intent='cancel' THEN
  IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.id AND state IN ('prepared','submitting','uncertain','accepted'))
   OR EXISTS(SELECT 1 FROM public.caller_campaign_targets WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.id AND state NOT IN ('canceled','expired'))
   OR EXISTS(SELECT 1 FROM public.caller_callback_plans b JOIN public.caller_campaign_targets t ON t.id=b.target_id AND t.tenant_id=b.tenant_id WHERE t.tenant_id=NEW.tenant_id AND t.campaign_id=NEW.id AND b.state NOT IN ('canceled','missed','started')) THEN
   RAISE EXCEPTION 'Unresolved calls or pending work prevent campaign cancellation' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 RAISE EXCEPTION 'Unsupported campaign state transition' USING ERRCODE='23514';
END $$;
