CREATE TABLE public.platform_admin_otp_challenges (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_user_id bigint NOT NULL,
  purpose text NOT NULL,
  delivery_channel text NOT NULL,
  destination_hash text NOT NULL,
  code_hash text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempt_count integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  verified_at timestamptz,
  cancelled_at timestamptz,
  CONSTRAINT platform_admin_otp_challenges_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_otp_challenges_code_hash_unique UNIQUE (code_hash),
  CONSTRAINT platform_admin_otp_challenges_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_otp_challenges_purpose_check CHECK (purpose IN (
    'login_mfa',
    'password_reset'
  )),
  CONSTRAINT platform_admin_otp_challenges_delivery_channel_check CHECK (delivery_channel IN ('email')),
  CONSTRAINT platform_admin_otp_challenges_status_check CHECK (status IN (
    'pending',
    'verified',
    'expired',
    'cancelled',
    'max_attempts_exceeded'
  )),
  CONSTRAINT platform_admin_otp_challenges_destination_hash_not_blank_check CHECK (btrim(destination_hash) <> ''),
  CONSTRAINT platform_admin_otp_challenges_code_hash_not_blank_check CHECK (btrim(code_hash) <> ''),
  CONSTRAINT platform_admin_otp_challenges_code_hash_length_check CHECK (length(code_hash) >= 20),
  CONSTRAINT platform_admin_otp_challenges_attempts_check CHECK (
    attempt_count >= 0 AND max_attempts > 0 AND attempt_count <= max_attempts
  ),
  CONSTRAINT platform_admin_otp_challenges_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT platform_admin_otp_challenges_verified_timestamp_check CHECK (
    status <> 'verified' OR verified_at IS NOT NULL
  ),
  CONSTRAINT platform_admin_otp_challenges_cancelled_timestamp_check CHECK (
    status <> 'cancelled' OR cancelled_at IS NOT NULL
  )
);

CREATE INDEX pa_otp_challenges_user_purpose_status_expires_at_idx
  ON public.platform_admin_otp_challenges (platform_admin_user_id, purpose, status, expires_at);

CREATE INDEX pa_otp_challenges_purpose_created_at_idx
  ON public.platform_admin_otp_challenges (purpose, created_at DESC);

CREATE TABLE public.platform_admin_password_resets (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_user_id bigint NOT NULL,
  platform_admin_credential_id bigint NOT NULL,
  reset_token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempt_count integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT platform_admin_password_resets_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_password_resets_token_hash_unique UNIQUE (reset_token_hash),
  CONSTRAINT platform_admin_password_resets_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_password_resets_credential_fk FOREIGN KEY (platform_admin_credential_id)
    REFERENCES public.platform_admin_credentials (id)
    ON DELETE RESTRICT,
  CONSTRAINT platform_admin_password_resets_status_check CHECK (status IN (
    'pending',
    'used',
    'expired',
    'revoked'
  )),
  CONSTRAINT platform_admin_password_resets_token_hash_not_blank_check CHECK (btrim(reset_token_hash) <> ''),
  CONSTRAINT platform_admin_password_resets_token_hash_length_check CHECK (length(reset_token_hash) >= 20),
  CONSTRAINT platform_admin_password_resets_attempts_check CHECK (
    attempt_count >= 0 AND max_attempts > 0 AND attempt_count <= max_attempts
  ),
  CONSTRAINT platform_admin_password_resets_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT platform_admin_password_resets_used_timestamp_check CHECK (
    status <> 'used' OR used_at IS NOT NULL
  ),
  CONSTRAINT platform_admin_password_resets_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE INDEX pa_password_resets_user_status_expires_at_idx
  ON public.platform_admin_password_resets (platform_admin_user_id, status, expires_at);
