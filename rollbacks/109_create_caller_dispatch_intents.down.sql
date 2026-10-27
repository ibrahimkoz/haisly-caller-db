SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_dispatch_intents IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents) THEN RAISE EXCEPTION 'Dispatch history exists; use a forward fix.'; END IF;
END $$;
DROP TRIGGER caller_target_claim_guard ON public.caller_campaign_targets;
DROP FUNCTION public.guard_claimed_target_snapshot();
DROP TRIGGER caller_dispatch_reservation_guard ON public.billing_reservations;
DROP FUNCTION public.guard_open_dispatch_reservation();
DROP TABLE public.caller_dispatch_intents;
DROP FUNCTION public.guard_caller_dispatch_intent();
DROP FUNCTION public.count_caller_dispatch_acceptance();
