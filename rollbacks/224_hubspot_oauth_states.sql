DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_oauth_states) THEN
  RAISE EXCEPTION 'Refusing to discard OAuth state records'; END IF;
END $$;
DROP TABLE public.caller_hubspot_oauth_states;
DROP FUNCTION public.guard_hubspot_oauth_state();
