DROP INDEX IF EXISTS public.webhook_deliveries_subscription_status_created_at_idx;
DROP INDEX IF EXISTS public.webhook_deliveries_tenant_status_next_attempt_idx;
DROP INDEX IF EXISTS public.webhook_deliveries_tenant_subscription_event_latest_unique_idx;

DROP TABLE IF EXISTS public.webhook_deliveries;

DROP INDEX IF EXISTS public.webhook_subscriptions_tenant_env_status_idx;
DROP INDEX IF EXISTS public.webhook_subscriptions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.webhook_subscriptions;
