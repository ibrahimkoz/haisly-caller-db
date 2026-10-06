ALTER TABLE public.notification_templates
  DROP CONSTRAINT notification_templates_channel_check,
  ADD CONSTRAINT notification_templates_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook',
    'push'
  ));

ALTER TABLE public.notification_preferences
  DROP CONSTRAINT notification_preferences_channel_check,
  ADD CONSTRAINT notification_preferences_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook',
    'push'
  ));

ALTER TABLE public.notification_deliveries
  DROP CONSTRAINT notification_deliveries_channel_check,
  ADD CONSTRAINT notification_deliveries_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook',
    'push'
  ));

CREATE TABLE public.web_push_subscriptions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  endpoint_hash text NOT NULL,
  encrypted_subscription text NOT NULL,
  encryption_auth_tag text NOT NULL,
  encryption_iv text NOT NULL,
  encryption_key_version text NOT NULL DEFAULT 'v1',
  expiration_time timestamptz,
  status text NOT NULL DEFAULT 'active',
  failure_count integer NOT NULL DEFAULT 0,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT web_push_subscriptions_public_id_unique UNIQUE (public_id),
  CONSTRAINT web_push_subscriptions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT web_push_subscriptions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT web_push_subscriptions_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT web_push_subscriptions_endpoint_hash_check CHECK (endpoint_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT web_push_subscriptions_encrypted_subscription_not_blank_check CHECK (
    btrim(encrypted_subscription) <> ''
  ),
  CONSTRAINT web_push_subscriptions_encryption_auth_tag_not_blank_check CHECK (
    btrim(encryption_auth_tag) <> ''
  ),
  CONSTRAINT web_push_subscriptions_encryption_iv_not_blank_check CHECK (
    btrim(encryption_iv) <> ''
  ),
  CONSTRAINT web_push_subscriptions_encryption_key_version_not_blank_check CHECK (
    btrim(encryption_key_version) <> ''
  ),
  CONSTRAINT web_push_subscriptions_status_check CHECK (status IN (
    'active',
    'expired',
    'revoked'
  )),
  CONSTRAINT web_push_subscriptions_failure_count_non_negative_check CHECK (failure_count >= 0),
  CONSTRAINT web_push_subscriptions_last_error_not_blank_check CHECK (
    last_error_code IS NULL OR btrim(last_error_code) <> ''
  )
);

CREATE UNIQUE INDEX web_push_subscriptions_endpoint_hash_unique_idx
  ON public.web_push_subscriptions (endpoint_hash)
  WHERE deleted_at IS NULL;

CREATE INDEX web_push_subscriptions_user_status_updated_at_idx
  ON public.web_push_subscriptions (tenant_id, user_id, status, updated_at DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_id_tenant_id_unique UNIQUE (id, tenant_id);

ALTER TABLE public.notification_deliveries
  ADD COLUMN source_notification_id bigint,
  ADD COLUMN web_push_subscription_id bigint,
  ADD CONSTRAINT notification_deliveries_source_notification_tenant_fk
    FOREIGN KEY (source_notification_id, tenant_id)
    REFERENCES public.notifications (id, tenant_id)
    ON DELETE CASCADE,
  ADD CONSTRAINT notification_deliveries_web_push_subscription_tenant_fk
    FOREIGN KEY (web_push_subscription_id, tenant_id)
    REFERENCES public.web_push_subscriptions (id, tenant_id)
    ON DELETE RESTRICT;

CREATE UNIQUE INDEX notification_deliveries_source_push_unique_idx
  ON public.notification_deliveries (source_notification_id, web_push_subscription_id)
  WHERE source_notification_id IS NOT NULL AND web_push_subscription_id IS NOT NULL;

CREATE INDEX notification_deliveries_push_status_queued_at_idx
  ON public.notification_deliveries (status, queued_at ASC)
  WHERE channel = 'push';
