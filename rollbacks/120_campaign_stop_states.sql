SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaigns WHERE state<>'draft') OR EXISTS(SELECT 1 FROM public.caller_campaign_state_events) THEN RAISE EXCEPTION 'Campaign lifecycle history requires forward remediation'; END IF;
END $$;
DROP TRIGGER caller_campaign_stop_request_apply ON public.caller_campaign_stop_requests;
DROP FUNCTION public.apply_campaign_stop_request();
DROP TRIGGER caller_campaign_state_event_record ON public.caller_campaigns;
DROP FUNCTION public.record_campaign_state_event();
DROP TRIGGER caller_campaign_state_event_guard ON public.caller_campaign_state_events;
DROP FUNCTION public.guard_campaign_state_event();
DROP TABLE public.caller_campaign_state_events;
DROP TRIGGER caller_campaign_stop_state_guard ON public.caller_campaigns;
DROP FUNCTION public.guard_campaign_stop_state();
ALTER TABLE public.caller_campaigns DROP CONSTRAINT caller_campaigns_state_check;
ALTER TABLE public.caller_campaigns ADD CONSTRAINT caller_campaigns_state_check CHECK(state='draft');
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
 UPDATE public.caller_campaigns SET version=version+1,updated_at=NEW.requested_at WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id;
 RETURN NEW;
END $$;
