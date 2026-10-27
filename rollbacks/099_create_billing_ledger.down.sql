SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_accounts LIMIT 1) OR EXISTS(SELECT 1 FROM public.payment_transactions WHERE payment_kind='prepaid' LIMIT 1) THEN
  RAISE EXCEPTION 'Prepaid accounts/payments exist; use a forward fix.';
 END IF;
END $$;
DROP TABLE public.billing_ledger_entries;
DROP TABLE public.billing_accounts;
DROP TRIGGER prepaid_payment_guard ON public.payment_transactions;
DROP FUNCTION public.guard_prepaid_payment();
DROP FUNCTION public.apply_billing_ledger_entry();
DROP FUNCTION public.post_billing_ledger_balance();
DROP FUNCTION public.guard_billing_account();
ALTER TABLE public.payment_transactions DROP CONSTRAINT payment_transactions_scope;
ALTER TABLE public.payment_transactions DROP CONSTRAINT payment_kind_scope;
ALTER TABLE public.payment_transactions DROP COLUMN payment_kind;
ALTER TABLE public.payment_transactions ALTER COLUMN invoice_id SET NOT NULL;
