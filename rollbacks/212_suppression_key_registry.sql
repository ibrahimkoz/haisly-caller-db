SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_suppression_keys) THEN
 RAISE EXCEPTION 'Cannot rollback registered suppression key history'; END IF; END $$;
ALTER TABLE public.caller_phone_suppression_events DROP CONSTRAINT caller_suppression_key_fk;
DROP TABLE public.caller_suppression_keys;
DROP FUNCTION public.guard_suppression_key();
