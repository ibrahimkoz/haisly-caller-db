SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_release_simulation_results WHERE definition_hash IS NOT NULL) THEN
  RAISE EXCEPTION 'Cannot discard simulation definition evidence';
 END IF;
END $$;
DROP TRIGGER caller_simulation_definition_guard ON public.caller_release_simulation_results;
DROP FUNCTION public.guard_simulation_definition_binding();
ALTER TABLE public.caller_release_simulation_results DROP COLUMN definition_hash;
