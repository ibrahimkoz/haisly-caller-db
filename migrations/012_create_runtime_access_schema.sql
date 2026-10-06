CREATE TABLE public.tenant_environments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  environment_type text NOT NULL DEFAULT 'sandbox',
  status text NOT NULL DEFAULT 'active',
  is_default boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenant_environments_public_id_unique UNIQUE (public_id),
  CONSTRAINT tenant_environments_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT tenant_environments_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT tenant_environments_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT tenant_environments_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT tenant_environments_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT tenant_environments_environment_type_check CHECK (environment_type IN (
    'development',
    'sandbox',
    'staging',
    'production'
  )),
  CONSTRAINT tenant_environments_status_check CHECK (status IN (
    'active',
    'inactive',
    'archived'
  )),
  CONSTRAINT tenant_environments_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX tenant_environments_single_default_idx
  ON public.tenant_environments (tenant_id)
  WHERE is_default = true;

CREATE INDEX tenant_environments_tenant_status_updated_at_idx
  ON public.tenant_environments (tenant_id, status, updated_at DESC);

CREATE TABLE public.service_accounts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  created_by_user_id bigint,
  name text NOT NULL,
  description text,
  auth_mode text NOT NULL DEFAULT 'bearer_jwt',
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_accounts_public_id_unique UNIQUE (public_id),
  CONSTRAINT service_accounts_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT service_accounts_tenant_environment_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    name
  ),
  CONSTRAINT service_accounts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT service_accounts_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT service_accounts_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT service_accounts_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT service_accounts_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT service_accounts_auth_mode_check CHECK (auth_mode IN (
    'bearer_jwt',
    'signed_request'
  )),
  CONSTRAINT service_accounts_status_check CHECK (status IN (
    'active',
    'disabled',
    'rotated'
  )),
  CONSTRAINT service_accounts_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX service_accounts_tenant_status_updated_at_idx
  ON public.service_accounts (tenant_id, status, updated_at DESC);

CREATE INDEX service_accounts_tenant_environment_status_idx
  ON public.service_accounts (tenant_id, tenant_environment_id, status);

CREATE TABLE public.service_account_scopes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  service_account_id bigint NOT NULL,
  scope_code text NOT NULL,
  effect text NOT NULL DEFAULT 'allow',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_account_scopes_public_id_unique UNIQUE (public_id),
  CONSTRAINT service_account_scopes_service_scope_unique UNIQUE (service_account_id, scope_code),
  CONSTRAINT service_account_scopes_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT service_account_scopes_service_account_tenant_fk FOREIGN KEY (service_account_id, tenant_id)
    REFERENCES public.service_accounts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT service_account_scopes_scope_not_blank_check CHECK (btrim(scope_code) <> ''),
  CONSTRAINT service_account_scopes_effect_check CHECK (effect IN (
    'allow',
    'deny'
  )),
  CONSTRAINT service_account_scopes_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX service_account_scopes_tenant_scope_effect_idx
  ON public.service_account_scopes (tenant_id, scope_code, effect);

CREATE TABLE public.service_account_keys (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  service_account_id bigint NOT NULL,
  key_prefix text NOT NULL,
  key_hash text NOT NULL,
  hash_algorithm text NOT NULL DEFAULT 'sha256',
  status text NOT NULL DEFAULT 'active',
  expires_at timestamptz,
  revoked_at timestamptz,
  last_used_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_account_keys_public_id_unique UNIQUE (public_id),
  CONSTRAINT service_account_keys_key_hash_unique UNIQUE (key_hash),
  CONSTRAINT service_account_keys_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT service_account_keys_service_account_tenant_fk FOREIGN KEY (service_account_id, tenant_id)
    REFERENCES public.service_accounts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT service_account_keys_prefix_not_blank_check CHECK (btrim(key_prefix) <> ''),
  CONSTRAINT service_account_keys_hash_length_check CHECK (length(key_hash) >= 32),
  CONSTRAINT service_account_keys_algorithm_not_blank_check CHECK (btrim(hash_algorithm) <> ''),
  CONSTRAINT service_account_keys_status_check CHECK (status IN (
    'active',
    'rotated',
    'revoked',
    'expired'
  )),
  CONSTRAINT service_account_keys_revoked_status_check CHECK (
    revoked_at IS NULL OR status IN ('rotated', 'revoked', 'expired')
  ),
  CONSTRAINT service_account_keys_expiry_after_created_check CHECK (
    expires_at IS NULL OR expires_at > created_at
  ),
  CONSTRAINT service_account_keys_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX service_account_keys_service_status_created_at_idx
  ON public.service_account_keys (service_account_id, status, created_at DESC);

CREATE INDEX service_account_keys_tenant_status_expires_at_idx
  ON public.service_account_keys (tenant_id, status, expires_at);

CREATE TABLE public.idempotency_keys (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  scope text NOT NULL,
  idempotency_key text NOT NULL,
  request_hash text NOT NULL,
  state text NOT NULL DEFAULT 'processing',
  response_status integer,
  response_body jsonb,
  locked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT idempotency_keys_public_id_unique UNIQUE (public_id),
  CONSTRAINT idempotency_keys_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT idempotency_keys_tenant_scope_key_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    scope,
    idempotency_key
  ),
  CONSTRAINT idempotency_keys_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT idempotency_keys_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT idempotency_keys_scope_not_blank_check CHECK (btrim(scope) <> ''),
  CONSTRAINT idempotency_keys_key_not_blank_check CHECK (btrim(idempotency_key) <> ''),
  CONSTRAINT idempotency_keys_request_hash_length_check CHECK (length(request_hash) >= 32),
  CONSTRAINT idempotency_keys_state_check CHECK (state IN (
    'processing',
    'completed',
    'failed'
  )),
  CONSTRAINT idempotency_keys_response_status_range_check CHECK (
    response_status IS NULL OR (response_status >= 100 AND response_status <= 599)
  ),
  CONSTRAINT idempotency_keys_response_body_shape_check CHECK (
    response_body IS NULL OR jsonb_typeof(response_body) IN ('object', 'array')
  ),
  CONSTRAINT idempotency_keys_expiry_after_created_check CHECK (expires_at > created_at)
);

CREATE INDEX idempotency_keys_tenant_scope_expires_at_idx
  ON public.idempotency_keys (tenant_id, scope, expires_at);

CREATE INDEX idempotency_keys_tenant_state_created_at_idx
  ON public.idempotency_keys (tenant_id, state, created_at DESC);
