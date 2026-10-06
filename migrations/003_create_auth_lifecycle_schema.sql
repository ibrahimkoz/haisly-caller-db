ALTER TABLE public.users
  ADD CONSTRAINT users_id_tenant_id_unique UNIQUE (id, tenant_id);

ALTER TABLE public.user_credentials
  ADD CONSTRAINT user_credentials_id_user_id_unique UNIQUE (id, user_id);

ALTER TABLE public.user_verified_contacts
  ADD CONSTRAINT user_verified_contacts_id_user_id_unique UNIQUE (id, user_id);

CREATE TABLE public.sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  access_token_jti text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  ip_address inet,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT sessions_public_id_unique UNIQUE (public_id),
  CONSTRAINT sessions_access_token_jti_unique UNIQUE (access_token_jti),
  CONSTRAINT sessions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT sessions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT sessions_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT sessions_status_check CHECK (status IN (
    'active',
    'revoked',
    'expired'
  )),
  CONSTRAINT sessions_access_token_jti_not_blank_check CHECK (btrim(access_token_jti) <> ''),
  CONSTRAINT sessions_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT sessions_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE INDEX sessions_user_status_expires_at_idx
  ON public.sessions (user_id, status, expires_at);

CREATE INDEX sessions_tenant_status_created_at_idx
  ON public.sessions (tenant_id, status, created_at DESC);

CREATE TABLE public.refresh_tokens (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  session_id bigint NOT NULL,
  token_hash text NOT NULL,
  token_family_id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_refresh_token_id bigint,
  status text NOT NULL DEFAULT 'active',
  issued_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  rotated_at timestamptz,
  revoked_at timestamptz,
  reused_at timestamptz,
  CONSTRAINT refresh_tokens_public_id_unique UNIQUE (public_id),
  CONSTRAINT refresh_tokens_token_hash_unique UNIQUE (token_hash),
  CONSTRAINT refresh_tokens_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT refresh_tokens_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT refresh_tokens_session_tenant_fk FOREIGN KEY (session_id, tenant_id)
    REFERENCES public.sessions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT refresh_tokens_parent_refresh_token_id_fk FOREIGN KEY (parent_refresh_token_id)
    REFERENCES public.refresh_tokens (id)
    ON DELETE SET NULL,
  CONSTRAINT refresh_tokens_status_check CHECK (status IN (
    'active',
    'rotated',
    'revoked',
    'expired',
    'reused'
  )),
  CONSTRAINT refresh_tokens_token_hash_not_blank_check CHECK (btrim(token_hash) <> ''),
  CONSTRAINT refresh_tokens_token_hash_length_check CHECK (length(token_hash) >= 20),
  CONSTRAINT refresh_tokens_expiry_check CHECK (expires_at > issued_at),
  CONSTRAINT refresh_tokens_rotated_timestamp_check CHECK (
    status <> 'rotated' OR rotated_at IS NOT NULL
  ),
  CONSTRAINT refresh_tokens_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  ),
  CONSTRAINT refresh_tokens_reused_timestamp_check CHECK (
    status <> 'reused' OR reused_at IS NOT NULL
  )
);

CREATE INDEX refresh_tokens_user_status_expires_at_idx
  ON public.refresh_tokens (user_id, status, expires_at);

CREATE INDEX refresh_tokens_family_status_idx
  ON public.refresh_tokens (token_family_id, status);

