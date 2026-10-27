SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_alert_reviews (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 alert_id bigint NOT NULL,
 reviewer_user_id bigint NOT NULL,
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 1 AND 2000),
 request_key text NOT NULL CHECK(length(request_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,alert_id),
 FOREIGN KEY(alert_id,tenant_id) REFERENCES public.caller_quality_alerts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(reviewer_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_quality_review_actor ON public.caller_quality_alert_reviews(tenant_id,reviewer_user_id,id DESC);
CREATE FUNCTION public.guard_quality_alert_review() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality owner reviews are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF NOT EXISTS (
  SELECT 1 FROM public.users u JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=NEW.tenant_id
  JOIN public.user_roles ur ON ur.user_id=u.id AND ur.tenant_id=m.tenant_id
  JOIN public.roles r ON r.id=ur.role_id AND r.tenant_id=ur.tenant_id
  WHERE u.id=NEW.reviewer_user_id AND u.status='active' AND u.deleted_at IS NULL
   AND m.status='active' AND m.deleted_at IS NULL AND ur.status='active' AND ur.revoked_at IS NULL
   AND r.status='active' AND r.code='owner'
 ) THEN RAISE EXCEPTION 'Quality alert review requires an active tenant owner' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_review_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_alert_reviews
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_alert_review();
