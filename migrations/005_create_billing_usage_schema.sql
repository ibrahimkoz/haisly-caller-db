CREATE TABLE public.pricing_plans (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  currency_code char(3) NOT NULL DEFAULT 'USD',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pricing_plans_public_id_unique UNIQUE (public_id),
  CONSTRAINT pricing_plans_code_unique UNIQUE (code),
  CONSTRAINT pricing_plans_code_format_check CHECK (code ~ '^[a-z][a-z0-9_]{1,79}$'),
  CONSTRAINT pricing_plans_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT pricing_plans_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT pricing_plans_status_check CHECK (status IN (
    'active',
    'deprecated',
    'hidden'
  )),
  CONSTRAINT pricing_plans_currency_code_format_check CHECK (
    currency_code ~ '^[A-Z]{3}$'
  ),
  CONSTRAINT pricing_plans_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX pricing_plans_status_code_idx
  ON public.pricing_plans (status, code);

CREATE TABLE public.usage_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  source_event_id text,
  metric_code text NOT NULL,
  period_key text NOT NULL,
  occurred_at timestamptz NOT NULL,
  quantity numeric(20, 6) NOT NULL,
  unit text NOT NULL,
  is_billable boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT usage_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT usage_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT usage_events_metric_code_format_check CHECK (
    metric_code ~ '^[a-z][a-z0-9_.:]{1,119}$'
  ),
  CONSTRAINT usage_events_period_key_not_blank_check CHECK (btrim(period_key) <> ''),
  CONSTRAINT usage_events_source_event_id_not_blank_check CHECK (
    source_event_id IS NULL OR btrim(source_event_id) <> ''
  ),
  CONSTRAINT usage_events_unit_not_blank_check CHECK (btrim(unit) <> ''),
  CONSTRAINT usage_events_quantity_non_negative_check CHECK (quantity >= 0),
  CONSTRAINT usage_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX usage_events_tenant_source_event_unique_idx
  ON public.usage_events (tenant_id, source_event_id)
  WHERE source_event_id IS NOT NULL;

CREATE INDEX usage_events_tenant_period_occurred_at_idx
  ON public.usage_events (tenant_id, period_key, occurred_at DESC);

CREATE INDEX usage_events_tenant_metric_occurred_at_idx
  ON public.usage_events (tenant_id, metric_code, occurred_at DESC);

CREATE TABLE public.invoices (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  pricing_plan_id bigint,
  invoice_no text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  period_start date NOT NULL,
  period_end date NOT NULL,
  currency_code char(3) NOT NULL,
  subtotal_amount numeric(20, 6) NOT NULL DEFAULT 0,
  tax_amount numeric(20, 6) NOT NULL DEFAULT 0,
  discount_amount numeric(20, 6) NOT NULL DEFAULT 0,
  total_amount numeric(20, 6) NOT NULL DEFAULT 0,
  due_at timestamptz,
  finalized_at timestamptz,
  paid_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT invoices_public_id_unique UNIQUE (public_id),
  CONSTRAINT invoices_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT invoices_tenant_invoice_no_unique UNIQUE (tenant_id, invoice_no),
  CONSTRAINT invoices_tenant_period_unique UNIQUE (tenant_id, period_start, period_end),
  CONSTRAINT invoices_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT invoices_pricing_plan_id_fk FOREIGN KEY (pricing_plan_id)
    REFERENCES public.pricing_plans (id)
    ON DELETE RESTRICT,
  CONSTRAINT invoices_invoice_no_not_blank_check CHECK (btrim(invoice_no) <> ''),
  CONSTRAINT invoices_status_check CHECK (status IN (
    'draft',
    'finalized',
    'paid',
    'partially_paid',
    'void',
    'overdue'
  )),
  CONSTRAINT invoices_period_range_check CHECK (period_end >= period_start),
  CONSTRAINT invoices_currency_code_format_check CHECK (
    currency_code ~ '^[A-Z]{3}$'
  ),
  CONSTRAINT invoices_subtotal_non_negative_check CHECK (subtotal_amount >= 0),
  CONSTRAINT invoices_tax_non_negative_check CHECK (tax_amount >= 0),
  CONSTRAINT invoices_discount_non_negative_check CHECK (discount_amount >= 0),
  CONSTRAINT invoices_total_non_negative_check CHECK (total_amount >= 0),
  CONSTRAINT invoices_total_consistency_check CHECK (
    total_amount = subtotal_amount + tax_amount - discount_amount
  ),
  CONSTRAINT invoices_finalized_timestamp_check CHECK (
    status NOT IN ('finalized', 'paid', 'partially_paid', 'void', 'overdue')
    OR finalized_at IS NOT NULL
  ),
  CONSTRAINT invoices_paid_timestamp_check CHECK (
    status NOT IN ('paid', 'partially_paid') OR paid_at IS NOT NULL
  ),
  CONSTRAINT invoices_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX invoices_tenant_period_idx
  ON public.invoices (tenant_id, period_start, period_end);

CREATE INDEX invoices_tenant_status_created_at_idx
  ON public.invoices (tenant_id, status, created_at DESC);

CREATE TABLE public.invoice_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  invoice_id bigint NOT NULL,
  line_no integer NOT NULL,
  item_type text NOT NULL,
  description text NOT NULL,
  quantity numeric(20, 6) NOT NULL,
  unit_price numeric(20, 6) NOT NULL,
  line_total numeric(20, 6) NOT NULL,
  currency_code char(3) NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT invoice_items_public_id_unique UNIQUE (public_id),
  CONSTRAINT invoice_items_invoice_line_unique UNIQUE (invoice_id, line_no),
  CONSTRAINT invoice_items_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT invoice_items_invoice_tenant_fk FOREIGN KEY (invoice_id, tenant_id)
    REFERENCES public.invoices (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT invoice_items_line_no_positive_check CHECK (line_no > 0),
  CONSTRAINT invoice_items_item_type_not_blank_check CHECK (btrim(item_type) <> ''),
  CONSTRAINT invoice_items_description_not_blank_check CHECK (btrim(description) <> ''),
  CONSTRAINT invoice_items_quantity_non_negative_check CHECK (quantity >= 0),
  CONSTRAINT invoice_items_unit_price_non_negative_check CHECK (unit_price >= 0),
  CONSTRAINT invoice_items_line_total_non_negative_check CHECK (line_total >= 0),
  CONSTRAINT invoice_items_line_total_consistency_check CHECK (
    line_total = quantity * unit_price
  ),
  CONSTRAINT invoice_items_currency_code_format_check CHECK (
    currency_code ~ '^[A-Z]{3}$'
  ),
  CONSTRAINT invoice_items_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX invoice_items_invoice_line_idx
  ON public.invoice_items (invoice_id, line_no);

CREATE INDEX invoice_items_tenant_invoice_idx
  ON public.invoice_items (tenant_id, invoice_id);

CREATE FUNCTION public.prevent_finalized_invoice_item_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  current_status text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO current_status
    FROM public.invoices
    WHERE id = OLD.invoice_id;
  ELSE
    SELECT status INTO current_status
    FROM public.invoices
    WHERE id = NEW.invoice_id;
  END IF;

  IF current_status IS NOT NULL AND current_status <> 'draft' THEN
    RAISE EXCEPTION 'invoice_items cannot be modified when invoice status is %', current_status;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER invoice_items_prevent_when_finalized
  BEFORE INSERT OR UPDATE OR DELETE ON public.invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_finalized_invoice_item_mutation();

CREATE TABLE public.payment_transactions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  invoice_id bigint NOT NULL,
  attempt_no integer NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  provider text,
  provider_transaction_ref text,
  amount numeric(20, 6) NOT NULL,
  currency_code char(3) NOT NULL,
  failure_reason text,
  processed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT payment_transactions_public_id_unique UNIQUE (public_id),
  CONSTRAINT payment_transactions_invoice_attempt_unique UNIQUE (invoice_id, attempt_no),
  CONSTRAINT payment_transactions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT payment_transactions_invoice_tenant_fk FOREIGN KEY (invoice_id, tenant_id)
    REFERENCES public.invoices (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT payment_transactions_attempt_no_positive_check CHECK (attempt_no > 0),
  CONSTRAINT payment_transactions_status_check CHECK (status IN (
    'pending',
    'succeeded',
    'failed',
    'cancelled',
    'refunded'
  )),
  CONSTRAINT payment_transactions_provider_not_blank_check CHECK (
    provider IS NULL OR btrim(provider) <> ''
  ),
  CONSTRAINT payment_transactions_provider_ref_not_blank_check CHECK (
    provider_transaction_ref IS NULL OR btrim(provider_transaction_ref) <> ''
  ),
  CONSTRAINT payment_transactions_amount_non_negative_check CHECK (amount >= 0),
  CONSTRAINT payment_transactions_currency_code_format_check CHECK (
    currency_code ~ '^[A-Z]{3}$'
  ),
  CONSTRAINT payment_transactions_failure_reason_not_blank_check CHECK (
    failure_reason IS NULL OR btrim(failure_reason) <> ''
  ),
  CONSTRAINT payment_transactions_processed_timestamp_check CHECK (
    status = 'pending' OR processed_at IS NOT NULL
  ),
  CONSTRAINT payment_transactions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX payment_transactions_tenant_provider_ref_unique_idx
  ON public.payment_transactions (tenant_id, provider_transaction_ref)
  WHERE provider_transaction_ref IS NOT NULL;

CREATE INDEX payment_transactions_invoice_attempt_idx
  ON public.payment_transactions (invoice_id, attempt_no);

CREATE INDEX payment_transactions_tenant_status_created_at_idx
  ON public.payment_transactions (tenant_id, status, created_at DESC);
