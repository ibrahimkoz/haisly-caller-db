SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.caller_phone_suppression_events) THEN
 RAISE EXCEPTION 'Existing suppression history requires verified key fingerprint backfill before migration212'; END IF; END $$;
CREATE TABLE public.caller_suppression_keys (
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 key_version text NOT NULL CHECK(key_version ~ '^[A-Za-z0-9_-]{1,64}$'),
 key_fingerprint text NOT NULL CHECK(key_fingerprint ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(tenant_id,key_version)
);
CREATE FUNCTION public.guard_suppression_key() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Registered suppression keys are immutable; rotate with a new version' USING ERRCODE='23514'; END $$;
CREATE TRIGGER caller_suppression_key_guard BEFORE UPDATE OR DELETE ON public.caller_suppression_keys
 FOR EACH ROW EXECUTE FUNCTION public.guard_suppression_key();
CREATE TRIGGER caller_suppression_key_no_truncate BEFORE TRUNCATE ON public.caller_suppression_keys
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_suppression_key();
ALTER TABLE public.caller_phone_suppression_events ADD CONSTRAINT caller_suppression_key_fk
 FOREIGN KEY(tenant_id,key_version) REFERENCES public.caller_suppression_keys(tenant_id,key_version) ON DELETE RESTRICT;
COMMENT ON TABLE public.caller_suppression_keys IS 'Immutable domain-separated HMAC key fingerprints, never keys. Detects changed secret under retained version; historical versions remain required for lookup.';
