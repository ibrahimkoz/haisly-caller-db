CREATE TABLE public.telephony_provider_accounts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  provider_code text NOT NULL,
  account_label text NOT NULL,
  provider_account_ref text NOT NULL,
  auth_mode text NOT NULL DEFAULT 'api_key',
  auth_secret_ref text,
  status text NOT NULL DEFAULT 'active',
  capabilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_synced_at timestamptz,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT telephony_provider_accounts_public_id_unique UNIQUE (public_id),
  CONSTRAINT telephony_provider_accounts_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT telephony_provider_accounts_tenant_env_provider_ref_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    provider_code,
    provider_account_ref
  ),
  CONSTRAINT telephony_provider_accounts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT telephony_provider_accounts_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT telephony_provider_accounts_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT telephony_provider_accounts_provider_code_not_blank_check CHECK (btrim(provider_code) <> ''),
  CONSTRAINT telephony_provider_accounts_label_not_blank_check CHECK (btrim(account_label) <> ''),
  CONSTRAINT telephony_provider_accounts_provider_ref_not_blank_check CHECK (btrim(provider_account_ref) <> ''),
  CONSTRAINT telephony_provider_accounts_auth_mode_check CHECK (auth_mode IN (
    'api_key',
    'oauth',
    'signature',
    'none'
  )),
  CONSTRAINT telephony_provider_accounts_auth_secret_ref_not_blank_check CHECK (
    auth_secret_ref IS NULL OR btrim(auth_secret_ref) <> ''
  ),
  CONSTRAINT telephony_provider_accounts_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled',
    'error'
  )),
  CONSTRAINT telephony_provider_accounts_capabilities_array_check CHECK (
    jsonb_typeof(capabilities) = 'array'
  ),
  CONSTRAINT telephony_provider_accounts_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX telephony_provider_accounts_tenant_env_status_updated_at_idx
  ON public.telephony_provider_accounts (tenant_id, tenant_environment_id, status, updated_at DESC);

CREATE INDEX telephony_provider_accounts_tenant_provider_status_idx
  ON public.telephony_provider_accounts (tenant_id, provider_code, status);

