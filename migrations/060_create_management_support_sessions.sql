CREATE TABLE public.management_support_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  requested_by_platform_admin_user_id bigint NOT NULL,
  approved_by_platform_admin_user_id bigint,
  revoked_by_platform_admin_user_id bigint,
  status text NOT NULL DEFAULT 'requested',
  access_scope text NOT NULL DEFAULT 'read_only',
  reason text NOT NULL,
  approval_note text,
  revoke_reason text,
  starts_at timestamptz,
  expires_at timestamptz NOT NULL,
  approved_at timestamptz,
  revoked_at timestamptz,
  last_used_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT management_support_sessions_public_id_unique UNIQUE (public_id),
  CONSTRAINT management_support_sessions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT management_support_sessions_requested_by_fk FOREIGN KEY (requested_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE RESTRICT,
  CONSTRAINT management_support_sessions_approved_by_fk FOREIGN KEY (approved_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT management_support_sessions_revoked_by_fk FOREIGN KEY (revoked_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT management_support_sessions_status_check CHECK (status IN (
    'requested',
    'approved',
    'active',
    'expired',
    'revoked',
    'denied'
  )),
  CONSTRAINT management_support_sessions_access_scope_check CHECK (access_scope IN (
    'read_only',
    'operations',
    'billing',
    'security'
  )),
  CONSTRAINT management_support_sessions_reason_not_blank_check CHECK (btrim(reason) <> ''),
  CONSTRAINT management_support_sessions_approval_note_not_blank_check CHECK (
    approval_note IS NULL OR btrim(approval_note) <> ''
  ),
  CONSTRAINT management_support_sessions_revoke_reason_not_blank_check CHECK (
    revoke_reason IS NULL OR btrim(revoke_reason) <> ''
  ),
  CONSTRAINT management_support_sessions_expiry_check CHECK (
    expires_at > COALESCE(starts_at, created_at)
  ),
  CONSTRAINT management_support_sessions_approved_timestamp_check CHECK (
    status NOT IN ('approved', 'active') OR approved_at IS NOT NULL
  ),
  CONSTRAINT management_support_sessions_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  ),
  CONSTRAINT management_support_sessions_denied_timestamp_check CHECK (
    status <> 'denied' OR approved_at IS NULL
  ),
  CONSTRAINT management_support_sessions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX management_support_sessions_tenant_status_expires_at_idx
  ON public.management_support_sessions (tenant_id, status, expires_at DESC);

CREATE INDEX management_support_sessions_requester_status_created_at_idx
  ON public.management_support_sessions (requested_by_platform_admin_user_id, status, created_at DESC);

CREATE INDEX management_support_sessions_status_updated_at_idx
  ON public.management_support_sessions (status, updated_at DESC);
