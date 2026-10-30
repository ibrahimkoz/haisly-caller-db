SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_test_dispatch_intents ADD COLUMN end_reason text;
ALTER TABLE public.caller_test_dispatch_intents ADD CONSTRAINT caller_test_dispatch_end_reason CHECK(
 end_reason IS NULL OR (state='ended' AND end_reason IN ('completed','no_answer','busy','declined','failed','canceled','voicemail')));
CREATE FUNCTION public.guard_test_dispatch_outcome() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.state='ended' AND NEW.end_reason IS DISTINCT FROM OLD.end_reason THEN
  RAISE EXCEPTION 'Recorded test dispatch outcome cannot be rewritten' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_test_dispatch_outcome_guard BEFORE UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_outcome();
COMMENT ON COLUMN public.caller_test_dispatch_intents.end_reason IS 'Verified normalized provider outcome. NULL is unknown/legacy and must never qualify as a successful publication test.';
