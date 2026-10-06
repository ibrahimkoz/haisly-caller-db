CREATE TABLE public.hotelrunner_reservation_outbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  reservation_xml text NOT NULL,
  push_url text,
  provider_response text,
  provider_status integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hotelrunner_reservation_outbox_public_id_unique UNIQUE (public_id),
  CONSTRAINT hotelrunner_reservation_outbox_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT hotelrunner_reservation_outbox_integration_tenant_fk FOREIGN KEY (
    integration_id,
    tenant_id
  )
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT hotelrunner_reservation_outbox_status_check CHECK (status IN (
    'pending',
    'pushed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT hotelrunner_reservation_outbox_xml_not_blank_check CHECK (
    btrim(reservation_xml) <> ''
  ),
  CONSTRAINT hotelrunner_reservation_outbox_push_url_not_blank_check CHECK (
    push_url IS NULL OR btrim(push_url) <> ''
  ),
  CONSTRAINT hotelrunner_reservation_outbox_provider_status_check CHECK (
    provider_status IS NULL OR provider_status BETWEEN 100 AND 599
  ),
  CONSTRAINT hotelrunner_reservation_outbox_metadata_object_check CHECK (
    jsonb_typeof(metadata) = 'object'
  )
);

CREATE INDEX hotelrunner_reservation_outbox_tenant_status_created_idx
  ON public.hotelrunner_reservation_outbox (tenant_id, status, created_at DESC);

CREATE INDEX hotelrunner_reservation_outbox_integration_created_idx
  ON public.hotelrunner_reservation_outbox (tenant_id, integration_id, created_at DESC);
