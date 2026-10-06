DROP INDEX IF EXISTS public.notification_deliveries_push_status_queued_at_idx;
DROP INDEX IF EXISTS public.notification_deliveries_source_push_unique_idx;

ALTER TABLE public.notification_deliveries
  DROP CONSTRAINT IF EXISTS notification_deliveries_web_push_subscription_tenant_fk,
  DROP CONSTRAINT IF EXISTS notification_deliveries_source_notification_tenant_fk,
  DROP COLUMN IF EXISTS web_push_subscription_id,
  DROP COLUMN IF EXISTS source_notification_id;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_id_tenant_id_unique;

DROP TABLE IF EXISTS public.web_push_subscriptions;

ALTER TABLE public.notification_deliveries
  DROP CONSTRAINT notification_deliveries_channel_check,
  ADD CONSTRAINT notification_deliveries_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  ));

ALTER TABLE public.notification_preferences
  DROP CONSTRAINT notification_preferences_channel_check,
  ADD CONSTRAINT notification_preferences_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  ));

ALTER TABLE public.notification_templates
  DROP CONSTRAINT notification_templates_channel_check,
  ADD CONSTRAINT notification_templates_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  ));
