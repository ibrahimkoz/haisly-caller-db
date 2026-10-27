SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_stop_requests WHERE supersedes_request_id IS NOT NULL) THEN RAISE EXCEPTION 'Stop escalation history requires forward remediation'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.guard_campaign_stop_request() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE campaign_version integer; actual record;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Campaign stop requests are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT version INTO campaign_version FROM public.caller_campaigns WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF campaign_version IS NULL OR campaign_version<>NEW.expected_campaign_version THEN RAISE EXCEPTION 'Campaign changed before stop confirmation' USING ERRCODE='23514'; END IF;
 SELECT count(*) FILTER(WHERE state='prepared') AS prepared,
 count(*) FILTER(WHERE state='submitting') AS submitting,
 count(*) FILTER(WHERE state='uncertain') AS uncertain,
 count(*) FILTER(WHERE state='accepted') AS accepted INTO actual
 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id;
 IF ROW(NEW.prepared_count::bigint,NEW.submitting_count::bigint,NEW.uncertain_count::bigint,NEW.accepted_count::bigint) IS DISTINCT FROM ROW(actual.prepared,actual.submitting,actual.uncertain,actual.accepted) THEN
  RAISE EXCEPTION 'Call impact changed before stop confirmation' USING ERRCODE='23514';
 END IF;
 NEW.requested_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION public.apply_campaign_stop_request() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 UPDATE public.caller_campaigns SET state='pausing',version=version+1,updated_at=NEW.requested_at WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id;
 RETURN NEW;
END $$;
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
CREATE OR REPLACE FUNCTION public.record_campaign_state_event() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.state IS DISTINCT FROM OLD.state THEN
  INSERT INTO public.caller_campaign_state_events(tenant_id,campaign_id,campaign_version,stop_request_id,from_state,to_state)
   SELECT NEW.tenant_id,NEW.id,NEW.version,id,OLD.state,NEW.state FROM public.caller_campaign_stop_requests WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.id;
 END IF;
 RETURN NEW;
END $$;
ALTER TABLE public.caller_campaigns DROP CONSTRAINT caller_campaign_active_stop_scope;
ALTER TABLE public.caller_campaigns DROP COLUMN current_stop_request_id;
ALTER TABLE public.caller_campaign_stop_requests DROP CONSTRAINT caller_stop_supersedes_scope;
ALTER TABLE public.caller_campaign_stop_requests DROP COLUMN supersedes_request_id;
DROP INDEX public.caller_stop_campaign_history;
ALTER TABLE public.caller_campaign_stop_requests DROP CONSTRAINT caller_stop_scope;
ALTER TABLE public.caller_campaign_stop_requests ADD CONSTRAINT caller_campaign_stop_requests_tenant_id_campaign_id_key UNIQUE(tenant_id,campaign_id);
