SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_budget_limits LIMIT 1) THEN RAISE EXCEPTION 'Budget limits exist; use a forward fix.'; END IF;
END $$;
DROP TABLE public.billing_budget_limits;
DROP FUNCTION public.guard_billing_budget_limit();
DROP INDEX public.billing_reservation_month_idx;
DROP INDEX public.billing_reservation_campaign_idx;
