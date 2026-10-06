DROP INDEX IF EXISTS public.case_events_tenant_event_type_occurred_at_idx;
DROP INDEX IF EXISTS public.case_events_case_occurred_at_idx;

DROP TABLE IF EXISTS public.case_events;

DROP INDEX IF EXISTS public.customer_interactions_call_occurred_at_idx;
DROP INDEX IF EXISTS public.customer_interactions_case_occurred_at_idx;
DROP INDEX IF EXISTS public.customer_interactions_customer_occurred_at_idx;

DROP TABLE IF EXISTS public.customer_interactions;

DROP INDEX IF EXISTS public.customer_contacts_customer_verified_idx;
DROP INDEX IF EXISTS public.customer_contacts_primary_per_type_unique_idx;

DROP TABLE IF EXISTS public.customer_contacts;

DROP INDEX IF EXISTS public.cases_tenant_assigned_user_opened_at_idx;
DROP INDEX IF EXISTS public.cases_tenant_customer_opened_at_idx;
DROP INDEX IF EXISTS public.cases_tenant_status_priority_opened_at_idx;

DROP TABLE IF EXISTS public.cases;

DROP INDEX IF EXISTS public.customers_tenant_display_name_idx;
DROP INDEX IF EXISTS public.customers_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.customers;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_id_tenant_id_unique;
