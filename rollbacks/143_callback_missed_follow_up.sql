SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_callback_plans WHERE state='missed' OR follow_up_task_id IS NOT NULL OR missed_at IS NOT NULL) THEN RAISE EXCEPTION 'Refusing to discard missed callback history'; END IF; END $$;
ALTER TABLE public.caller_callback_plans DROP CONSTRAINT caller_callback_terminal_shape;
ALTER TABLE public.caller_callback_plans DROP CONSTRAINT caller_callback_plans_state_check;
ALTER TABLE public.caller_callback_plans ADD CONSTRAINT caller_callback_plans_state_check CHECK(state IN ('pending','canceled'));
ALTER TABLE public.caller_callback_plans ADD CONSTRAINT caller_callback_plans_check1 CHECK((state='pending' AND canceled_at IS NULL AND cancellation_reason IS NULL) OR (state='canceled' AND canceled_at IS NOT NULL AND cancellation_reason IS NOT NULL));
DROP INDEX public.caller_callback_follow_up_unique;
ALTER TABLE public.caller_callback_plans DROP CONSTRAINT caller_callback_follow_up_scope;
ALTER TABLE public.caller_callback_plans DROP COLUMN missed_at;
ALTER TABLE public.caller_callback_plans DROP COLUMN follow_up_task_id;
CREATE OR REPLACE FUNCTION public.guard_confirmed_callback_plan() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target public.caller_campaign_targets%ROWTYPE; source public.caller_dispatch_intents%ROWTYPE;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Callback history cannot be deleted' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='INSERT' THEN
  SELECT * INTO target FROM public.caller_campaign_targets WHERE id=NEW.target_id AND tenant_id=NEW.tenant_id FOR UPDATE;
  SELECT * INTO source FROM public.caller_dispatch_intents WHERE id=NEW.source_dispatch_id AND tenant_id=NEW.tenant_id;
  IF target.id IS NULL OR target.state='canceled' OR source.id IS NULL OR source.target_id<>target.id OR source.snapshot_id<>target.snapshot_id OR source.accepted_at IS NULL THEN
   RAISE EXCEPTION 'Callback requires a matching accepted source call and active target' USING ERRCODE='23514';
  END IF;
  IF NEW.confirmed_at<source.accepted_at OR NEW.confirmed_at>clock_timestamp() OR (source.ended_at IS NOT NULL AND NEW.confirmed_at>source.ended_at) THEN
   RAISE EXCEPTION 'Callback confirmation must belong to the source conversation' USING ERRCODE='23514';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.id=target.customer_id AND c.tenant_id=target.tenant_id AND c.identity_revision=target.identity_revision AND c.do_not_call_at IS NULL AND c.archived_at IS NULL) THEN
   RAISE EXCEPTION 'Callback contact identity or preference changed' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM public.caller_campaign_stop_requests WHERE campaign_id=target.campaign_id AND tenant_id=target.tenant_id AND intent='cancel') THEN
   RAISE EXCEPTION 'Canceled campaign cannot receive callback plans' USING ERRCODE='23514';
  END IF;
  IF NEW.state<>'pending' OR NEW.canceled_at IS NOT NULL OR NEW.cancellation_reason IS NOT NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=NEW.recipient_timezone) THEN
   RAISE EXCEPTION 'Callback requires a pending state and valid timezone' USING ERRCODE='23514';
  END IF;
  IF NEW.due_at+interval '30 minutes'<=clock_timestamp() THEN RAISE EXCEPTION 'Callback start window has already expired' USING ERRCODE='23514'; END IF;
  NEW.created_at:=clock_timestamp();
  NEW.window_ends_at:=NEW.due_at+interval '30 minutes';
  RETURN NEW;
 END IF;
 IF ROW(NEW.id,NEW.public_id,NEW.tenant_id,NEW.target_id,NEW.source_dispatch_id,NEW.request_key,NEW.request_hash,NEW.confirmed_at,NEW.due_at,NEW.window_ends_at,NEW.recipient_timezone,NEW.evidence_reference,NEW.created_at)
 IS DISTINCT FROM ROW(OLD.id,OLD.public_id,OLD.tenant_id,OLD.target_id,OLD.source_dispatch_id,OLD.request_key,OLD.request_hash,OLD.confirmed_at,OLD.due_at,OLD.window_ends_at,OLD.recipient_timezone,OLD.evidence_reference,OLD.created_at) THEN
  RAISE EXCEPTION 'Callback confirmation and timing are immutable' USING ERRCODE='23514';
 END IF;
 IF OLD.state<>'pending' OR NEW.state<>'canceled' THEN RAISE EXCEPTION 'Unsupported callback transition' USING ERRCODE='23514'; END IF;
 IF NEW.cancellation_reason='campaign_canceled' AND NOT EXISTS(SELECT 1 FROM public.caller_campaign_targets t JOIN public.caller_campaign_stop_requests s ON s.campaign_id=t.campaign_id AND s.tenant_id=t.tenant_id WHERE t.id=NEW.target_id AND t.tenant_id=NEW.tenant_id AND s.intent='cancel') THEN
  RAISE EXCEPTION 'Callback campaign cancellation requires a cancel request' USING ERRCODE='23514';
 END IF;
 NEW.canceled_at:=clock_timestamp();
 RETURN NEW;
END $$;
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
   OR EXISTS(SELECT 1 FROM public.caller_campaign_targets WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.id AND state<>'canceled')
   OR EXISTS(SELECT 1 FROM public.caller_callback_plans b JOIN public.caller_campaign_targets t ON t.id=b.target_id AND t.tenant_id=b.tenant_id WHERE t.tenant_id=NEW.tenant_id AND t.campaign_id=NEW.id AND b.state<>'canceled') THEN
   RAISE EXCEPTION 'Unresolved calls or pending work prevent campaign cancellation' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 RAISE EXCEPTION 'Unsupported campaign state transition' USING ERRCODE='23514';
END $$;
