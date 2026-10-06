DROP INDEX IF EXISTS public.follow_up_tasks_tenant_assigned_status_due_at_idx;
DROP INDEX IF EXISTS public.follow_up_tasks_tenant_status_due_at_idx;

DROP TABLE IF EXISTS public.follow_up_tasks;

DROP INDEX IF EXISTS public.lead_events_tenant_event_type_occurred_at_idx;
DROP INDEX IF EXISTS public.lead_events_lead_occurred_at_idx;

DROP TABLE IF EXISTS public.lead_events;

DROP INDEX IF EXISTS public.leads_tenant_customer_created_at_idx;
DROP INDEX IF EXISTS public.leads_tenant_status_owner_created_at_idx;

DROP TABLE IF EXISTS public.leads;
