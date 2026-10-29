SET LOCAL lock_timeout='5s';
LOCK TABLE public.caller_capacity_assignment_receipts IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_capacity_assignment_receipts) THEN
  RAISE EXCEPTION 'Capacity assignment receipt history must be preserved'; END IF;
END $$;
DROP TABLE public.caller_capacity_assignment_receipts;
DROP FUNCTION public.guard_capacity_assignment_receipt();
