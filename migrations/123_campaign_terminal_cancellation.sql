SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaigns DROP CONSTRAINT caller_campaigns_state_check;
ALTER TABLE public.caller_campaigns ADD CONSTRAINT caller_campaigns_state_check CHECK(state IN ('draft','pausing','paused','canceled'));
CREATE OR REPLACE FUNCTION public.guard_campaign_stop_state() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE stop public.caller_campaign_stop_requests%ROWTYPE;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'draft' THEN RAISE EXCEPTION 'Campaign must start as draft' USING ERRCODE='23514'; END IF;
  RETURN NEW;
 END IF;
 IF OLD.state='canceled' AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Canceled campaigns are immutable; clone to start again' USING ERRCODE='23514'; END IF;
 IF NEW.state=OLD.state THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO stop FROM public.caller_campaign_stop_requests WHERE campaign_id=NEW.id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND OR NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'Campaign state requires a stop request and next version' USING ERRCODE='23514'; END IF;
 IF OLD.state='draft' AND NEW.state='pausing' THEN RETURN NEW; END IF;
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
