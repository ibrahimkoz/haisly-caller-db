SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_marketing_lead_actions) THEN RAISE EXCEPTION 'Marketing action history prevents rollback'; END IF; END $$;
DROP TABLE public.caller_marketing_lead_actions;
DROP FUNCTION public.guard_marketing_lead_action();
