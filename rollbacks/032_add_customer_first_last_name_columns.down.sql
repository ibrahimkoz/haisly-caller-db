DROP INDEX IF EXISTS public.customers_tenant_name_idx;

ALTER TABLE public.customers
  DROP CONSTRAINT IF EXISTS customers_last_name_not_blank_check,
  DROP CONSTRAINT IF EXISTS customers_first_name_not_blank_check,
  DROP COLUMN IF EXISTS last_name,
  DROP COLUMN IF EXISTS first_name;
