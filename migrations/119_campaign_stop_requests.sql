SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_campaign_stop_requests (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 actor_user_id bigint NOT NULL,
 expected_campaign_version integer NOT NULL CHECK(expected_campaign_version>0),
 intent text NOT NULL CHECK(intent IN ('pause','cancel')),
 active_call_policy text NOT NULL CHECK(active_call_policy IN ('finish','graceful_close')),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 1000),
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 prepared_count integer NOT NULL CHECK(prepared_count>=0),
 submitting_count integer NOT NULL CHECK(submitting_count>=0),
 uncertain_count integer NOT NULL CHECK(uncertain_count>=0),
 accepted_count integer NOT NULL CHECK(accepted_count>=0),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,campaign_id),
 UNIQUE(tenant_id,actor_user_id,idempotency_key),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(actor_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
-- Stop records are permanent barriers until a separately guarded resume lifecycle
-- is implemented. Do not delete a request to resume or silently replace its policy.
CREATE FUNCTION public.guard_campaign_stop_request() RETURNS trigger LANGUAGE plpgsql AS $$
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
CREATE TRIGGER caller_campaign_stop_request_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_campaign_stop_requests FOR EACH ROW EXECUTE FUNCTION public.guard_campaign_stop_request();

CREATE FUNCTION public.guard_dispatch_campaign_stop() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.state<>'submitting' OR OLD.state<>'prepared' THEN RETURN NEW; END IF;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF EXISTS(SELECT 1 FROM public.caller_campaign_stop_requests WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id) THEN
  RAISE EXCEPTION 'Campaign stop blocks new dispatch preparation and submission' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_dispatch_campaign_stop_guard BEFORE INSERT OR UPDATE ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.guard_dispatch_campaign_stop();
