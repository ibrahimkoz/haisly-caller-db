SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_transfer_destinations) OR EXISTS(SELECT 1 FROM public.caller_transfer_team_policies) THEN
  RAISE EXCEPTION 'Cannot discard transfer configuration';
 END IF;
END $$;
DROP TABLE public.caller_transfer_destinations;
DROP TABLE public.caller_transfer_team_policies;
DROP FUNCTION public.guard_caller_transfer_configuration();
