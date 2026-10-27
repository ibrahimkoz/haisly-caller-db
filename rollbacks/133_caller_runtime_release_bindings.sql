DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.caller_runtime_release_bindings) THEN
    RAISE EXCEPTION 'Runtime binding rollback requires explicit retention/removal approval';
  END IF;
END $$;
DROP TABLE public.caller_runtime_release_bindings;
DROP FUNCTION public.caller_guard_runtime_release_binding();
