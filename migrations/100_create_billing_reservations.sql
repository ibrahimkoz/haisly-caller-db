SET LOCAL lock_timeout = '5s';
ALTER TABLE public.usage_events ADD CONSTRAINT usage_events_scope UNIQUE(id,tenant_id);
CREATE TABLE public.billing_reservations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.billing_accounts(tenant_id) ON DELETE RESTRICT,
 campaign_id bigint,
 tariff_version_id bigint NOT NULL REFERENCES public.billing_tariff_versions(id) ON DELETE RESTRICT,
 reference_key uuid NOT NULL,
 purpose text NOT NULL CHECK(purpose IN ('production','test','inbound')),
 state text NOT NULL DEFAULT 'held' CHECK(state IN ('held','uncertain','settled','released')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 reserved_amount numeric(20,6) NOT NULL CHECK(reserved_amount>=0),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 sale_amount numeric(20,6),
 final_hash text,
 evidence_reference text,
 usage_event_id bigint,
 charge_breakdown jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id),UNIQUE(tenant_id,reference_key),UNIQUE(usage_event_id),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(usage_event_id,tenant_id) REFERENCES public.usage_events(id,tenant_id) ON DELETE RESTRICT,
 CHECK((purpose='inbound' AND campaign_id IS NULL) OR (purpose<>'inbound' AND campaign_id IS NOT NULL)),
 CHECK((state IN ('held','uncertain') AND sale_amount IS NULL AND final_hash IS NULL AND evidence_reference IS NULL AND usage_event_id IS NULL AND charge_breakdown IS NULL)
  OR (state='settled' AND sale_amount IS NOT NULL AND sale_amount>=0 AND usage_event_id IS NOT NULL AND charge_breakdown IS NOT NULL AND final_hash IS NOT NULL AND evidence_reference IS NOT NULL)
  OR (state='released' AND sale_amount IS NOT NULL AND sale_amount=0 AND usage_event_id IS NULL AND charge_breakdown IS NULL AND final_hash IS NOT NULL AND evidence_reference IS NOT NULL)),
 CHECK(final_hash IS NULL OR final_hash ~ '^[0-9a-f]{64}$'),
 CHECK(evidence_reference IS NULL OR length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 CHECK(charge_breakdown IS NULL OR (jsonb_typeof(charge_breakdown)='object' AND octet_length(charge_breakdown::text)<=131072))
);
CREATE INDEX billing_reservations_open_idx ON public.billing_reservations(tenant_id,state,id) WHERE state IN ('held','uncertain');
ALTER TABLE public.billing_ledger_entries DROP CONSTRAINT billing_ledger_entries_kind_check;
ALTER TABLE public.billing_ledger_entries DROP CONSTRAINT billing_ledger_entries_check;
ALTER TABLE public.billing_ledger_entries ALTER COLUMN actor_platform_admin_user_id DROP NOT NULL;
ALTER TABLE public.billing_ledger_entries ADD COLUMN reservation_id bigint;
ALTER TABLE public.billing_ledger_entries ADD COLUMN usage_event_id bigint;
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT ledger_reservation_scope FOREIGN KEY(reservation_id,tenant_id) REFERENCES public.billing_reservations(id,tenant_id) ON DELETE RESTRICT;
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT ledger_usage_scope FOREIGN KEY(usage_event_id,tenant_id) REFERENCES public.usage_events(id,tenant_id) ON DELETE RESTRICT;
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT ledger_one_settlement UNIQUE(reservation_id);
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT ledger_kind_scope CHECK(
 (kind='collection' AND amount_delta>0 AND payment_transaction_id IS NOT NULL AND correction_of_entry_id IS NULL AND actor_platform_admin_user_id IS NOT NULL AND reservation_id IS NULL AND usage_event_id IS NULL)
 OR (kind='adjustment' AND payment_transaction_id IS NULL AND correction_of_entry_id IS NOT NULL AND actor_platform_admin_user_id IS NOT NULL AND reservation_id IS NULL AND usage_event_id IS NULL)
 OR (kind='usage' AND amount_delta<0 AND payment_transaction_id IS NULL AND correction_of_entry_id IS NULL AND actor_platform_admin_user_id IS NULL AND reservation_id IS NOT NULL AND usage_event_id IS NOT NULL)
);
CREATE FUNCTION public.guard_billing_reservation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE account public.billing_accounts%ROWTYPE;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Reservation history cannot be deleted.' USING ERRCODE='23514'; END IF;
 SELECT * INTO account FROM public.billing_accounts WHERE tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Billing account missing.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'held' OR NEW.version<>1 OR account.state<>'active' OR account.balance_amount-account.reserved_amount<NEW.reserved_amount THEN
   RAISE EXCEPTION 'Insufficient available balance or account requires reconciliation.' USING ERRCODE='23514';
  END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.campaign_id,NEW.tariff_version_id,NEW.reference_key,NEW.purpose,NEW.reserved_amount,NEW.request_hash,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.campaign_id,OLD.tariff_version_id,OLD.reference_key,OLD.purpose,OLD.reserved_amount,OLD.request_hash,OLD.created_at)
   OR NEW.version<>OLD.version+1 OR OLD.state IN ('settled','released') OR NEW.state=OLD.state
   OR NEW.state='held' OR (OLD.state='uncertain' AND NEW.state='released') THEN
   RAISE EXCEPTION 'Invalid reservation transition or immutable binding change.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_reservation_guard BEFORE INSERT OR UPDATE OR DELETE ON public.billing_reservations FOR EACH ROW EXECUTE FUNCTION public.guard_billing_reservation();
