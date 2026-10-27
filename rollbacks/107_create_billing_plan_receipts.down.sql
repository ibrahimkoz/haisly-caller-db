SET LOCAL lock_timeout = '5s';
LOCK TABLE public.billing_plan_creation_receipts IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_plan_creation_receipts LIMIT 1) THEN
 RAISE EXCEPTION 'Plan creation history exists; use a forward fix.';
 END IF;
END $$;
DROP TABLE public.billing_plan_creation_receipts;
DROP FUNCTION public.guard_billing_plan_receipt();
