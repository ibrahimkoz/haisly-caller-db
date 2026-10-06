DROP INDEX IF EXISTS public.customers_tenant_source_idx;

ALTER TABLE public.customers
  DROP CONSTRAINT IF EXISTS customers_source_check,
  DROP COLUMN IF EXISTS source;
