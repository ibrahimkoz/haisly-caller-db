SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaigns WHERE state='canceled') OR EXISTS(SELECT 1 FROM public.caller_campaign_state_events WHERE to_state='canceled') THEN RAISE EXCEPTION 'Terminal cancellation history requires forward remediation'; END IF;
END $$;
ALTER TABLE public.caller_campaigns DROP CONSTRAINT caller_campaigns_state_check;
ALTER TABLE public.caller_campaigns ADD CONSTRAINT caller_campaigns_state_check CHECK(state IN ('draft','pausing','paused'));
CREATE OR REPLACE FUNCTION public.guard_campaign_stop_state() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE stop public.caller_campaign_stop_requests%ROWTYPE;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'draft' THEN RAISE EXCEPTION 'Campaign must start as draft' USING ERRCODE='23514'; END IF;
  RETURN NEW;
 END IF;
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
 RAISE EXCEPTION 'Unsupported campaign state transition' USING ERRCODE='23514';
END $$;
