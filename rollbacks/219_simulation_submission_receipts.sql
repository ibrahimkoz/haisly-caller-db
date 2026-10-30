SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_simulation_submission_receipts) THEN
  RAISE EXCEPTION 'Cannot discard simulation receipt evidence; retain table and roll back application only';
 END IF;
END $$;
DROP TABLE public.caller_simulation_submission_receipts;
DROP FUNCTION public.guard_simulation_submission_receipt();
