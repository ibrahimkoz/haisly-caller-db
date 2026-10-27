DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.caller_release_artifacts) THEN
    RAISE EXCEPTION 'Release artifact rollback requires an explicit retention/removal plan';
  END IF;
END $$;
DROP TABLE public.caller_release_artifacts;
DROP FUNCTION public.caller_guard_release_artifact();
