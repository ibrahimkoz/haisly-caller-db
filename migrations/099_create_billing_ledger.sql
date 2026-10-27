SET LOCAL lock_timeout = '5s';
ALTER TABLE public.payment_transactions ALTER COLUMN invoice_id DROP NOT NULL;
ALTER TABLE public.payment_transactions ADD COLUMN payment_kind text NOT NULL DEFAULT 'invoice';
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_kind_scope CHECK(
 (payment_kind='invoice' AND invoice_id IS NOT NULL) OR (payment_kind='prepaid' AND invoice_id IS NULL AND currency_code='USD' AND amount>0 AND status='succeeded')
);
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_scope UNIQUE(id,tenant_id);
CREATE TABLE public.billing_accounts (
 tenant_id bigint PRIMARY KEY REFERENCES public.tenants(id) ON DELETE RESTRICT,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 currency_code text NOT NULL DEFAULT 'USD' CHECK(currency_code='USD'),
 balance_amount numeric(20,6) NOT NULL DEFAULT 0,
 reserved_amount numeric(20,6) NOT NULL DEFAULT 0 CHECK(reserved_amount>=0),
 state text NOT NULL DEFAULT 'active' CHECK(state IN ('active','reconciliation')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(state='reconciliation' OR balance_amount>=reserved_amount)
);
CREATE TABLE public.billing_ledger_entries (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.billing_accounts(tenant_id) ON DELETE RESTRICT,
 kind text NOT NULL CHECK(kind IN ('collection','adjustment')),
 amount_delta numeric(20,6) NOT NULL CHECK(amount_delta<>0),
 balance_after numeric(20,6) NOT NULL DEFAULT 0,
 payment_transaction_id bigint,
 correction_of_entry_id bigint,
 source_reference text NOT NULL CHECK(length(btrim(source_reference)) BETWEEN 1 AND 200),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 1000),
 actor_platform_admin_user_id bigint NOT NULL REFERENCES public.platform_admin_users(id) ON DELETE RESTRICT,
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id), UNIQUE(kind,source_reference), UNIQUE(payment_transaction_id),
 UNIQUE(actor_platform_admin_user_id,idempotency_key),
 FOREIGN KEY(payment_transaction_id,tenant_id) REFERENCES public.payment_transactions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(correction_of_entry_id,tenant_id) REFERENCES public.billing_ledger_entries(id,tenant_id) ON DELETE RESTRICT,
 CHECK((kind='collection' AND amount_delta>0 AND payment_transaction_id IS NOT NULL AND correction_of_entry_id IS NULL)
    OR (kind='adjustment' AND payment_transaction_id IS NULL AND correction_of_entry_id IS NOT NULL))
);
CREATE INDEX billing_ledger_tenant_page_idx ON public.billing_ledger_entries(tenant_id,id DESC);
CREATE FUNCTION public.guard_billing_account() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Billing accounts cannot be deleted.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.balance_amount<>0 OR NEW.reserved_amount<>0 OR NEW.version<>1 OR NEW.state<>'active' THEN
   RAISE EXCEPTION 'Billing accounts must start empty.' USING ERRCODE='23514';
  END IF;
 ELSE
  IF (NEW.tenant_id,NEW.public_id,NEW.currency_code,NEW.created_at) IS DISTINCT FROM (OLD.tenant_id,OLD.public_id,OLD.currency_code,OLD.created_at)
   OR NEW.version<>OLD.version+1
   OR ((NEW.balance_amount,NEW.reserved_amount) IS DISTINCT FROM (OLD.balance_amount,OLD.reserved_amount) AND pg_trigger_depth()<2) THEN
   RAISE EXCEPTION 'Account amounts require an accounting movement.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_account_guard BEFORE INSERT OR UPDATE OR DELETE ON public.billing_accounts FOR EACH ROW EXECUTE FUNCTION public.guard_billing_account();
CREATE FUNCTION public.apply_billing_ledger_entry() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE account public.billing_accounts%ROWTYPE; payment public.payment_transactions%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Ledger history is immutable; record a correction.' USING ERRCODE='23514'; END IF;
 SELECT * INTO account FROM public.billing_accounts WHERE tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Billing account not found.' USING ERRCODE='23514'; END IF;
 IF NEW.kind='collection' THEN
  SELECT * INTO payment FROM public.payment_transactions WHERE id=NEW.payment_transaction_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR payment.payment_kind<>'prepaid' OR payment.status<>'succeeded' OR payment.currency_code<>'USD'
    OR payment.amount<>NEW.amount_delta OR payment.provider_transaction_ref IS DISTINCT FROM NEW.source_reference THEN
   RAISE EXCEPTION 'Collection requires a matching confirmed prepaid payment.' USING ERRCODE='23514';
  END IF;
 END IF;
 NEW.balance_after:=account.balance_amount+NEW.amount_delta;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_ledger_apply BEFORE INSERT OR UPDATE OR DELETE ON public.billing_ledger_entries FOR EACH ROW EXECUTE FUNCTION public.apply_billing_ledger_entry();
CREATE FUNCTION public.post_billing_ledger_balance() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 UPDATE public.billing_accounts SET balance_amount=NEW.balance_after,version=version+1,updated_at=now(),
  state=CASE WHEN NEW.balance_after<reserved_amount THEN 'reconciliation' ELSE state END
  WHERE tenant_id=NEW.tenant_id;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_ledger_post AFTER INSERT ON public.billing_ledger_entries FOR EACH ROW EXECUTE FUNCTION public.post_billing_ledger_balance();
CREATE FUNCTION public.guard_prepaid_payment() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.payment_kind='prepaid' OR (TG_OP='UPDATE' AND NEW.payment_kind='prepaid') THEN
  RAISE EXCEPTION 'Prepaid collection history is immutable; use a ledger correction.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER prepaid_payment_guard BEFORE UPDATE OR DELETE ON public.payment_transactions FOR EACH ROW EXECUTE FUNCTION public.guard_prepaid_payment();
