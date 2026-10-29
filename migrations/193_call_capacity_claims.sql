SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_capacity_claims (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 dispatch_id bigint,
 inbound_binding_id bigint,
 provider_account_id bigint NOT NULL,
 campaign_id bigint,
 state text NOT NULL DEFAULT 'held' CHECK(state IN ('held','released')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 released_at timestamptz,
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,dispatch_id), UNIQUE(tenant_id,inbound_binding_id),
 CHECK((dispatch_id IS NOT NULL AND inbound_binding_id IS NULL AND campaign_id IS NOT NULL) OR
       (dispatch_id IS NULL AND inbound_binding_id IS NOT NULL AND campaign_id IS NULL)),
 CHECK((state='held' AND released_at IS NULL) OR (state='released' AND released_at IS NOT NULL AND released_at>=created_at)),
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(inbound_binding_id,tenant_id) REFERENCES public.caller_inbound_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_capacity_claim_held_idx ON public.caller_capacity_claims(tenant_id,provider_account_id,campaign_id) WHERE state='held';
CREATE TRIGGER caller_capacity_claim_write_lock BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.caller_capacity_claims
 FOR EACH STATEMENT EXECUTE FUNCTION public.lock_caller_capacity();
CREATE FUNCTION public.guard_caller_capacity_claim() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source record; platform_limit integer; tenant_limit integer; provider_limit integer; campaign_limit integer;
BEGIN
 IF current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Capacity claims require READ COMMITTED isolation' USING ERRCODE='23514'; END IF;
 IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'Capacity claim history is immutable' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.dispatch_id,NEW.inbound_binding_id,NEW.provider_account_id,NEW.campaign_id,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.dispatch_id,OLD.inbound_binding_id,OLD.provider_account_id,OLD.campaign_id,OLD.created_at)
   OR OLD.state<>'held' OR NEW.state<>'released' THEN
   RAISE EXCEPTION 'Capacity claim may only be released once' USING ERRCODE='23514'; END IF;
  IF NEW.dispatch_id IS NOT NULL THEN
   IF NOT EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE id=NEW.dispatch_id AND tenant_id=NEW.tenant_id AND state IN ('ended','rejected','canceled')) THEN
    RAISE EXCEPTION 'Unresolved dispatch retains capacity' USING ERRCODE='23514'; END IF;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.caller_inbound_completions WHERE inbound_binding_id=NEW.inbound_binding_id AND tenant_id=NEW.tenant_id) THEN
    RAISE EXCEPTION 'Unresolved inbound call retains capacity' USING ERRCODE='23514'; END IF;
  END IF;
  NEW.released_at:=clock_timestamp();
  RETURN NEW;
 END IF;
 IF NEW.state<>'held' OR NEW.released_at IS NOT NULL THEN RAISE EXCEPTION 'Capacity claims must start held' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 IF NEW.dispatch_id IS NOT NULL THEN
  SELECT d.provider_account_id,d.campaign_id,(s.document->'settings'->>'requested_concurrency')::integer AS concurrency
   INTO source FROM public.caller_dispatch_intents d
   JOIN public.caller_campaign_snapshots s ON s.id=d.snapshot_id AND s.campaign_id=d.campaign_id AND s.tenant_id=d.tenant_id
   WHERE d.id=NEW.dispatch_id AND d.tenant_id=NEW.tenant_id AND d.state='prepared';
  IF NOT FOUND OR (NEW.provider_account_id,NEW.campaign_id) IS DISTINCT FROM (source.provider_account_id,source.campaign_id) THEN
   RAISE EXCEPTION 'Capacity claim requires matching prepared dispatch' USING ERRCODE='23514'; END IF;
  campaign_limit:=source.concurrency;
  IF campaign_limit IS NULL OR campaign_limit<1 THEN RAISE EXCEPTION 'Campaign capacity configuration missing' USING ERRCODE='23514'; END IF;
 ELSE
  SELECT b.provider_account_id INTO source FROM public.caller_inbound_bindings b
   JOIN public.caller_inbound_greeting_pins pin ON pin.inbound_binding_id=b.id AND pin.tenant_id=b.tenant_id
   JOIN public.billing_reservations r ON r.id=pin.reservation_id AND r.tenant_id=pin.tenant_id AND r.state='held'
   JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id AND s.status='active' AND s.ended_at IS NULL
   JOIN public.calls c ON c.id=b.call_id AND c.tenant_id=b.tenant_id AND c.status='in_progress' AND c.ended_at IS NULL
   WHERE b.id=NEW.inbound_binding_id AND b.tenant_id=NEW.tenant_id
   AND NOT EXISTS(SELECT 1 FROM public.caller_inbound_completions done WHERE done.inbound_binding_id=b.id AND done.tenant_id=b.tenant_id);
  IF NOT FOUND OR NEW.provider_account_id<>source.provider_account_id THEN
   RAISE EXCEPTION 'Capacity claim requires funded active inbound binding' USING ERRCODE='23514'; END IF;
 END IF;
 SELECT hard_limit INTO platform_limit FROM public.caller_capacity_policies WHERE scope='platform';
 SELECT requested_limit INTO tenant_limit FROM public.caller_capacity_policies WHERE scope='tenant' AND tenant_id=NEW.tenant_id;
 SELECT hard_limit INTO provider_limit FROM public.caller_capacity_policies WHERE scope='provider' AND tenant_id=NEW.tenant_id AND provider_account_id=NEW.provider_account_id;
 IF platform_limit IS NULL OR tenant_limit IS NULL OR provider_limit IS NULL THEN RAISE EXCEPTION 'Capacity configuration missing' USING ERRCODE='23514'; END IF;
 IF (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held')>=platform_limit OR
    (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id)>=tenant_limit OR
    (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id AND provider_account_id=NEW.provider_account_id)>=provider_limit THEN
  RAISE EXCEPTION 'Shared call capacity exhausted' USING ERRCODE='23514'; END IF;
 IF NEW.campaign_id IS NOT NULL AND (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id)>=campaign_limit THEN
  RAISE EXCEPTION 'Campaign call capacity exhausted' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_capacity_claim_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_capacity_claims
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_capacity_claim();
CREATE TRIGGER caller_capacity_claim_no_truncate BEFORE TRUNCATE ON public.caller_capacity_claims
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_caller_capacity_claim();
COMMENT ON TABLE public.caller_capacity_claims IS 'Durable source-bound capacity reservations. No timeout expiry. This primitive counts registered claims only; final admission must incorporate unclaimed legacy/test occupancy and all other gates before authorizing provider submission.';

CREATE FUNCTION public.release_terminal_call_capacity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='caller_dispatch_intents' THEN
  UPDATE public.caller_capacity_claims SET state='released'
   WHERE tenant_id=NEW.tenant_id AND dispatch_id=NEW.id AND state='held';
 ELSE
  UPDATE public.caller_capacity_claims SET state='released'
   WHERE tenant_id=NEW.tenant_id AND inbound_binding_id=NEW.inbound_binding_id AND state='held';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_dispatch_terminal_capacity AFTER UPDATE OF state ON public.caller_dispatch_intents
 FOR EACH ROW WHEN (NEW.state IN ('ended','rejected','canceled') AND OLD.state IS DISTINCT FROM NEW.state)
 EXECUTE FUNCTION public.release_terminal_call_capacity();
CREATE TRIGGER caller_inbound_terminal_capacity AFTER INSERT ON public.caller_inbound_completions
 FOR EACH ROW EXECUTE FUNCTION public.release_terminal_call_capacity();
