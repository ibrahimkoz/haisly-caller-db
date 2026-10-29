SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(hashtextextended('caller-shared-capacity',0));
LOCK TABLE public.caller_capacity_claims IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_capacity_claims) THEN
  RAISE EXCEPTION 'Capacity claim history must be preserved before rollback'; END IF;
END $$;
DROP TRIGGER caller_dispatch_terminal_capacity ON public.caller_dispatch_intents;
DROP TRIGGER caller_inbound_terminal_capacity ON public.caller_inbound_completions;
DROP FUNCTION public.release_terminal_call_capacity();
DROP TABLE public.caller_capacity_claims;
DROP FUNCTION public.guard_caller_capacity_claim();
