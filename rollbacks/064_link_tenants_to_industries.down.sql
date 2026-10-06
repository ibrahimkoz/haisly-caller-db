DROP INDEX IF EXISTS public.tenants_industry_status_created_at_idx;

ALTER TABLE public.tenants
  DROP CONSTRAINT IF EXISTS tenants_industry_id_fk,
  DROP COLUMN IF EXISTS industry_id;
