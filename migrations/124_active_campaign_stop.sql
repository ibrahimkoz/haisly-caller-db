SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_stop_requests ADD CONSTRAINT caller_stop_scope UNIQUE(id,campaign_id,tenant_id);
ALTER TABLE public.caller_campaign_stop_requests ADD COLUMN supersedes_request_id bigint;
ALTER TABLE public.caller_campaign_stop_requests ADD CONSTRAINT caller_stop_supersedes_scope FOREIGN KEY(supersedes_request_id,campaign_id,tenant_id) REFERENCES public.caller_campaign_stop_requests(id,campaign_id,tenant_id) ON DELETE RESTRICT;
ALTER TABLE public.caller_campaigns ADD COLUMN current_stop_request_id bigint;
ALTER TABLE public.caller_campaigns ADD CONSTRAINT caller_campaign_active_stop_scope FOREIGN KEY(current_stop_request_id,id,tenant_id) REFERENCES public.caller_campaign_stop_requests(id,campaign_id,tenant_id) ON DELETE RESTRICT;
-- ALTER TABLE holds an exclusive lock; backfill changes only the new reference.
ALTER TABLE public.caller_campaigns DISABLE TRIGGER caller_campaign_stop_state_guard;
UPDATE public.caller_campaigns c SET current_stop_request_id=s.id FROM public.caller_campaign_stop_requests s WHERE c.id=s.campaign_id AND c.tenant_id=s.tenant_id;
ALTER TABLE public.caller_campaigns ENABLE TRIGGER caller_campaign_stop_state_guard;
ALTER TABLE public.caller_campaign_stop_requests DROP CONSTRAINT caller_campaign_stop_requests_tenant_id_campaign_id_key;
CREATE INDEX caller_stop_campaign_history ON public.caller_campaign_stop_requests(tenant_id,campaign_id,id);
CREATE OR REPLACE FUNCTION public.guard_campaign_stop_request() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE campaign_version integer; campaign_state text; active_stop bigint; previous_intent text; actual record;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Campaign stop requests are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT version,state,current_stop_request_id INTO campaign_version,campaign_state,active_stop FROM public.caller_campaigns WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF campaign_version IS NULL OR campaign_version<>NEW.expected_campaign_version THEN RAISE EXCEPTION 'Campaign changed before stop confirmation' USING ERRCODE='23514'; END IF;
 IF campaign_state='canceled' THEN RAISE EXCEPTION 'Canceled campaign cannot receive stop requests' USING ERRCODE='23514'; END IF;
 IF active_stop IS NOT NULL THEN
  SELECT intent INTO previous_intent FROM public.caller_campaign_stop_requests WHERE id=active_stop AND tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id;
  IF previous_intent IS DISTINCT FROM 'pause' OR NEW.intent<>'cancel' OR campaign_state NOT IN ('pausing','paused') THEN
   RAISE EXCEPTION 'Only pause to cancel escalation is supported' USING ERRCODE='23514';
  END IF;
 END IF;
 NEW.supersedes_request_id:=active_stop;
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
 UPDATE public.caller_campaigns SET state='pausing',current_stop_request_id=NEW.id,version=version+1,updated_at=NEW.requested_at WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id;
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
CREATE OR REPLACE FUNCTION public.record_campaign_state_event() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.state IS DISTINCT FROM OLD.state OR NEW.current_stop_request_id IS DISTINCT FROM OLD.current_stop_request_id THEN
  INSERT INTO public.caller_campaign_state_events(tenant_id,campaign_id,campaign_version,stop_request_id,from_state,to_state)
   SELECT NEW.tenant_id,NEW.id,NEW.version,id,OLD.state,NEW.state FROM public.caller_campaign_stop_requests WHERE id=NEW.current_stop_request_id AND tenant_id=NEW.tenant_id AND campaign_id=NEW.id;
 END IF;
 RETURN NEW;
END $$;
