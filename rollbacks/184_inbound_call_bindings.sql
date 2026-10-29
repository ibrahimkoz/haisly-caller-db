SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_inbound_bindings) THEN RAISE EXCEPTION 'Cannot discard inbound call history'; END IF;
END $$;
DROP TABLE public.caller_inbound_bindings;
DROP FUNCTION public.guard_inbound_call_binding();
