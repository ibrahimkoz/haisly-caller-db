CREATE TABLE public.provider_credentials (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  provider text NOT NULL,
  credential_name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  encrypted_payload text NOT NULL,
  encryption_iv text NOT NULL,
  encryption_auth_tag text NOT NULL,
  encryption_key_version text NOT NULL DEFAULT 'v1',
  last_rotated_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT provider_credentials_public_id_unique UNIQUE (public_id),
  CONSTRAINT provider_credentials_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT provider_credentials_tenant_provider_name_unique UNIQUE (
    tenant_id,
    provider,
    credential_name
  ),
  CONSTRAINT provider_credentials_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT provider_credentials_provider_not_blank_check CHECK (btrim(provider) <> ''),
  CONSTRAINT provider_credentials_name_not_blank_check CHECK (btrim(credential_name) <> ''),
  CONSTRAINT provider_credentials_encrypted_payload_not_blank_check CHECK (btrim(encrypted_payload) <> ''),
  CONSTRAINT provider_credentials_encryption_iv_not_blank_check CHECK (btrim(encryption_iv) <> ''),
  CONSTRAINT provider_credentials_auth_tag_not_blank_check CHECK (btrim(encryption_auth_tag) <> ''),
  CONSTRAINT provider_credentials_key_version_not_blank_check CHECK (btrim(encryption_key_version) <> ''),
  CONSTRAINT provider_credentials_status_check CHECK (status IN (
    'active',
    'disabled',
    'rotating',
    'revoked'
  )),
  CONSTRAINT provider_credentials_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX provider_credentials_tenant_provider_status_idx
  ON public.provider_credentials (tenant_id, provider, status, updated_at DESC);
