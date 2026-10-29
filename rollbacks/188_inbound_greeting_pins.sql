SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_inbound_greeting_pins) THEN RAISE EXCEPTION 'Cannot discard inbound greeting pins'; END IF;
END $$;
DROP TABLE public.caller_inbound_greeting_pins;
DROP FUNCTION public.guard_inbound_greeting_pin();
