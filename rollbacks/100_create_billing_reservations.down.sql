SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_reservations LIMIT 1) THEN
  RAISE EXCEPTION 'Reservations exist; use a forward fix.';
 END IF;
END $$;
DROP TRIGGER settled_usage_event_guard ON public.usage_events;
DROP TRIGGER billing_usage_settlement_guard ON public.billing_ledger_entries;
DROP FUNCTION public.guard_settled_usage_event();
DROP FUNCTION public.guard_usage_settlement();
ALTER TABLE public.billing_ledger_entries DROP CONSTRAINT ledger_kind_scope;
ALTER TABLE public.billing_ledger_entries DROP COLUMN reservation_id;
ALTER TABLE public.billing_ledger_entries DROP COLUMN usage_event_id;
ALTER TABLE public.billing_ledger_entries ALTER COLUMN actor_platform_admin_user_id SET NOT NULL;
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT billing_ledger_entries_kind_check CHECK(kind IN ('collection','adjustment'));
ALTER TABLE public.billing_ledger_entries ADD CONSTRAINT billing_ledger_entries_check CHECK((kind='collection' AND amount_delta>0 AND payment_transaction_id IS NOT NULL AND correction_of_entry_id IS NULL) OR (kind='adjustment' AND payment_transaction_id IS NULL AND correction_of_entry_id IS NOT NULL));
DROP TABLE public.billing_reservations;
DROP FUNCTION public.check_final_billing_reservation();
DROP FUNCTION public.guard_billing_reservation();
DROP FUNCTION public.post_billing_reservation();
ALTER TABLE public.usage_events DROP CONSTRAINT usage_events_scope;
