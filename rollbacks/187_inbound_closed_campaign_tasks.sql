SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_inbound_follow_up_actions) THEN RAISE EXCEPTION 'Cannot discard inbound follow-up provenance'; END IF;
END $$;
DROP TABLE public.caller_inbound_follow_up_actions;
DROP FUNCTION public.guard_inbound_follow_up_action();
ALTER TABLE public.caller_inbound_topic_confirmations DROP CONSTRAINT caller_inbound_topic_id_tenant_unique;
