SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_calling_policy_cancellations, public.caller_calling_policy_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_calling_policy_cancellations) THEN RAISE EXCEPTION 'Policy cancellation history exists; use a forward fix.'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.guard_caller_calling_policy() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous_version integer; previous_effective timestamptz;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Calling policy versions are immutable.' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-calling-policy',0));
 SELECT version,effective_at INTO previous_version,previous_effective FROM public.caller_calling_policy_versions
 WHERE scope=NEW.scope AND tenant_id IS NOT DISTINCT FROM NEW.tenant_id AND country_code IS NOT DISTINCT FROM NEW.country_code ORDER BY version DESC LIMIT 1;
 IF NEW.version<>COALESCE(previous_version,0)+1 OR (previous_effective IS NOT NULL AND NEW.effective_at<=previous_effective) THEN
  RAISE EXCEPTION 'Calling policy revision and effective time must advance.' USING ERRCODE='23514';
 END IF;
 IF cardinality(NEW.weekdays)<>(SELECT count(DISTINCT v) FROM unnest(NEW.weekdays) v) THEN
  RAISE EXCEPTION 'Duplicate calling weekdays.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
DROP TABLE public.caller_calling_policy_cancellations;
DROP FUNCTION public.guard_calling_policy_cancellation();
