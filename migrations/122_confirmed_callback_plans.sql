SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_callback_plans (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 target_id bigint NOT NULL,
 source_dispatch_id bigint NOT NULL,
 request_key uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 confirmed_at timestamptz NOT NULL CHECK(isfinite(confirmed_at)),
 due_at timestamptz NOT NULL CHECK(isfinite(due_at)),
 window_ends_at timestamptz NOT NULL,
 recipient_timezone text NOT NULL,
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','canceled')),
 canceled_at timestamptz,
 cancellation_reason text CHECK(cancellation_reason IN ('campaign_canceled','rescheduled','contact_blocked','operator')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,request_key),
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(source_dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT,
 CHECK(due_at>confirmed_at AND window_ends_at=due_at+interval '30 minutes'),
 CHECK((state='pending' AND canceled_at IS NULL AND cancellation_reason IS NULL) OR (state='canceled' AND canceled_at IS NOT NULL AND cancellation_reason IS NOT NULL))
);
CREATE UNIQUE INDEX caller_callback_one_pending_target ON public.caller_callback_plans(tenant_id,target_id) WHERE state='pending';
CREATE INDEX caller_callback_due ON public.caller_callback_plans(tenant_id,due_at,id) WHERE state='pending';
CREATE FUNCTION public.guard_confirmed_callback_plan() RETURNS trigger LANGUAGE plpgsql AS $$
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
CREATE TRIGGER caller_callback_plan_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_callback_plans FOR EACH ROW EXECUTE FUNCTION public.guard_confirmed_callback_plan();
