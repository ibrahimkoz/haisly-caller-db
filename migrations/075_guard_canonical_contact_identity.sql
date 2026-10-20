-- Both legacy writers and caller writers take the same tenant-scoped lock.
-- Existing ambiguous rows are preserved; no new claim may shadow a canonical identity.
CREATE FUNCTION public.guard_canonical_contact_identity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE candidate text; owner_id bigint; canonical text;
BEGIN
  IF TG_TABLE_NAME = 'customers' THEN
    candidate := NEW.primary_phone;
    owner_id := NEW.id;
    IF TG_OP = 'UPDATE' AND NEW.primary_phone IS NOT DISTINCT FROM OLD.primary_phone
       AND NEW.canonical_phone IS NOT DISTINCT FROM OLD.canonical_phone THEN RETURN NEW; END IF;
  ELSE
    IF NEW.contact_type <> 'phone' THEN RETURN NEW; END IF;
    candidate := regexp_replace(NEW.normalized_value, '[[:space:]().-]', '', 'g');
    owner_id := NEW.customer_id;
  END IF;
  -- Advisory locks are transaction-scoped and also protect empty-key races.
  PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id::text, 0));
  IF EXISTS (SELECT 1 FROM public.customers c WHERE c.tenant_id = NEW.tenant_id
             AND c.id <> owner_id AND c.canonical_phone = candidate) THEN
    RAISE EXCEPTION 'Phone conflicts with a canonical contact' USING ERRCODE = '23505';
  END IF;
  IF TG_TABLE_NAME = 'customer_contacts' THEN
    SELECT canonical_phone INTO canonical FROM public.customers WHERE tenant_id = NEW.tenant_id AND id = owner_id;
    IF canonical IS NOT NULL AND candidate IS DISTINCT FROM canonical THEN
      RAISE EXCEPTION 'Canonical contact requires an explicit identity correction' USING ERRCODE = '23514';
    END IF;
  ELSIF NEW.canonical_phone IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.customers c WHERE c.tenant_id = NEW.tenant_id AND c.id <> owner_id AND c.primary_phone = NEW.canonical_phone)
       OR EXISTS (SELECT 1 FROM public.customer_contacts cc WHERE cc.tenant_id = NEW.tenant_id AND cc.customer_id <> owner_id AND cc.contact_type = 'phone'
                  AND regexp_replace(cc.normalized_value, '[[:space:]().-]', '', 'g') = NEW.canonical_phone) THEN
      RAISE EXCEPTION 'Legacy phone claim requires manual resolution' USING ERRCODE = '23505';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER customers_guard_canonical_identity BEFORE INSERT OR UPDATE ON public.customers
 FOR EACH ROW EXECUTE FUNCTION public.guard_canonical_contact_identity();
CREATE TRIGGER customer_contacts_guard_canonical_identity BEFORE INSERT OR UPDATE ON public.customer_contacts
 FOR EACH ROW EXECUTE FUNCTION public.guard_canonical_contact_identity();
CREATE INDEX customer_contacts_canonical_claim_idx ON public.customer_contacts
 (tenant_id, (regexp_replace(normalized_value, '[[:space:]().-]', '', 'g')))
 WHERE contact_type = 'phone';
CREATE INDEX customers_primary_phone_claim_idx ON public.customers (tenant_id, primary_phone)
 WHERE primary_phone IS NOT NULL;
