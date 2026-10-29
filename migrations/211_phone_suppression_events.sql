SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_phone_suppression_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 key_version text NOT NULL CHECK(key_version ~ '^[A-Za-z0-9_-]{1,64}$'),
 phone_digest text NOT NULL CHECK(phone_digest ~ '^[0-9a-f]{64}$'),
 source_event_id bigint NOT NULL CHECK(source_event_id>0),
 source_event_public_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('blocked','released')),
 occurred_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,key_version,source_event_id),
 UNIQUE(tenant_id,key_version,source_event_public_id)
);
CREATE INDEX caller_phone_suppression_lookup_idx ON public.caller_phone_suppression_events(tenant_id,key_version,phone_digest,source_event_id DESC);
CREATE FUNCTION public.guard_phone_suppression_event() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source record;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Phone suppression events are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT * INTO source FROM public.contact_change_events e
  WHERE e.id=NEW.source_event_id AND e.public_id=NEW.source_event_public_id AND e.tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND OR source.event_type NOT IN ('dnc_requested','dnc_revoked') OR source.occurred_at>clock_timestamp()
  OR NEW.occurred_at IS DISTINCT FROM source.occurred_at
  OR NEW.action IS DISTINCT FROM (CASE WHEN source.event_type='dnc_requested' THEN 'blocked' ELSE 'released' END) THEN
  RAISE EXCEPTION 'Phone suppression requires matching DNC preference event' USING ERRCODE='23514'; END IF;
 IF NEW.action='released' THEN
  IF source.source<>'user' OR source.actor_user_id IS NULL OR nullif(btrim(source.evidence_reference),'') IS NULL
   OR (source.after_value->>'requested_at') IS NULL OR (source.before_value->>'do_not_call_at') IS NULL
   OR (source.after_value->>'requested_at')::timestamptz<=(source.before_value->>'do_not_call_at')::timestamptz
   OR (source.after_value->>'requested_at')::timestamptz>source.occurred_at THEN
   RAISE EXCEPTION 'Suppression release requires subsequent explicit request evidence' USING ERRCODE='23514'; END IF;
  PERFORM 1 FROM public.user_roles ur JOIN public.roles r ON r.id=ur.role_id AND r.tenant_id=ur.tenant_id
   JOIN public.users u ON u.id=ur.user_id AND u.tenant_id=ur.tenant_id
   JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=ur.tenant_id
   WHERE ur.tenant_id=NEW.tenant_id AND ur.user_id=source.actor_user_id AND ur.status='active' AND ur.revoked_at IS NULL
   AND r.code='owner' AND r.status='active' AND u.status='active' AND u.deleted_at IS NULL
   AND m.status='active' AND m.deleted_at IS NULL FOR SHARE OF ur,r,u,m;
  IF NOT FOUND THEN RAISE EXCEPTION 'Suppression release requires active tenant owner' USING ERRCODE='23514'; END IF;
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_phone_suppression_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_phone_suppression_events
 FOR EACH ROW EXECUTE FUNCTION public.guard_phone_suppression_event();
CREATE TRIGGER caller_phone_suppression_no_truncate BEFORE TRUNCATE ON public.caller_phone_suppression_events
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_phone_suppression_event();
COMMENT ON TABLE public.caller_phone_suppression_events IS 'Minimal tenant-keyed HMAC preference ledger; remains personal data. No raw phone, contact FK, reason or evidence body. Source IDs preserved without FK for future source erasure. Latest source_event_id determines preference; insertion order is not event order.';
