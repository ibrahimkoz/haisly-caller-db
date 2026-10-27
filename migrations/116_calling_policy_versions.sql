SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_calling_policy_versions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 scope text NOT NULL CHECK(scope IN ('country','tenant')),
 tenant_id bigint REFERENCES public.tenants(id) ON DELETE RESTRICT,
 country_code text CHECK(country_code ~ '^[A-Z]{2}$'),
 version integer NOT NULL CHECK(version>0),
 calling_enabled boolean NOT NULL,
 weekdays smallint[] NOT NULL CHECK(cardinality(weekdays) BETWEEN 1 AND 7 AND weekdays <@ ARRAY[1,2,3,4,5,6,7]::smallint[] AND array_position(weekdays,NULL) IS NULL),
 start_minute integer NOT NULL CHECK(start_minute>=540),
 end_minute integer NOT NULL CHECK(end_minute<=1200 AND end_minute>start_minute),
 excluded_dates date[] NOT NULL DEFAULT '{}' CHECK(cardinality(excluded_dates)<=3660 AND array_position(excluded_dates,NULL) IS NULL),
 max_attempts integer NOT NULL CHECK(max_attempts BETWEEN 1 AND 5),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 1000),
 published_by_platform_admin_user_id bigint NOT NULL REFERENCES public.platform_admin_users(id) ON DELETE RESTRICT,
 effective_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((scope='country' AND country_code IS NOT NULL AND tenant_id IS NULL) OR (scope='tenant' AND country_code IS NULL AND tenant_id IS NOT NULL))
);
CREATE UNIQUE INDEX caller_calling_policy_country_version ON public.caller_calling_policy_versions(country_code,version) WHERE scope='country';
CREATE UNIQUE INDEX caller_calling_policy_tenant_version ON public.caller_calling_policy_versions(tenant_id,version) WHERE scope='tenant';
CREATE INDEX caller_calling_policy_country_effective ON public.caller_calling_policy_versions(country_code,effective_at DESC,version DESC) WHERE scope='country';
CREATE INDEX caller_calling_policy_tenant_effective ON public.caller_calling_policy_versions(tenant_id,effective_at DESC,version DESC) WHERE scope='tenant';
CREATE FUNCTION public.guard_caller_calling_policy() RETURNS trigger LANGUAGE plpgsql AS $$
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
CREATE TRIGGER caller_calling_policy_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_calling_policy_versions FOR EACH ROW EXECUTE FUNCTION public.guard_caller_calling_policy();
