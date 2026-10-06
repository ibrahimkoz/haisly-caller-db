CREATE TABLE public.secret_references (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  secret_name text NOT NULL,
  secret_ref text NOT NULL,
  secret_type text NOT NULL DEFAULT 'generic',
  status text NOT NULL DEFAULT 'active',
  rotation_policy text,
  last_rotated_at timestamptz,
  next_rotation_due_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT secret_references_public_id_unique UNIQUE (public_id),
  CONSTRAINT secret_references_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT secret_references_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    secret_name
  ),
  CONSTRAINT secret_references_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT secret_references_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT secret_references_secret_name_not_blank_check CHECK (btrim(secret_name) <> ''),
  CONSTRAINT secret_references_secret_ref_not_blank_check CHECK (btrim(secret_ref) <> ''),
  CONSTRAINT secret_references_secret_type_check CHECK (secret_type IN (
    'generic',
    'api_key',
    'signing_key',
    'webhook_secret',
    'service_account_key',
    'provider_credential'
  )),
  CONSTRAINT secret_references_status_check CHECK (status IN (
    'active',
    'disabled',
    'rotating',
    'revoked'
  )),
  CONSTRAINT secret_references_rotation_policy_not_blank_check CHECK (
    rotation_policy IS NULL OR btrim(rotation_policy) <> ''
  ),
  CONSTRAINT secret_references_next_rotation_after_last_check CHECK (
    next_rotation_due_at IS NULL
    OR last_rotated_at IS NULL
    OR next_rotation_due_at >= last_rotated_at
  ),
  CONSTRAINT secret_references_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX secret_references_tenant_status_updated_at_idx
  ON public.secret_references (tenant_id, status, updated_at DESC);

CREATE INDEX secret_references_tenant_env_type_status_idx
  ON public.secret_references (tenant_id, tenant_environment_id, secret_type, status);

CREATE TABLE public.secret_rotation_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  secret_reference_id bigint NOT NULL,
  requested_by_user_id bigint,
  status text NOT NULL DEFAULT 'requested',
  reason text,
  old_secret_ref text,
  new_secret_ref text,
  error_message text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT secret_rotation_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT secret_rotation_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT secret_rotation_events_secret_tenant_fk FOREIGN KEY (secret_reference_id, tenant_id)
    REFERENCES public.secret_references (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT secret_rotation_events_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT secret_rotation_events_status_check CHECK (status IN (
    'requested',
    'in_progress',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT secret_rotation_events_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT secret_rotation_events_old_ref_not_blank_check CHECK (
    old_secret_ref IS NULL OR btrim(old_secret_ref) <> ''
  ),
  CONSTRAINT secret_rotation_events_new_ref_not_blank_check CHECK (
    new_secret_ref IS NULL OR btrim(new_secret_ref) <> ''
  ),
  CONSTRAINT secret_rotation_events_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT secret_rotation_events_started_after_requested_check CHECK (
    started_at IS NULL OR started_at >= requested_at
  ),
  CONSTRAINT secret_rotation_events_completed_after_started_check CHECK (
    completed_at IS NULL OR completed_at >= COALESCE(started_at, requested_at)
  ),
  CONSTRAINT secret_rotation_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX secret_rotation_events_secret_status_requested_at_idx
  ON public.secret_rotation_events (secret_reference_id, status, requested_at DESC);

CREATE INDEX secret_rotation_events_tenant_status_requested_at_idx
  ON public.secret_rotation_events (tenant_id, status, requested_at DESC);
