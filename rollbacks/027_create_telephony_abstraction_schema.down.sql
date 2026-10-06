DROP INDEX IF EXISTS public.provider_event_mappings_tenant_call_event_idx;
DROP INDEX IF EXISTS public.provider_event_mappings_tenant_status_mapped_at_idx;

DROP TABLE IF EXISTS public.provider_event_mappings;

DROP INDEX IF EXISTS public.provider_webhook_events_tenant_provider_type_occurred_at_idx;
DROP INDEX IF EXISTS public.provider_webhook_events_tenant_status_received_at_idx;

DROP TABLE IF EXISTS public.provider_webhook_events;

DROP INDEX IF EXISTS public.phone_number_orders_tenant_provider_status_idx;
DROP INDEX IF EXISTS public.phone_number_orders_tenant_env_status_requested_at_idx;

DROP TABLE IF EXISTS public.phone_number_orders;

DROP INDEX IF EXISTS public.telephony_provider_accounts_tenant_provider_status_idx;
DROP INDEX IF EXISTS public.telephony_provider_accounts_tenant_env_status_updated_at_idx;

DROP TABLE IF EXISTS public.telephony_provider_accounts;
