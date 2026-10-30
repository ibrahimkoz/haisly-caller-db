SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_hubspot_connections) THEN
  RAISE EXCEPTION 'Retain HubSpot connection bindings and roll back application; disconnect and revoke credentials before schema removal';
 END IF;
END $$;
DROP TABLE public.caller_hubspot_connections;
DROP FUNCTION public.guard_hubspot_connection_credentials();
