-- Additive, initially deny-all. No tenant is granted network destinations by migration.
SET LOCAL lock_timeout = '5s';
CREATE FUNCTION public.caller_valid_https_origins(origins text[]) RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT COALESCE(
    cardinality(origins) <= 100
    AND (cardinality(origins) = 0 OR (array_ndims(origins) = 1 AND array_lower(origins, 1) = 1))
    AND cardinality(origins) = (SELECT count(DISTINCT value) FROM unnest(origins) AS value)
    AND NOT EXISTS (
      SELECT 1 FROM unnest(origins) AS value
      WHERE value IS NULL OR length(value) > 261
        OR value !~ '^https://[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z][a-z0-9-]*$'
    ), false);
$$;
CREATE TABLE public.caller_knowledge_https_policies (
  tenant_id bigint PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  allowed_origins text[] NOT NULL DEFAULT '{}'::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT caller_knowledge_https_origins_check CHECK (public.caller_valid_https_origins(allowed_origins))
);
CREATE FUNCTION public.caller_guard_https_policy() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id, 0));
  IF TG_OP = 'UPDATE' THEN
    IF NEW.tenant_id <> OLD.tenant_id OR NEW.public_id <> OLD.public_id OR NEW.created_at <> OLD.created_at THEN
      RAISE EXCEPTION 'HTTPS policy identity is immutable' USING ERRCODE = '23514';
    END IF;
    IF OLD.version = 2147483647 THEN
      RAISE EXCEPTION 'HTTPS policy version exhausted' USING ERRCODE = '23514';
    END IF;
    NEW.version := OLD.version + 1;
  ELSE
    NEW.version := 1;
  END IF;
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;
CREATE TRIGGER caller_https_policy_guard BEFORE INSERT OR UPDATE ON public.caller_knowledge_https_policies
FOR EACH ROW EXECUTE FUNCTION public.caller_guard_https_policy();
