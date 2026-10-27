SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_marketing_action_deliveries) THEN RAISE EXCEPTION 'Marketing action delivery history prevents rollback'; END IF; END $$;
DROP TABLE public.caller_marketing_action_deliveries;