CREATE TABLE public.password_resets (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  credential_id bigint,
  reset_token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempt_count integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT password_resets_public_id_unique UNIQUE (public_id),
  CONSTRAINT password_resets_reset_token_hash_unique UNIQUE (reset_token_hash),
  CONSTRAINT password_resets_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT password_resets_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT password_resets_credential_user_fk FOREIGN KEY (credential_id, user_id)
    REFERENCES public.user_credentials (id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT password_resets_status_check CHECK (status IN (
    'pending',
    'used',
    'expired',
    'revoked'
  )),
  CONSTRAINT password_resets_token_hash_not_blank_check CHECK (btrim(reset_token_hash) <> ''),
  CONSTRAINT password_resets_token_hash_length_check CHECK (length(reset_token_hash) >= 20),
  CONSTRAINT password_resets_attempts_check CHECK (
    attempt_count >= 0 AND max_attempts > 0 AND attempt_count <= max_attempts
  ),
  CONSTRAINT password_resets_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT password_resets_used_timestamp_check CHECK (
    status <> 'used' OR used_at IS NOT NULL
  ),
  CONSTRAINT password_resets_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE INDEX password_resets_user_status_expires_at_idx
  ON public.password_resets (user_id, status, expires_at);

CREATE TABLE public.otp_challenges (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint,
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
  CONSTRAINT otp_challenges_public_id_unique UNIQUE (public_id),
  CONSTRAINT otp_challenges_code_hash_unique UNIQUE (code_hash),
  CONSTRAINT otp_challenges_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT otp_challenges_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT otp_challenges_purpose_check CHECK (purpose IN (
    'login_mfa',
    'email_verification',
    'password_reset',
    'phone_verification'
  )),
  CONSTRAINT otp_challenges_delivery_channel_check CHECK (delivery_channel IN ('email', 'sms')),
  CONSTRAINT otp_challenges_status_check CHECK (status IN (
    'pending',
    'verified',
    'expired',
    'cancelled',
    'max_attempts_exceeded'
  )),
  CONSTRAINT otp_challenges_destination_hash_not_blank_check CHECK (btrim(destination_hash) <> ''),
  CONSTRAINT otp_challenges_code_hash_not_blank_check CHECK (btrim(code_hash) <> ''),
  CONSTRAINT otp_challenges_code_hash_length_check CHECK (length(code_hash) >= 20),
  CONSTRAINT otp_challenges_attempts_check CHECK (
    attempt_count >= 0 AND max_attempts > 0 AND attempt_count <= max_attempts
  ),
  CONSTRAINT otp_challenges_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT otp_challenges_verified_timestamp_check CHECK (
    status <> 'verified' OR verified_at IS NOT NULL
  ),
  CONSTRAINT otp_challenges_cancelled_timestamp_check CHECK (
    status <> 'cancelled' OR cancelled_at IS NOT NULL
  )
);

CREATE INDEX otp_challenges_user_purpose_status_expires_at_idx
  ON public.otp_challenges (user_id, purpose, status, expires_at);

CREATE INDEX otp_challenges_tenant_purpose_created_at_idx
  ON public.otp_challenges (tenant_id, purpose, created_at DESC);

CREATE TABLE public.mfa_factors (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  verified_contact_id bigint,
  factor_type text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  secret_ref text,
  created_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  disabled_at timestamptz,
  CONSTRAINT mfa_factors_public_id_unique UNIQUE (public_id),
  CONSTRAINT mfa_factors_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT mfa_factors_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT mfa_factors_verified_contact_user_fk FOREIGN KEY (verified_contact_id, user_id)
    REFERENCES public.user_verified_contacts (id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT mfa_factors_factor_type_check CHECK (factor_type IN (
    'email_otp',
    'sms_otp',
    'totp'
  )),
  CONSTRAINT mfa_factors_status_check CHECK (status IN (
    'pending_verification',
    'active',
    'disabled'
  )),
  CONSTRAINT mfa_factors_secret_ref_not_blank_check CHECK (
    secret_ref IS NULL OR btrim(secret_ref) <> ''
  ),
  CONSTRAINT mfa_factors_disabled_timestamp_check CHECK (
    status <> 'disabled' OR disabled_at IS NOT NULL
  )
);

CREATE INDEX mfa_factors_user_status_idx
  ON public.mfa_factors (user_id, status);

CREATE TABLE public.mfa_recovery_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  target_user_id bigint NOT NULL,
  requested_by_user_id bigint,
  recovery_scope text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  reason text NOT NULL,
  evidence_ref text,
  decision_by_user_id bigint,
  decision_at timestamptz,
  completed_at timestamptz,
  audit_correlation_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mfa_recovery_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT mfa_recovery_requests_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT mfa_recovery_requests_target_user_tenant_fk FOREIGN KEY (target_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT mfa_recovery_requests_requested_by_user_tenant_fk FOREIGN KEY (
    requested_by_user_id,
    tenant_id
  )
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT mfa_recovery_requests_decision_by_user_tenant_fk FOREIGN KEY (
    decision_by_user_id,
    tenant_id
  )
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT mfa_recovery_requests_scope_check CHECK (recovery_scope IN (
    'tenant_admin',
    'platform_support'
  )),
  CONSTRAINT mfa_recovery_requests_status_check CHECK (status IN (
    'pending',
    'approved',
    'rejected',
    'cancelled',
    'completed'
  )),
  CONSTRAINT mfa_recovery_requests_reason_not_blank_check CHECK (btrim(reason) <> ''),
  CONSTRAINT mfa_recovery_requests_evidence_ref_not_blank_check CHECK (
    evidence_ref IS NULL OR btrim(evidence_ref) <> ''
  ),
  CONSTRAINT mfa_recovery_requests_audit_correlation_not_blank_check CHECK (
    audit_correlation_id IS NULL OR btrim(audit_correlation_id) <> ''
  ),
  CONSTRAINT mfa_recovery_requests_decision_timestamp_check CHECK (
    status NOT IN ('approved', 'rejected') OR decision_at IS NOT NULL
  ),
  CONSTRAINT mfa_recovery_requests_completed_timestamp_check CHECK (
    status <> 'completed' OR completed_at IS NOT NULL
  )
);

CREATE INDEX mfa_recovery_requests_target_status_created_at_idx
  ON public.mfa_recovery_requests (target_user_id, status, created_at DESC);

CREATE INDEX mfa_recovery_requests_tenant_status_created_at_idx
  ON public.mfa_recovery_requests (tenant_id, status, created_at DESC);
