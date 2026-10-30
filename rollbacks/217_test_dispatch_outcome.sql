SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_intents WHERE end_reason IS NOT NULL) THEN
  RAISE EXCEPTION 'Cannot discard recorded test outcome evidence';
 END IF;
END $$;
DROP TRIGGER caller_test_dispatch_outcome_guard ON public.caller_test_dispatch_intents;
DROP FUNCTION public.guard_test_dispatch_outcome();
ALTER TABLE public.caller_test_dispatch_intents DROP COLUMN end_reason;
