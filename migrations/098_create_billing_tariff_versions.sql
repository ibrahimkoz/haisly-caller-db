SET LOCAL lock_timeout = '5s';
CREATE TABLE public.billing_tariff_versions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 pricing_plan_id bigint NOT NULL REFERENCES public.pricing_plans(id) ON DELETE RESTRICT,
 version integer NOT NULL CHECK(version>0),
 schema_version integer NOT NULL DEFAULT 1 CHECK(schema_version=1),
 currency_code text NOT NULL DEFAULT 'USD' CHECK(currency_code='USD'),
 definition jsonb NOT NULL CHECK(jsonb_typeof(definition)='object' AND octet_length(definition::text)<=131072),
 definition_hash text NOT NULL CHECK(definition_hash ~ '^[0-9a-f]{64}$'),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 published_by_user_id bigint NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
 effective_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(effective_at>=created_at),
 UNIQUE(pricing_plan_id,version),
 UNIQUE(pricing_plan_id,effective_at),
 CHECK(COALESCE(definition->>'currency_code'='USD' AND definition->>'schema_version'='1' AND definition->>'reserve_buffer_bps'='1000',false))
);
CREATE INDEX billing_tariff_effective_idx ON public.billing_tariff_versions(pricing_plan_id,effective_at DESC);
CREATE FUNCTION public.guard_billing_tariff_version() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous_version integer; previous_effective timestamptz; plan_currency text; plan_status text;
BEGIN
 IF TG_OP<>'INSERT' THEN
  RAISE EXCEPTION 'Published billing tariff versions are immutable.' USING ERRCODE='23514';
 END IF;
 SELECT currency_code,status INTO plan_currency,plan_status FROM public.pricing_plans WHERE id=NEW.pricing_plan_id FOR UPDATE;
 IF NOT FOUND OR plan_currency<>'USD' OR plan_status<>'active' THEN
  RAISE EXCEPTION 'Tariff requires an active USD pricing plan.' USING ERRCODE='23514';
 END IF;
 SELECT version,effective_at INTO previous_version,previous_effective FROM public.billing_tariff_versions
  WHERE pricing_plan_id=NEW.pricing_plan_id ORDER BY version DESC LIMIT 1;
 IF NEW.version<>COALESCE(previous_version,0)+1 OR (previous_effective IS NOT NULL AND NEW.effective_at<=previous_effective) THEN
  RAISE EXCEPTION 'Tariff versions and effective dates must advance monotonically.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_tariff_version_guard BEFORE INSERT OR UPDATE OR DELETE ON public.billing_tariff_versions
 FOR EACH ROW EXECUTE FUNCTION public.guard_billing_tariff_version();
