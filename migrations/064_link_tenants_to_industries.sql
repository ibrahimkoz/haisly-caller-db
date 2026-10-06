ALTER TABLE public.tenants
  ADD COLUMN industry_id bigint,
  ADD CONSTRAINT tenants_industry_id_fk FOREIGN KEY (industry_id)
    REFERENCES public.industries (id)
    ON DELETE RESTRICT;

CREATE INDEX tenants_industry_status_created_at_idx
  ON public.tenants (industry_id, status, created_at DESC)
  WHERE industry_id IS NOT NULL;

COMMENT ON COLUMN public.tenants.industry_id IS
  'Selected industry catalog entry. Nullable only for tenants created before industry selection became mandatory.';
