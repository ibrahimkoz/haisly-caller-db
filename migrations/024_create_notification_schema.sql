CREATE TABLE public.notification_templates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  channel text NOT NULL,
  language text,
  name text NOT NULL,
  subject_template text,
  body_template text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_templates_public_id_unique UNIQUE (public_id),
  CONSTRAINT notification_templates_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT notification_templates_tenant_code_channel_lang_unique UNIQUE (
    tenant_id,
    code,
    channel,
    language
  ),
  CONSTRAINT notification_templates_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT notification_templates_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT notification_templates_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT notification_templates_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  )),
  CONSTRAINT notification_templates_language_not_blank_check CHECK (
    language IS NULL OR btrim(language) <> ''
  ),
  CONSTRAINT notification_templates_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT notification_templates_subject_not_blank_check CHECK (
    subject_template IS NULL OR btrim(subject_template) <> ''
  ),
  CONSTRAINT notification_templates_body_not_blank_check CHECK (btrim(body_template) <> ''),
  CONSTRAINT notification_templates_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT notification_templates_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX notification_templates_tenant_channel_status_idx
  ON public.notification_templates (tenant_id, channel, status);

CREATE TABLE public.notification_preferences (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  channel text NOT NULL,
  preference_scope text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  mute_until timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_preferences_public_id_unique UNIQUE (public_id),
  CONSTRAINT notification_preferences_user_channel_scope_unique UNIQUE (
    user_id,
    channel,
    preference_scope
  ),
  CONSTRAINT notification_preferences_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT notification_preferences_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT notification_preferences_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  )),
  CONSTRAINT notification_preferences_scope_check CHECK (preference_scope IN (
    'all',
    'security',
    'billing',
    'operations',
    'follow_up'
  )),
  CONSTRAINT notification_preferences_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX notification_preferences_tenant_channel_enabled_idx
  ON public.notification_preferences (tenant_id, channel, enabled);

CREATE TABLE public.notification_deliveries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  notification_template_id bigint,
  user_id bigint,
  follow_up_task_id bigint,
  channel text NOT NULL,
  destination_ref text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued',
  provider text,
  provider_message_ref text,
  attempt_no integer NOT NULL DEFAULT 1,
  max_attempts integer NOT NULL DEFAULT 5,
  error_message text,
  queued_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  delivered_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_deliveries_public_id_unique UNIQUE (public_id),
  CONSTRAINT notification_deliveries_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT notification_deliveries_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT notification_deliveries_template_tenant_fk FOREIGN KEY (notification_template_id, tenant_id)
    REFERENCES public.notification_templates (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT notification_deliveries_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT notification_deliveries_follow_up_task_tenant_fk FOREIGN KEY (follow_up_task_id, tenant_id)
    REFERENCES public.follow_up_tasks (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT notification_deliveries_channel_check CHECK (channel IN (
    'email',
    'sms',
    'whatsapp',
    'slack',
    'webhook'
  )),
  CONSTRAINT notification_deliveries_destination_ref_not_blank_check CHECK (btrim(destination_ref) <> ''),
  CONSTRAINT notification_deliveries_status_check CHECK (status IN (
    'queued',
    'sending',
    'sent',
    'delivered',
    'failed',
    'cancelled'
  )),
  CONSTRAINT notification_deliveries_provider_not_blank_check CHECK (
    provider IS NULL OR btrim(provider) <> ''
  ),
  CONSTRAINT notification_deliveries_provider_message_ref_not_blank_check CHECK (
    provider_message_ref IS NULL OR btrim(provider_message_ref) <> ''
  ),
  CONSTRAINT notification_deliveries_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT notification_deliveries_max_attempts_positive_check CHECK (max_attempts > 0),
  CONSTRAINT notification_deliveries_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT notification_deliveries_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT notification_deliveries_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT notification_deliveries_sent_after_queued_check CHECK (
    sent_at IS NULL OR sent_at >= queued_at
  ),
  CONSTRAINT notification_deliveries_delivered_after_sent_check CHECK (
    delivered_at IS NULL OR delivered_at >= COALESCE(sent_at, queued_at)
  )
);

CREATE INDEX notification_deliveries_tenant_status_queued_at_idx
  ON public.notification_deliveries (tenant_id, status, queued_at ASC);

CREATE INDEX notification_deliveries_follow_up_status_idx
  ON public.notification_deliveries (follow_up_task_id, status, queued_at DESC)
  WHERE follow_up_task_id IS NOT NULL;