CREATE TABLE public.phone_number_orders (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  telephony_provider_account_id bigint NOT NULL,
  phone_number_id bigint,
  provider_order_ref text NOT NULL,
  requested_phone_number text,
  assigned_phone_number text,
  country_code text,
  order_type text NOT NULL DEFAULT 'provision',
  status text NOT NULL DEFAULT 'pending',
  provisioning_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  failure_reason text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT phone_number_orders_public_id_unique UNIQUE (public_id),
  CONSTRAINT phone_number_orders_tenant_provider_order_unique UNIQUE (
    tenant_id,
    telephony_provider_account_id,
    provider_order_ref
  ),
  CONSTRAINT phone_number_orders_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT phone_number_orders_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT phone_number_orders_provider_account_tenant_fk FOREIGN KEY (telephony_provider_account_id, tenant_id)
    REFERENCES public.telephony_provider_accounts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT phone_number_orders_phone_number_tenant_fk FOREIGN KEY (phone_number_id, tenant_id)
    REFERENCES public.phone_numbers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT phone_number_orders_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT phone_number_orders_provider_order_ref_not_blank_check CHECK (btrim(provider_order_ref) <> ''),
  CONSTRAINT phone_number_orders_requested_phone_format_check CHECK (
    requested_phone_number IS NULL OR requested_phone_number ~ '^\+[1-9][0-9]{7,14}$'
  ),
  CONSTRAINT phone_number_orders_assigned_phone_format_check CHECK (
    assigned_phone_number IS NULL OR assigned_phone_number ~ '^\+[1-9][0-9]{7,14}$'
  ),
  CONSTRAINT phone_number_orders_country_code_not_blank_check CHECK (
    country_code IS NULL OR btrim(country_code) <> ''
  ),
  CONSTRAINT phone_number_orders_order_type_check CHECK (order_type IN (
    'provision',
    'port_in',
    'release',
    'update'
  )),
  CONSTRAINT phone_number_orders_status_check CHECK (status IN (
    'pending',
    'submitted',
    'in_progress',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT phone_number_orders_payload_object_check CHECK (jsonb_typeof(provisioning_payload) = 'object'),
  CONSTRAINT phone_number_orders_failure_reason_not_blank_check CHECK (
    failure_reason IS NULL OR btrim(failure_reason) <> ''
  ),
  CONSTRAINT phone_number_orders_completed_after_requested_check CHECK (
    completed_at IS NULL OR completed_at >= requested_at
  ),
  CONSTRAINT phone_number_orders_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX phone_number_orders_tenant_env_status_requested_at_idx
  ON public.phone_number_orders (tenant_id, tenant_environment_id, status, requested_at DESC);

CREATE INDEX phone_number_orders_tenant_provider_status_idx
  ON public.phone_number_orders (tenant_id, telephony_provider_account_id, status, updated_at DESC);

CREATE TABLE public.provider_webhook_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  telephony_provider_account_id bigint,
  provider_code text NOT NULL,
  provider_event_id text NOT NULL,
  provider_event_type text NOT NULL,
  signature_id text,
  delivery_id text,
  source_ip inet,
  normalized_status text NOT NULL DEFAULT 'received',
  validation_error text,
  raw_headers jsonb NOT NULL DEFAULT '{}'::jsonb,
  raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT provider_webhook_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT provider_webhook_events_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT provider_webhook_events_tenant_env_provider_event_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    provider_code,
    provider_event_id
  ),
  CONSTRAINT provider_webhook_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT provider_webhook_events_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT provider_webhook_events_provider_account_tenant_fk FOREIGN KEY (telephony_provider_account_id, tenant_id)
    REFERENCES public.telephony_provider_accounts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT provider_webhook_events_provider_code_not_blank_check CHECK (btrim(provider_code) <> ''),
  CONSTRAINT provider_webhook_events_provider_event_id_not_blank_check CHECK (btrim(provider_event_id) <> ''),
  CONSTRAINT provider_webhook_events_provider_event_type_not_blank_check CHECK (btrim(provider_event_type) <> ''),
  CONSTRAINT provider_webhook_events_signature_id_not_blank_check CHECK (
    signature_id IS NULL OR btrim(signature_id) <> ''
  ),
  CONSTRAINT provider_webhook_events_delivery_id_not_blank_check CHECK (
    delivery_id IS NULL OR btrim(delivery_id) <> ''
  ),
  CONSTRAINT provider_webhook_events_normalized_status_check CHECK (normalized_status IN (
    'received',
    'validated',
    'rejected',
    'mapped',
    'failed',
    'ignored'
  )),
  CONSTRAINT provider_webhook_events_validation_error_not_blank_check CHECK (
    validation_error IS NULL OR btrim(validation_error) <> ''
  ),
  CONSTRAINT provider_webhook_events_raw_headers_object_check CHECK (jsonb_typeof(raw_headers) = 'object'),
  CONSTRAINT provider_webhook_events_raw_payload_shape_check CHECK (
    jsonb_typeof(raw_payload) IN ('object', 'array')
  ),
  CONSTRAINT provider_webhook_events_processed_after_received_check CHECK (
    processed_at IS NULL OR processed_at >= received_at
  ),
  CONSTRAINT provider_webhook_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX provider_webhook_events_tenant_status_received_at_idx
  ON public.provider_webhook_events (tenant_id, normalized_status, received_at DESC);

CREATE INDEX provider_webhook_events_tenant_provider_type_occurred_at_idx
  ON public.provider_webhook_events (tenant_id, provider_code, provider_event_type, occurred_at DESC);

CREATE TABLE public.provider_event_mappings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  provider_webhook_event_id bigint NOT NULL,
  call_id bigint,
  call_event_id bigint,
  call_recording_id bigint,
  mapping_status text NOT NULL DEFAULT 'mapped',
  normalized_event_type text NOT NULL,
  normalized_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  mapping_error text,
  mapped_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT provider_event_mappings_public_id_unique UNIQUE (public_id),
  CONSTRAINT provider_event_mappings_tenant_event_unique UNIQUE (tenant_id, provider_webhook_event_id),
  CONSTRAINT provider_event_mappings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT provider_event_mappings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT provider_event_mappings_webhook_event_tenant_fk FOREIGN KEY (provider_webhook_event_id, tenant_id)
    REFERENCES public.provider_webhook_events (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT provider_event_mappings_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT provider_event_mappings_call_event_tenant_fk FOREIGN KEY (call_event_id, tenant_id)
    REFERENCES public.call_events (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT provider_event_mappings_call_recording_tenant_fk FOREIGN KEY (call_recording_id, tenant_id)
    REFERENCES public.call_recordings (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT provider_event_mappings_status_check CHECK (mapping_status IN (
    'mapped',
    'partially_mapped',
    'unmapped',
    'failed'
  )),
  CONSTRAINT provider_event_mappings_event_type_not_blank_check CHECK (
    btrim(normalized_event_type) <> ''
  ),
  CONSTRAINT provider_event_mappings_payload_object_check CHECK (jsonb_typeof(normalized_payload) = 'object'),
  CONSTRAINT provider_event_mappings_mapping_error_not_blank_check CHECK (
    mapping_error IS NULL OR btrim(mapping_error) <> ''
  ),
  CONSTRAINT provider_event_mappings_error_on_failed_check CHECK (
    mapping_status <> 'failed' OR mapping_error IS NOT NULL
  ),
  CONSTRAINT provider_event_mappings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX provider_event_mappings_tenant_status_mapped_at_idx
  ON public.provider_event_mappings (tenant_id, mapping_status, mapped_at DESC);

CREATE INDEX provider_event_mappings_tenant_call_event_idx
  ON public.provider_event_mappings (tenant_id, call_id, call_event_id, mapped_at DESC);
