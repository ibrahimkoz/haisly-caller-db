DROP INDEX IF EXISTS public.payment_transactions_tenant_status_created_at_idx;
DROP INDEX IF EXISTS public.payment_transactions_invoice_attempt_idx;
DROP INDEX IF EXISTS public.payment_transactions_tenant_provider_ref_unique_idx;

DROP TABLE IF EXISTS public.payment_transactions;

DROP TRIGGER IF EXISTS invoice_items_prevent_when_finalized ON public.invoice_items;
DROP FUNCTION IF EXISTS public.prevent_finalized_invoice_item_mutation();

DROP INDEX IF EXISTS public.invoice_items_tenant_invoice_idx;
DROP INDEX IF EXISTS public.invoice_items_invoice_line_idx;

DROP TABLE IF EXISTS public.invoice_items;

DROP INDEX IF EXISTS public.invoices_tenant_status_created_at_idx;
DROP INDEX IF EXISTS public.invoices_tenant_period_idx;

DROP TABLE IF EXISTS public.invoices;

DROP INDEX IF EXISTS public.usage_events_tenant_metric_occurred_at_idx;
DROP INDEX IF EXISTS public.usage_events_tenant_period_occurred_at_idx;
DROP INDEX IF EXISTS public.usage_events_tenant_source_event_unique_idx;

DROP TABLE IF EXISTS public.usage_events;

DROP INDEX IF EXISTS public.pricing_plans_status_code_idx;

DROP TABLE IF EXISTS public.pricing_plans;
