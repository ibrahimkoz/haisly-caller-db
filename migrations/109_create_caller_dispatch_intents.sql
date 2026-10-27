SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_dispatch_intents (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 target_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 customer_id bigint NOT NULL,
 identity_revision integer NOT NULL CHECK(identity_revision>0),
 canonical_phone text NOT NULL CHECK(canonical_phone ~ '^\+[1-9][0-9]{6,14}$'),
 outbound_phone_number_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 reservation_id bigint NOT NULL UNIQUE,
 request_key uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 state text NOT NULL DEFAULT 'prepared' CHECK(state IN ('prepared','submitting','uncertain','accepted','ended','rejected','canceled')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 provider_call_ref text CHECK(length(btrim(provider_call_ref)) BETWEEN 1 AND 200),
 accepted_at timestamptz,
 ended_at timestamptz,
 evidence_reference text CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 end_reason text CHECK(end_reason IN ('completed','no_answer','busy','declined','failed','canceled','voicemail')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,request_key), UNIQUE(provider_account_id,provider_call_ref),
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,campaign_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,campaign_id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(customer_id,tenant_id) REFERENCES public.customers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(outbound_phone_number_id,tenant_id) REFERENCES public.phone_numbers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(reservation_id,tenant_id) REFERENCES public.billing_reservations(id,tenant_id) ON DELETE RESTRICT,
 CHECK((state IN ('prepared','submitting','uncertain','rejected','canceled') AND accepted_at IS NULL AND ended_at IS NULL AND provider_call_ref IS NULL AND end_reason IS NULL)
  OR (state='accepted' AND accepted_at IS NOT NULL AND provider_call_ref IS NOT NULL AND ended_at IS NULL AND end_reason IS NULL)
  OR (state='ended' AND accepted_at IS NOT NULL AND provider_call_ref IS NOT NULL AND ended_at IS NOT NULL AND end_reason IS NOT NULL)),
 CHECK((accepted_at IS NULL OR (isfinite(accepted_at) AND accepted_at>=created_at)) AND (ended_at IS NULL OR (isfinite(ended_at) AND ended_at>=accepted_at))),
 CHECK(state='prepared' OR evidence_reference IS NOT NULL)
);
CREATE UNIQUE INDEX caller_dispatch_open_phone ON public.caller_dispatch_intents(tenant_id,canonical_phone) WHERE state IN ('prepared','submitting','uncertain','accepted');
CREATE INDEX caller_dispatch_phone_history ON public.caller_dispatch_intents(tenant_id,canonical_phone,accepted_at DESC) WHERE accepted_at IS NOT NULL;
CREATE INDEX caller_dispatch_target_history ON public.caller_dispatch_intents(tenant_id,target_id,id DESC);
CREATE FUNCTION public.guard_caller_dispatch_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target public.caller_campaign_targets%ROWTYPE; person public.customers%ROWTYPE; reserve public.billing_reservations%ROWTYPE;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Dispatch history cannot be deleted.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  SELECT * INTO target FROM public.caller_campaign_targets WHERE id=NEW.target_id AND tenant_id=NEW.tenant_id FOR UPDATE;
  IF NOT FOUND OR (target.campaign_id,target.snapshot_id,target.customer_id,target.identity_revision) IS DISTINCT FROM (NEW.campaign_id,NEW.snapshot_id,NEW.customer_id,NEW.identity_revision) THEN
   RAISE EXCEPTION 'Dispatch target binding is stale or foreign.' USING ERRCODE='23514';
  END IF;
  SELECT * INTO person FROM public.customers WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR (person.identity_revision,person.canonical_phone) IS DISTINCT FROM (NEW.identity_revision,NEW.canonical_phone) THEN
   RAISE EXCEPTION 'Dispatch contact identity is stale.' USING ERRCODE='23514';
  END IF;
  SELECT * INTO reserve FROM public.billing_reservations WHERE id=NEW.reservation_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR reserve.state<>'held' OR reserve.campaign_id IS DISTINCT FROM NEW.campaign_id OR reserve.purpose<>'production' THEN
   RAISE EXCEPTION 'Dispatch requires a matching held reservation.' USING ERRCODE='23514';
  END IF;
  IF NEW.state<>'prepared' OR NEW.version<>1 THEN RAISE EXCEPTION 'Dispatch must start prepared.' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.target_id,NEW.campaign_id,NEW.snapshot_id,NEW.customer_id,NEW.identity_revision,NEW.canonical_phone,NEW.outbound_phone_number_id,NEW.provider_account_id,NEW.reservation_id,NEW.request_key,NEW.request_hash,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.target_id,OLD.campaign_id,OLD.snapshot_id,OLD.customer_id,OLD.identity_revision,OLD.canonical_phone,OLD.outbound_phone_number_id,OLD.provider_account_id,OLD.reservation_id,OLD.request_key,OLD.request_hash,OLD.created_at) THEN
   RAISE EXCEPTION 'Dispatch bindings are immutable.' USING ERRCODE='23514';
  END IF;
  IF NOT ((OLD.state='prepared' AND NEW.state IN ('submitting','canceled'))
   OR (OLD.state IN ('submitting','uncertain') AND NEW.state IN ('uncertain','accepted','ended','rejected'))
   OR (OLD.state='accepted' AND NEW.state='ended')) OR NEW.state=OLD.state THEN
   RAISE EXCEPTION 'Invalid dispatch transition.' USING ERRCODE='23514';
  END IF;
  IF OLD.accepted_at IS NOT NULL AND (NEW.accepted_at,NEW.provider_call_ref) IS DISTINCT FROM (OLD.accepted_at,OLD.provider_call_ref) THEN
   RAISE EXCEPTION 'Provider acceptance is immutable.' USING ERRCODE='23514';
  END IF;
  NEW.version:=OLD.version+1;
 END IF;
 NEW.updated_at:=now();
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_dispatch_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.guard_caller_dispatch_intent();
CREATE FUNCTION public.count_caller_dispatch_acceptance() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.accepted_at IS NULL AND NEW.accepted_at IS NOT NULL THEN
  UPDATE public.caller_campaign_targets SET attempt_count=attempt_count+1,first_attempt_at=COALESCE(first_attempt_at,NEW.accepted_at)
   WHERE id=NEW.target_id AND tenant_id=NEW.tenant_id;
 END IF;
 RETURN NULL;
END;
$$;
CREATE TRIGGER caller_dispatch_count AFTER UPDATE ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.count_caller_dispatch_acceptance();
CREATE FUNCTION public.guard_claimed_target_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.snapshot_id<>OLD.snapshot_id AND EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE target_id=OLD.id AND tenant_id=OLD.tenant_id AND state IN ('prepared','submitting','uncertain','accepted')) THEN
  RAISE EXCEPTION 'Claimed targets cannot change campaign snapshot.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_target_claim_guard BEFORE UPDATE ON public.caller_campaign_targets FOR EACH ROW EXECUTE FUNCTION public.guard_claimed_target_snapshot();
CREATE FUNCTION public.guard_open_dispatch_reservation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents d JOIN public.billing_reservations r ON r.id=d.reservation_id AND r.tenant_id=d.tenant_id
  WHERE r.id=NEW.id AND d.state IN ('prepared','submitting','uncertain','accepted') AND r.state NOT IN ('held','uncertain')) THEN
  RAISE EXCEPTION 'Open dispatch must retain its cost reservation.' USING ERRCODE='23514';
 END IF;
 RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER caller_dispatch_reservation_guard AFTER UPDATE ON public.billing_reservations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.guard_open_dispatch_reservation();
