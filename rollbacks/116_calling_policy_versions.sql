SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_calling_policy_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_calling_policy_versions) THEN RAISE EXCEPTION 'Calling policy history exists; use a forward fix.'; END IF;
END $$;
DROP TABLE public.caller_calling_policy_versions;
DROP FUNCTION public.guard_caller_calling_policy();
