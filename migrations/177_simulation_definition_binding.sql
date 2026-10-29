SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_release_simulation_results ADD COLUMN definition_hash text
 CHECK(definition_hash IS NULL OR definition_hash ~ '^[a-f0-9]{64}$');
COMMENT ON COLUMN public.caller_release_simulation_results.definition_hash IS 'Immutable server suite definition hash bound to release; NULL legacy results cannot certify current definitions.';
CREATE FUNCTION public.guard_simulation_definition_binding() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE expected text;
BEGIN
 SELECT metadata->>'definition_hash' INTO expected FROM public.background_jobs
 WHERE tenant_id=NEW.tenant_id AND id=NEW.background_job_id FOR UPDATE;
 IF NEW.definition_hash IS NULL OR expected IS DISTINCT FROM NEW.definition_hash THEN
  RAISE EXCEPTION 'Simulation definition does not match requested job' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_simulation_definition_guard BEFORE INSERT ON public.caller_release_simulation_results
 FOR EACH ROW EXECUTE FUNCTION public.guard_simulation_definition_binding();
