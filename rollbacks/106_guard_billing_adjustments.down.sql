SET LOCAL lock_timeout = '5s';
LOCK TABLE public.billing_ledger_entries IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_ledger_entries WHERE kind='adjustment' LIMIT 1) THEN
 RAISE EXCEPTION 'Adjustment history exists; preserve correction safeguards with a forward fix.';
 END IF;
END $$;
DROP TRIGGER billing_adjustment_guard ON public.billing_ledger_entries;
DROP FUNCTION public.guard_billing_adjustment();
DROP INDEX public.billing_ledger_correction_idx;
