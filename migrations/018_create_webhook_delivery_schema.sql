CREATE TABLE public.webhook_subscriptions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  name text NOT NULL,
  endpoint_url text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  signing_secret_ref text,
  auth_mode text NOT NULL DEFAULT 'none',
  auth_header_name text,
  auth_secret_ref text,
  event_filters jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_delivery_at timestamptz,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT webhook_subscriptions_public_id_unique UNIQUE (public_id),
  CONSTRAINT webhook_subscriptions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT webhook_subscriptions_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    name
  ),
  CONSTRAINT webhook_subscriptions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT webhook_subscriptions_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT webhook_subscriptions_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT webhook_subscriptions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT webhook_subscriptions_endpoint_url_not_blank_check CHECK (btrim(endpoint_url) <> ''),
  CONSTRAINT webhook_subscriptions_endpoint_url_http_check CHECK (endpoint_url ~* '^https?://'),
  CONSTRAINT webhook_subscriptions_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT webhook_subscriptions_signing_secret_ref_not_blank_check CHECK (
    signing_secret_ref IS NULL OR btrim(signing_secret_ref) <> ''
  ),
  CONSTRAINT webhook_subscriptions_auth_mode_check CHECK (auth_mode IN (
    'none',
    'header_secret',
    'bearer_token'
  )),
  CONSTRAINT webhook_subscriptions_auth_header_name_not_blank_check CHECK (
    auth_header_name IS NULL OR btrim(auth_header_name) <> ''
  ),
  CONSTRAINT webhook_subscriptions_auth_secret_ref_not_blank_check CHECK (
    auth_secret_ref IS NULL OR btrim(auth_secret_ref) <> ''
  ),
  CONSTRAINT webhook_subscriptions_auth_config_pair_check CHECK (
    (auth_mode = 'none' AND auth_header_name IS NULL AND auth_secret_ref IS NULL)
    OR (auth_mode IN ('header_secret', 'bearer_token') AND auth_secret_ref IS NOT NULL)
  ),
  CONSTRAINT webhook_subscriptions_event_filters_array_check CHECK (jsonb_typeof(event_filters) = 'array'),
  CONSTRAINT webhook_subscriptions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX webhook_subscriptions_tenant_status_updated_at_idx
  ON public.webhook_subscriptions (tenant_id, status, updated_at DESC);

CREATE INDEX webhook_subscriptions_tenant_env_status_idx
  ON public.webhook_subscriptions (tenant_id, tenant_environment_id, status);

CREATE TABLE public.webhook_deliveries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  webhook_subscription_id bigint NOT NULL,
  outbox_event_id bigint,
  source text NOT NULL,
  event_type text NOT NULL,
  event_key text NOT NULL,
  delivery_status text NOT NULL DEFAULT 'pending',
  attempt_no integer NOT NULL DEFAULT 1,
  max_attempts integer NOT NULL DEFAULT 10,
  request_headers jsonb NOT NULL DEFAULT '{}'::jsonb,
  request_body jsonb NOT NULL DEFAULT '{}'::jsonb,
  response_status integer,
  response_headers jsonb,
  response_body jsonb,
  error_message text,
  next_attempt_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT webhook_deliveries_public_id_unique UNIQUE (public_id),
  CONSTRAINT webhook_deliveries_tenant_subscription_event_attempt_unique UNIQUE (
    tenant_id,
    webhook_subscription_id,
    event_key,
    attempt_no
  ),
  CONSTRAINT webhook_deliveries_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT webhook_deliveries_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT webhook_deliveries_subscription_tenant_fk FOREIGN KEY (webhook_subscription_id, tenant_id)
    REFERENCES public.webhook_subscriptions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT webhook_deliveries_outbox_event_tenant_fk FOREIGN KEY (outbox_event_id, tenant_id)
    REFERENCES public.outbox_events (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT webhook_deliveries_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT webhook_deliveries_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT webhook_deliveries_event_key_not_blank_check CHECK (btrim(event_key) <> ''),
  CONSTRAINT webhook_deliveries_delivery_status_check CHECK (delivery_status IN (
    'pending',
    'in_progress',
    'delivered',
    'failed',
    'dead_letter',
    'cancelled'
  )),
  CONSTRAINT webhook_deliveries_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT webhook_deliveries_max_attempts_positive_check CHECK (max_attempts > 0),
  CONSTRAINT webhook_deliveries_response_status_range_check CHECK (
    response_status IS NULL OR (response_status >= 100 AND response_status <= 599)
  ),
  CONSTRAINT webhook_deliveries_error_message_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT webhook_deliveries_request_headers_object_check CHECK (jsonb_typeof(request_headers) = 'object'),
  CONSTRAINT webhook_deliveries_request_body_shape_check CHECK (
    jsonb_typeof(request_body) IN ('object', 'array')
  ),
  CONSTRAINT webhook_deliveries_response_headers_object_check CHECK (
    response_headers IS NULL OR jsonb_typeof(response_headers) = 'object'
  ),
  CONSTRAINT webhook_deliveries_response_body_shape_check CHECK (
    response_body IS NULL OR jsonb_typeof(response_body) IN ('object', 'array')
  )
);

CREATE UNIQUE INDEX webhook_deliveries_tenant_subscription_event_latest_unique_idx
  ON public.webhook_deliveries (tenant_id, webhook_subscription_id, event_key)
  WHERE delivery_status IN ('pending', 'in_progress');

CREATE INDEX webhook_deliveries_tenant_status_next_attempt_idx
  ON public.webhook_deliveries (tenant_id, delivery_status, next_attempt_at ASC);

CREATE INDEX webhook_deliveries_subscription_status_created_at_idx
  ON public.webhook_deliveries (webhook_subscription_id, delivery_status, created_at DESC);
