SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_contact_conflicts) THEN
  RAISE EXCEPTION 'Preserve CRM conflict evidence; roll back application instead';
 END IF;
END $$;
DROP TABLE public.caller_hubspot_contact_conflicts;
DROP FUNCTION public.guard_hubspot_contact_conflict();
