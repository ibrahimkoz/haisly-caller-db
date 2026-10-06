CREATE TABLE public.users (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  primary_email text NOT NULL,
  primary_email_normalized text GENERATED ALWAYS AS (lower(primary_email)) STORED,
  display_name text NOT NULL,
  status text NOT NULL DEFAULT 'pending_email_verification',
  email_verified_at timestamptz,
  locale text NOT NULL DEFAULT 'en',
  timezone text NOT NULL DEFAULT 'UTC',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT users_public_id_unique UNIQUE (public_id),
  CONSTRAINT users_primary_email_normalized_unique UNIQUE (primary_email_normalized),
  CONSTRAINT users_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT users_primary_email_format_check CHECK (
    primary_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  CONSTRAINT users_display_name_not_blank_check CHECK (btrim(display_name) <> ''),
  CONSTRAINT users_status_check CHECK (status IN (
    'pending_email_verification',
    'active',
    'disabled'
  )),
  CONSTRAINT users_active_requires_verified_email_check CHECK (
    status <> 'active' OR email_verified_at IS NOT NULL
  )
);

CREATE INDEX users_tenant_status_created_at_idx
  ON public.users (tenant_id, status, created_at DESC);

CREATE INDEX users_tenant_public_id_idx
  ON public.users (tenant_id, public_id);

CREATE INDEX users_deleted_at_idx
  ON public.users (deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE TABLE public.user_invitations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  invited_email text NOT NULL,
  invited_email_normalized text GENERATED ALWAYS AS (lower(invited_email)) STORED,
  inviter_user_id bigint,
  status text NOT NULL DEFAULT 'pending',
  token_hash text NOT NULL,
  role_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  expires_at timestamptz NOT NULL,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_invitations_public_id_unique UNIQUE (public_id),
  CONSTRAINT user_invitations_token_hash_unique UNIQUE (token_hash),
  CONSTRAINT user_invitations_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT user_invitations_inviter_user_id_fk FOREIGN KEY (inviter_user_id)
    REFERENCES public.users (id)
    ON DELETE SET NULL,
  CONSTRAINT user_invitations_email_format_check CHECK (
    invited_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  CONSTRAINT user_invitations_status_check CHECK (status IN (
    'pending',
    'accepted',
    'revoked',
    'expired'
  )),
  CONSTRAINT user_invitations_token_hash_not_blank_check CHECK (btrim(token_hash) <> ''),
  CONSTRAINT user_invitations_role_codes_array_check CHECK (jsonb_typeof(role_codes) = 'array'),
  CONSTRAINT user_invitations_acceptance_timestamp_check CHECK (
    status <> 'accepted' OR accepted_at IS NOT NULL
  ),
  CONSTRAINT user_invitations_revocation_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE UNIQUE INDEX user_invitations_pending_email_unique_idx
  ON public.user_invitations (invited_email_normalized)
  WHERE status = 'pending';

CREATE INDEX user_invitations_tenant_status_expires_at_idx
  ON public.user_invitations (tenant_id, status, expires_at);

CREATE INDEX user_invitations_tenant_public_id_idx
  ON public.user_invitations (tenant_id, public_id);

CREATE TABLE public.user_settings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id bigint NOT NULL,
  language text NOT NULL DEFAULT 'en',
  timezone text NOT NULL DEFAULT 'UTC',
  notification_preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  mfa_delivery_preference text NOT NULL DEFAULT 'email_otp',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_settings_user_id_unique UNIQUE (user_id),
  CONSTRAINT user_settings_user_id_fk FOREIGN KEY (user_id)
    REFERENCES public.users (id)
    ON DELETE CASCADE,
  CONSTRAINT user_settings_language_check CHECK (language IN ('en', 'tr')),
  CONSTRAINT user_settings_notification_preferences_object_check CHECK (
    jsonb_typeof(notification_preferences) = 'object'
  ),
  CONSTRAINT user_settings_mfa_delivery_preference_check CHECK (
    mfa_delivery_preference IN ('email_otp', 'sms_otp')
  )
);

CREATE TABLE public.user_verified_contacts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id bigint NOT NULL,
  contact_type text NOT NULL,
  contact_value text NOT NULL,
  normalized_value text NOT NULL,
  verified_at timestamptz,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_verified_contacts_public_id_unique UNIQUE (public_id),
  CONSTRAINT user_verified_contacts_user_contact_unique UNIQUE (
    user_id,
    contact_type,
    normalized_value
  ),
  CONSTRAINT user_verified_contacts_user_id_fk FOREIGN KEY (user_id)
    REFERENCES public.users (id)
    ON DELETE CASCADE,
  CONSTRAINT user_verified_contacts_contact_type_check CHECK (contact_type IN ('email', 'phone')),
  CONSTRAINT user_verified_contacts_contact_value_not_blank_check CHECK (btrim(contact_value) <> ''),
  CONSTRAINT user_verified_contacts_normalized_value_not_blank_check CHECK (btrim(normalized_value) <> '')
);

CREATE INDEX user_verified_contacts_user_verified_at_idx
  ON public.user_verified_contacts (user_id, contact_type, verified_at DESC);

CREATE INDEX user_verified_contacts_user_primary_idx
  ON public.user_verified_contacts (user_id, contact_type)
  WHERE is_primary = true;

CREATE TABLE public.user_credentials (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id bigint NOT NULL,
  credential_type text NOT NULL,
  identifier text NOT NULL,
  identifier_normalized text GENERATED ALWAYS AS (lower(identifier)) STORED,
  secret_hash text NOT NULL,
  hash_algorithm text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  CONSTRAINT user_credentials_public_id_unique UNIQUE (public_id),
  CONSTRAINT user_credentials_type_identifier_unique UNIQUE (
    credential_type,
    identifier_normalized
  ),
  CONSTRAINT user_credentials_user_id_fk FOREIGN KEY (user_id)
    REFERENCES public.users (id)
    ON DELETE CASCADE,
  CONSTRAINT user_credentials_type_check CHECK (credential_type IN ('password')),
  CONSTRAINT user_credentials_identifier_not_blank_check CHECK (btrim(identifier) <> ''),
  CONSTRAINT user_credentials_secret_hash_not_blank_check CHECK (btrim(secret_hash) <> ''),
  CONSTRAINT user_credentials_secret_hash_length_check CHECK (length(secret_hash) >= 20),
  CONSTRAINT user_credentials_hash_algorithm_not_blank_check CHECK (btrim(hash_algorithm) <> ''),
  CONSTRAINT user_credentials_status_check CHECK (status IN (
    'active',
    'disabled',
    'rotated'
  ))
);

CREATE INDEX user_credentials_user_id_idx
  ON public.user_credentials (user_id);
