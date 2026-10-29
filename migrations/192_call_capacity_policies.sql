SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_capacity_policies (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 scope text NOT NULL CHECK(scope IN ('platform','tenant','provider')),
 tenant_id bigint REFERENCES public.tenants(id) ON DELETE RESTRICT,
 provider_account_id bigint,
 hard_limit integer NOT NULL CHECK(hard_limit>=0),
 requested_limit integer,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 CONSTRAINT caller_capacity_scope_contract CHECK (
  (scope='platform' AND tenant_id IS NULL AND provider_account_id IS NULL AND requested_limit IS NULL) OR
  (scope='tenant' AND tenant_id IS NOT NULL AND provider_account_id IS NULL AND requested_limit IS NOT NULL AND requested_limit BETWEEN 0 AND hard_limit) OR
  (scope='provider' AND tenant_id IS NOT NULL AND provider_account_id IS NOT NULL AND requested_limit IS NULL)
 )
);
CREATE UNIQUE INDEX caller_capacity_platform_unique ON public.caller_capacity_policies(scope) WHERE scope='platform';
CREATE UNIQUE INDEX caller_capacity_tenant_unique ON public.caller_capacity_policies(tenant_id) WHERE scope='tenant';
CREATE UNIQUE INDEX caller_capacity_provider_unique ON public.caller_capacity_policies(tenant_id,provider_account_id) WHERE scope='provider';
COMMENT ON TABLE public.caller_capacity_policies IS 'Shared concurrent call limits, independent of periodic admission quotas. Zero stops new work; lowering limits does not terminate existing calls. Provider limits require explicit configuration. No dispatch authority.';

-- Take this lock before any policy row locks. Admission will use the same lock
-- for its count-and-claim transaction; policy writers must not subsequently take
-- tenant/contact locks. Tenant-scoped admission takes its tenant lock first.
CREATE FUNCTION public.lock_caller_capacity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-shared-capacity',0));
 RETURN NULL;
END $$;
CREATE TRIGGER caller_capacity_write_lock BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.caller_capacity_policies
 FOR EACH STATEMENT EXECUTE FUNCTION public.lock_caller_capacity();
CREATE FUNCTION public.guard_caller_capacity_policy() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'Disable capacity with zero instead of deleting policy' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (NEW.id,NEW.public_id,NEW.scope,NEW.tenant_id,NEW.provider_account_id,NEW.created_at)
     IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.scope,OLD.tenant_id,OLD.provider_account_id,OLD.created_at) THEN
   RAISE EXCEPTION 'Capacity policy identity and scope are immutable' USING ERRCODE='23514'; END IF;
  NEW.version:=OLD.version+1;
 ELSE NEW.version:=1;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_capacity_policy_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_capacity_policies
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_capacity_policy();
CREATE TRIGGER caller_capacity_no_truncate BEFORE TRUNCATE ON public.caller_capacity_policies
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_caller_capacity_policy();
CREATE FUNCTION public.provision_caller_tenant_capacity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO public.caller_capacity_policies(scope,tenant_id,hard_limit,requested_limit)
 VALUES ('tenant',NEW.id,2,2);
 RETURN NEW;
END $$;
CREATE TRIGGER caller_tenant_capacity_provision AFTER INSERT ON public.tenants
 FOR EACH ROW EXECUTE FUNCTION public.provision_caller_tenant_capacity();
INSERT INTO public.caller_capacity_policies(scope,hard_limit) VALUES ('platform',20);
INSERT INTO public.caller_capacity_policies(scope,tenant_id,hard_limit,requested_limit)
 SELECT 'tenant',id,2,2 FROM public.tenants;