CREATE FUNCTION public.post_billing_reservation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE delta numeric(20,6);
BEGIN
 delta:=CASE WHEN NEW.state IN ('held','uncertain') THEN NEW.reserved_amount ELSE 0 END;
 IF TG_OP='UPDATE' THEN delta:=delta-CASE WHEN OLD.state IN ('held','uncertain') THEN OLD.reserved_amount ELSE 0 END; END IF;
 IF delta<>0 THEN
  UPDATE public.billing_accounts SET reserved_amount=reserved_amount+delta,version=version+1,updated_at=now() WHERE tenant_id=NEW.tenant_id;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_reservation_post AFTER INSERT OR UPDATE ON public.billing_reservations FOR EACH ROW EXECUTE FUNCTION public.post_billing_reservation();
CREATE FUNCTION public.guard_usage_settlement() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE reservation public.billing_reservations%ROWTYPE;
BEGIN
 IF NEW.kind='usage' THEN
  SELECT * INTO reservation FROM public.billing_reservations WHERE id=NEW.reservation_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR reservation.state<>'settled' OR NEW.amount_delta<>-reservation.sale_amount OR NEW.usage_event_id<>reservation.usage_event_id THEN
   RAISE EXCEPTION 'Usage ledger must match its final reservation charge.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_usage_settlement_guard BEFORE INSERT ON public.billing_ledger_entries FOR EACH ROW EXECUTE FUNCTION public.guard_usage_settlement();
CREATE FUNCTION public.guard_settled_usage_event() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_reservations WHERE usage_event_id=OLD.id) THEN
  RAISE EXCEPTION 'Settled usage is immutable; record a correction.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER settled_usage_event_guard BEFORE UPDATE OR DELETE ON public.usage_events FOR EACH ROW EXECUTE FUNCTION public.guard_settled_usage_event();

CREATE FUNCTION public.check_final_billing_reservation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE current_row public.billing_reservations%ROWTYPE;
BEGIN
 SELECT * INTO current_row FROM public.billing_reservations WHERE id=NEW.id;
 IF current_row.state='settled' THEN
  IF NOT EXISTS(SELECT 1 FROM public.usage_events WHERE id=current_row.usage_event_id AND tenant_id=current_row.tenant_id AND quantity=current_row.sale_amount AND unit='usd' AND NOT is_billable)
   OR (current_row.sale_amount>0 AND NOT EXISTS(SELECT 1 FROM public.billing_ledger_entries WHERE reservation_id=current_row.id AND tenant_id=current_row.tenant_id AND kind='usage' AND amount_delta=-current_row.sale_amount)) THEN
   RAISE EXCEPTION 'Final settlement requires matching usage and ledger in one transaction.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER billing_reservation_final_check AFTER INSERT OR UPDATE ON public.billing_reservations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.check_final_billing_reservation();
