SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_provider_circuits, public.caller_provider_circuit_receipts IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_provider_circuits) THEN RAISE EXCEPTION 'Provider circuit state exists; use a forward fix.'; END IF;
END $$;
DROP TABLE public.caller_provider_circuit_receipts;
DROP TABLE public.caller_provider_circuits;
DROP FUNCTION public.guard_provider_circuit_receipt();
DROP FUNCTION public.guard_provider_circuit();
