SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_inbound_topic_confirmations) THEN RAISE EXCEPTION 'Cannot discard inbound topic evidence'; END IF;
END $$;
DROP TABLE public.caller_inbound_topic_confirmations;
DROP FUNCTION public.guard_inbound_topic_confirmation();
