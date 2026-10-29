SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_inbound_completions) THEN RAISE EXCEPTION 'Cannot discard inbound completion evidence'; END IF;
END $$;
DROP TABLE public.caller_inbound_completions;
DROP FUNCTION public.guard_inbound_completion();
DROP INDEX public.caller_inbound_binding_phone_idx;
