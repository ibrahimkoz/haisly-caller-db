SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(hashtextextended('caller-shared-capacity',0));
LOCK TABLE public.caller_capacity_policies IN ACCESS EXCLUSIVE MODE;
-- Disable admissions before rollback. Refuse to discard any configured policy.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_capacity_policies WHERE version<>1 OR scope='provider'
   OR (scope='platform' AND hard_limit<>20)
   OR (scope='tenant' AND (hard_limit<>2 OR requested_limit<>2))) THEN
  RAISE EXCEPTION 'Configured capacity policies require an explicit preservation plan before rollback';
 END IF;
END $$;
DROP TRIGGER caller_tenant_capacity_provision ON public.tenants;
DROP FUNCTION public.provision_caller_tenant_capacity();
DROP TABLE public.caller_capacity_policies;
DROP FUNCTION public.guard_caller_capacity_policy();
DROP FUNCTION public.lock_caller_capacity();
