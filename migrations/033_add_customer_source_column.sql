ALTER TABLE public.customers
  ADD COLUMN source text NOT NULL DEFAULT 'manual',
  ADD CONSTRAINT customers_source_check CHECK (source IN ('manual', 'ai'));

CREATE INDEX customers_tenant_source_idx
  ON public.customers (tenant_id, source);
