SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_calling_policy_cancellations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 policy_version_id bigint NOT NULL UNIQUE REFERENCES public.caller_calling_policy_versions(id) ON DELETE RESTRICT,
 expected_latest_version integer NOT NULL CHECK(expected_latest_version>0),
 actor_platform_admin_user_id bigint NOT NULL REFERENCES public.platform_admin_users(id) ON DELETE RESTRICT,
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 1000),
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(actor_platform_admin_user_id,idempotency_key)
);
CREATE FUNCTION public.guard_calling_policy_cancellation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE policy public.caller_calling_policy_versions%ROWTYPE; latest integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Policy cancellations are immutable.' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-calling-policy',0));
 SELECT * INTO policy FROM public.caller_calling_policy_versions WHERE id=NEW.policy_version_id;
 IF NOT FOUND OR policy.effective_at<=clock_timestamp() THEN RAISE EXCEPTION 'Only future policy versions can be canceled.' USING ERRCODE='23514'; END IF;
 SELECT max(version) INTO latest FROM public.caller_calling_policy_versions WHERE scope=policy.scope AND tenant_id IS NOT DISTINCT FROM policy.tenant_id AND country_code IS NOT DISTINCT FROM policy.country_code;
 IF latest<>NEW.expected_latest_version THEN RAISE EXCEPTION 'Policy revision changed.' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_calling_policy_cancellation_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_calling_policy_cancellations FOR EACH ROW EXECUTE FUNCTION public.guard_calling_policy_cancellation();
CREATE OR REPLACE FUNCTION public.guard_caller_calling_policy() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous_version integer; previous_effective timestamptz;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Calling policy versions are immutable.' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-calling-policy',0));
 SELECT max(version) INTO previous_version FROM public.caller_calling_policy_versions WHERE scope=NEW.scope AND tenant_id IS NOT DISTINCT FROM NEW.tenant_id AND country_code IS NOT DISTINCT FROM NEW.country_code;
 SELECT max(p.effective_at) INTO previous_effective FROM public.caller_calling_policy_versions p
 WHERE p.scope=NEW.scope AND p.tenant_id IS NOT DISTINCT FROM NEW.tenant_id AND p.country_code IS NOT DISTINCT FROM NEW.country_code
 AND NOT EXISTS(SELECT 1 FROM public.caller_calling_policy_cancellations c WHERE c.policy_version_id=p.id);
 IF NEW.version<>COALESCE(previous_version,0)+1 OR (previous_effective IS NOT NULL AND NEW.effective_at<=previous_effective) THEN
  RAISE EXCEPTION 'Calling policy revision and uncanceled effective time must advance.' USING ERRCODE='23514';
 END IF;
 IF cardinality(NEW.weekdays)<>(SELECT count(DISTINCT v) FROM unnest(NEW.weekdays) v) THEN RAISE EXCEPTION 'Duplicate calling weekdays.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
