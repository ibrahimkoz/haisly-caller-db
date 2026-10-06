CREATE TABLE public.notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  recipient_user_id bigint NOT NULL,
  notification_type text NOT NULL,
  category text NOT NULL DEFAULT 'info',
  title text NOT NULL,
  body text NOT NULL,
  severity text NOT NULL DEFAULT 'normal',
  status text NOT NULL DEFAULT 'unread',
  action_url text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT notifications_public_id_unique UNIQUE (public_id),
  CONSTRAINT notifications_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT notifications_recipient_user_tenant_fk FOREIGN KEY (recipient_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT notifications_type_check CHECK (notification_type IN (
    'setup',
    'billing',
    'call',
    'case',
    'lead',
    'follow_up',
    'security',
    'system'
  )),
  CONSTRAINT notifications_category_check CHECK (category IN (
    'info',
    'success',
    'warning',
    'error',
    'action_required'
  )),
  CONSTRAINT notifications_severity_check CHECK (severity IN (
    'low',
    'normal',
    'high',
    'critical'
  )),
  CONSTRAINT notifications_status_check CHECK (status IN (
    'unread',
    'read',
    'archived'
  )),
  CONSTRAINT notifications_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT notifications_body_not_blank_check CHECK (btrim(body) <> ''),
  CONSTRAINT notifications_action_url_internal_check CHECK (
    action_url IS NULL OR action_url ~ '^/app(?:/|$)'
  ),
  CONSTRAINT notifications_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT notifications_read_state_check CHECK (
    (status = 'unread' AND read_at IS NULL)
    OR (status = 'read' AND read_at IS NOT NULL)
    OR status = 'archived'
  )
);

CREATE INDEX notifications_recipient_status_created_at_idx
  ON public.notifications (tenant_id, recipient_user_id, status, created_at DESC, public_id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX notifications_recipient_created_at_idx
  ON public.notifications (tenant_id, recipient_user_id, created_at DESC, public_id DESC)
  WHERE deleted_at IS NULL;
