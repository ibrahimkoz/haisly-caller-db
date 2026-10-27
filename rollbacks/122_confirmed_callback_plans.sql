SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_callback_plans) THEN RAISE EXCEPTION 'Callback history requires forward remediation'; END IF;
END $$;
DROP TRIGGER caller_callback_plan_guard ON public.caller_callback_plans;
DROP FUNCTION public.guard_confirmed_callback_plan();
DROP TABLE public.caller_callback_plans;
