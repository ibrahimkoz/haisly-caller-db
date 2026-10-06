CREATE TABLE public.bookable_resources (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  resource_type text NOT NULL DEFAULT 'room',
  provider_resource_id text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bookable_resources_public_id_unique UNIQUE (public_id),
  CONSTRAINT bookable_resources_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT bookable_resources_integration_tenant_fk FOREIGN KEY (integration_id, tenant_id)
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT bookable_resources_provider_unique UNIQUE (
    tenant_id,
    integration_id,
    provider_resource_id
  ),
  CONSTRAINT bookable_resources_type_not_blank_check CHECK (btrim(resource_type) <> ''),
  CONSTRAINT bookable_resources_provider_id_not_blank_check CHECK (btrim(provider_resource_id) <> ''),
  CONSTRAINT bookable_resources_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT bookable_resources_status_check CHECK (status IN ('active', 'inactive')),
  CONSTRAINT bookable_resources_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT bookable_resources_payload_object_check CHECK (jsonb_typeof(provider_payload) = 'object')
);

CREATE INDEX bookable_resources_tenant_integration_status_idx
  ON public.bookable_resources (tenant_id, integration_id, status, updated_at DESC);

CREATE TABLE public.resource_offers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  resource_id bigint NOT NULL,
  offer_type text NOT NULL DEFAULT 'rate_plan',
  provider_offer_id text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT resource_offers_public_id_unique UNIQUE (public_id),
  CONSTRAINT resource_offers_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT resource_offers_integration_tenant_fk FOREIGN KEY (integration_id, tenant_id)
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT resource_offers_resource_fk FOREIGN KEY (resource_id)
    REFERENCES public.bookable_resources (id)
    ON DELETE CASCADE,
  CONSTRAINT resource_offers_provider_unique UNIQUE (
    tenant_id,
    integration_id,
    provider_offer_id
  ),
  CONSTRAINT resource_offers_type_not_blank_check CHECK (btrim(offer_type) <> ''),
  CONSTRAINT resource_offers_provider_id_not_blank_check CHECK (btrim(provider_offer_id) <> ''),
  CONSTRAINT resource_offers_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT resource_offers_status_check CHECK (status IN ('active', 'inactive')),
  CONSTRAINT resource_offers_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT resource_offers_payload_object_check CHECK (jsonb_typeof(provider_payload) = 'object')
);

CREATE INDEX resource_offers_tenant_resource_status_idx
  ON public.resource_offers (tenant_id, resource_id, status, updated_at DESC);

CREATE TABLE public.resource_availability (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  resource_id bigint NOT NULL,
  offer_id bigint NOT NULL,
  availability_date date NOT NULL,
  price_amount numeric(14, 2) NOT NULL,
  price_currency char(3) NOT NULL,
  allocation integer NOT NULL,
  stop_sale boolean NOT NULL,
  min_stay integer NOT NULL,
  cta boolean NOT NULL,
  ctd boolean NOT NULL,
  release_hour integer NOT NULL,
  source text NOT NULL DEFAULT 'provider_push',
  provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_synced_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT resource_availability_public_id_unique UNIQUE (public_id),
  CONSTRAINT resource_availability_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT resource_availability_integration_tenant_fk FOREIGN KEY (integration_id, tenant_id)
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT resource_availability_resource_fk FOREIGN KEY (resource_id)
    REFERENCES public.bookable_resources (id)
    ON DELETE CASCADE,
  CONSTRAINT resource_availability_offer_fk FOREIGN KEY (offer_id)
    REFERENCES public.resource_offers (id)
    ON DELETE CASCADE,
  CONSTRAINT resource_availability_offer_date_unique UNIQUE (
    tenant_id,
    integration_id,
    offer_id,
    availability_date
  ),
  CONSTRAINT resource_availability_price_non_negative_check CHECK (price_amount >= 0),
  CONSTRAINT resource_availability_currency_upper_check CHECK (price_currency ~ '^[A-Z]{3}$'),
  CONSTRAINT resource_availability_allocation_non_negative_check CHECK (allocation >= 0),
  CONSTRAINT resource_availability_min_stay_check CHECK (min_stay BETWEEN 1 AND 31),
  CONSTRAINT resource_availability_release_hour_check CHECK (release_hour BETWEEN 0 AND 1080),
  CONSTRAINT resource_availability_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT resource_availability_payload_object_check CHECK (jsonb_typeof(provider_payload) = 'object')
);

CREATE INDEX resource_availability_tenant_date_idx
  ON public.resource_availability (tenant_id, availability_date, stop_sale, allocation);

CREATE INDEX resource_availability_offer_date_idx
  ON public.resource_availability (tenant_id, integration_id, offer_id, availability_date);
