SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_test_numbers (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 canonical_phone text NOT NULL CHECK(canonical_phone ~ '^\+[1-9][0-9]{7,14}$'),
 country_code text NOT NULL CHECK(country_code ~ '^[A-Z]{2}$'),
 registered_by_user_id bigint NOT NULL,
 state text NOT NULL DEFAULT 'active' CHECK(state IN ('active','revoked')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 revoked_at timestamptz,
 revoked_by_user_id bigint,
 revocation_reason text CHECK(length(btrim(revocation_reason)) BETWEEN 3 AND 1000),
 UNIQUE(id,tenant_id),
 FOREIGN KEY(registered_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(revoked_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 CHECK((state='active' AND revoked_at IS NULL AND revoked_by_user_id IS NULL AND revocation_reason IS NULL)
   OR (state='revoked' AND revoked_at IS NOT NULL AND revoked_by_user_id IS NOT NULL AND revocation_reason IS NOT NULL))
);
CREATE UNIQUE INDEX caller_test_number_active_unique ON public.caller_test_numbers(tenant_id,canonical_phone) WHERE state='active';
CREATE INDEX caller_test_number_history_idx ON public.caller_test_numbers(tenant_id,id DESC);
COMMENT ON TABLE public.caller_test_numbers IS 'Tenant-owner enrollment only. Active does not mean verified or authorized to call; independent ownership proof and dispatch checks are required.';
CREATE FUNCTION public.guard_test_number_enrollment() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE actor bigint;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Test number enrollment history cannot be deleted' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='INSERT' THEN
  IF NEW.state<>'active' THEN RAISE EXCEPTION 'Test numbers must enroll active' USING ERRCODE='23514'; END IF;
  IF (SELECT count(*) FROM public.caller_test_numbers WHERE tenant_id=NEW.tenant_id AND state='active')>=10 THEN
   RAISE EXCEPTION 'Tenant test number limit reached' USING ERRCODE='23514'; END IF;
  actor:=NEW.registered_by_user_id; NEW.created_at:=clock_timestamp();
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.canonical_phone,NEW.country_code,NEW.registered_by_user_id,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.canonical_phone,OLD.country_code,OLD.registered_by_user_id,OLD.created_at)
   OR OLD.state<>'active' OR NEW.state<>'revoked' THEN
   RAISE EXCEPTION 'Enrollment identity is immutable; only active revocation allowed' USING ERRCODE='23514'; END IF;
  actor:=NEW.revoked_by_user_id; NEW.revoked_at:=clock_timestamp();
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id=ur.role_id
  JOIN public.users u ON u.id=ur.user_id JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=ur.tenant_id
  JOIN public.tenants t ON t.id=ur.tenant_id
  WHERE ur.tenant_id=NEW.tenant_id AND ur.user_id=actor AND ur.status='active' AND r.status='active' AND r.code='owner'
   AND u.status='active' AND u.deleted_at IS NULL AND m.status='active' AND m.deleted_at IS NULL AND t.status='active' AND t.deleted_at IS NULL) THEN
  RAISE EXCEPTION 'Test number enrollment requires an active tenant owner' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_test_number_enrollment_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_test_numbers
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_number_enrollment();
