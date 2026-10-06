DROP INDEX IF EXISTS public.notification_deliveries_follow_up_status_idx;
DROP INDEX IF EXISTS public.notification_deliveries_tenant_status_queued_at_idx;

DROP TABLE IF EXISTS public.notification_deliveries;

DROP INDEX IF EXISTS public.notification_preferences_tenant_channel_enabled_idx;

DROP TABLE IF EXISTS public.notification_preferences;

DROP INDEX IF EXISTS public.notification_templates_tenant_channel_status_idx;

DROP TABLE IF EXISTS public.notification_templates;
