-- Never erase consent evidence or uncertain external execution references implicitly.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.caller_tool_confirmations) THEN
    RAISE EXCEPTION 'Confirmation rollback requires explicit evidence retention/removal approval';
  END IF;
END $$;
DROP TABLE public.caller_tool_confirmations;
DROP FUNCTION public.caller_guard_tool_confirmation();
