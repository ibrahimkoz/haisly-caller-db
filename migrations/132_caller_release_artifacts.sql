-- Immutable candidate artifacts, not live publication authorization.
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_release_artifacts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  snapshot_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  outbound_phone_number_id bigint NOT NULL,
  release_hash text NOT NULL CHECK (release_hash ~ '^[a-f0-9]{64}$'),
  manifest jsonb NOT NULL CHECK (jsonb_typeof(manifest) = 'object' AND octet_length(manifest::text) <= 16384),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (id, tenant_id),
  UNIQUE (tenant_id, snapshot_id, release_hash),
  FOREIGN KEY (snapshot_id, tenant_id) REFERENCES public.caller_campaign_snapshots(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_environment_id, tenant_id) REFERENCES public.tenant_environments(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (outbound_phone_number_id, tenant_id) REFERENCES public.phone_numbers(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_release_artifact_environment_idx ON public.caller_release_artifacts(tenant_id, tenant_environment_id);
CREATE INDEX caller_release_artifact_phone_idx ON public.caller_release_artifacts(tenant_id, outbound_phone_number_id);
-- Test evidence can be reused for an identical hash after an operational-only snapshot change.
CREATE INDEX caller_release_artifact_hash_idx ON public.caller_release_artifacts(tenant_id, release_hash);
CREATE FUNCTION public.caller_guard_release_artifact() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE tenant_ref uuid; environment_ref uuid; phone_ref uuid; binding_hash text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'Release artifacts are immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  SELECT public_id INTO STRICT tenant_ref FROM public.tenants WHERE id=NEW.tenant_id;
  SELECT public_id INTO STRICT environment_ref FROM public.tenant_environments WHERE id=NEW.tenant_environment_id AND tenant_id=NEW.tenant_id;
  SELECT public_id INTO STRICT phone_ref FROM public.phone_numbers WHERE id=NEW.outbound_phone_number_id AND tenant_id=NEW.tenant_id;
  SELECT content_compilation_snapshot->'summary'->>'binding_hash' INTO STRICT binding_hash
    FROM public.caller_campaign_snapshots WHERE id=NEW.snapshot_id AND tenant_id=NEW.tenant_id
      AND content_compilation_snapshot->'summary'->>'status'='compiled';
  IF NOT COALESCE(
    NEW.manifest ?& ARRAY['schema','tenant_public_id','environment_public_id','outbound_phone_public_id','content_binding_hash','tools']
    AND (NEW.manifest - ARRAY['schema','tenant_public_id','environment_public_id','outbound_phone_public_id','content_binding_hash','tools']) = '{}'::jsonb
    AND NEW.manifest->>'schema'='caller-release-v1'
    AND NEW.manifest->>'tenant_public_id'=tenant_ref::text
    AND NEW.manifest->>'environment_public_id'=environment_ref::text
    AND NEW.manifest->>'outbound_phone_public_id'=phone_ref::text
    AND NEW.manifest->>'content_binding_hash'=binding_hash
    AND binding_hash ~ '^[a-f0-9]{64}$'
    AND jsonb_typeof(NEW.manifest->'tools')='array', false) THEN
    RAISE EXCEPTION 'Release manifest does not match its scope or compilation' USING ERRCODE = '23514';
  END IF;
  IF jsonb_array_length(NEW.manifest->'tools') > 6 THEN
    RAISE EXCEPTION 'Release tool limit exceeded' USING ERRCODE = '23514';
  END IF;
  -- Full pin validation/configuration matching belongs to the trusted preparation
  -- service. This record stores no test-success or live-publication flag.
  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$$;
CREATE TRIGGER caller_release_artifact_guard BEFORE INSERT OR UPDATE ON public.caller_release_artifacts
FOR EACH ROW EXECUTE FUNCTION public.caller_guard_release_artifact();
