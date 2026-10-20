-- Schema-only rollback. Restore the pre-cleanup dump to recover removed rows.
-- Integration credentials/automations remain disabled deliberately.
\ir ../migrations/051_create_booking_availability_cache.sql
\ir ../migrations/052_create_hotelrunner_reservation_outbox.sql
-- The ai_call_sessions unique constraint is retained by migration 071.
ALTER TABLE public.hotelrunner_reservation_outbox
  ADD CONSTRAINT hotelrunner_reservation_outbox_id_tenant_id_unique UNIQUE (id, tenant_id);

CREATE TABLE public.booking_reservation_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  hotelrunner_reservation_outbox_id bigint,
  ai_call_session_id bigint,
  call_id bigint,
  customer_id bigint,
  provider text NOT NULL DEFAULT 'hotelrunner',
  provider_reservation_ref text,
  status text NOT NULL DEFAULT 'pending',
  room_id text NOT NULL,
  room_name text NOT NULL,
  rate_id text,
  rate_name text,
  check_in date NOT NULL,
  check_out date NOT NULL,
  nights integer NOT NULL,
  adults integer NOT NULL DEFAULT 1,
  children integer NOT NULL DEFAULT 0,
  child_ages jsonb NOT NULL DEFAULT '[]'::jsonb,
  guest_first_name text NOT NULL,
  guest_last_name text NOT NULL,
  guest_email text,
  guest_phone text,
  total_amount numeric(12, 2),
  currency char(3),
  notes text,
  request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT booking_reservation_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT booking_reservation_requests_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT booking_reservation_requests_tenant_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT booking_reservation_requests_integration_tenant_fk FOREIGN KEY (
    integration_id,
    tenant_id
  )
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT booking_reservation_requests_outbox_tenant_fk FOREIGN KEY (
    hotelrunner_reservation_outbox_id,
    tenant_id
  )
    REFERENCES public.hotelrunner_reservation_outbox (id, tenant_id)
    ON DELETE SET NULL (hotelrunner_reservation_outbox_id),
  CONSTRAINT booking_reservation_requests_ai_call_session_tenant_fk FOREIGN KEY (
    ai_call_session_id,
    tenant_id
  )
    REFERENCES public.ai_call_sessions (id, tenant_id)
    ON DELETE SET NULL (ai_call_session_id),
  CONSTRAINT booking_reservation_requests_call_tenant_fk FOREIGN KEY (
    call_id,
    tenant_id
  )
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL (call_id),
  CONSTRAINT booking_reservation_requests_customer_tenant_fk FOREIGN KEY (
    customer_id,
    tenant_id
  )
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL (customer_id),
  CONSTRAINT booking_reservation_requests_provider_check CHECK (provider IN (
    'hotelrunner'
  )),
  CONSTRAINT booking_reservation_requests_status_check CHECK (status IN (
    'pending',
    'submitted',
    'confirmed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT booking_reservation_requests_dates_check CHECK (check_out > check_in),
  CONSTRAINT booking_reservation_requests_nights_check CHECK (nights > 0),
  CONSTRAINT booking_reservation_requests_adults_check CHECK (adults BETWEEN 1 AND 20),
  CONSTRAINT booking_reservation_requests_children_check CHECK (children BETWEEN 0 AND 20),
  CONSTRAINT booking_reservation_requests_total_amount_check CHECK (
    total_amount IS NULL OR total_amount >= 0
  ),
  CONSTRAINT booking_reservation_requests_currency_check CHECK (
    currency IS NULL OR currency ~ '^[A-Z]{3}$'
  ),
  CONSTRAINT booking_reservation_requests_provider_ref_not_blank_check CHECK (
    provider_reservation_ref IS NULL OR btrim(provider_reservation_ref) <> ''
  ),
  CONSTRAINT booking_reservation_requests_room_id_not_blank_check CHECK (btrim(room_id) <> ''),
  CONSTRAINT booking_reservation_requests_room_name_not_blank_check CHECK (btrim(room_name) <> ''),
  CONSTRAINT booking_reservation_requests_rate_id_not_blank_check CHECK (
    rate_id IS NULL OR btrim(rate_id) <> ''
  ),
  CONSTRAINT booking_reservation_requests_rate_name_not_blank_check CHECK (
    rate_name IS NULL OR btrim(rate_name) <> ''
  ),
  CONSTRAINT booking_reservation_requests_guest_first_name_not_blank_check CHECK (
    btrim(guest_first_name) <> ''
  ),
  CONSTRAINT booking_reservation_requests_guest_last_name_not_blank_check CHECK (
    btrim(guest_last_name) <> ''
  ),
  CONSTRAINT booking_reservation_requests_child_ages_array_check CHECK (
    jsonb_typeof(child_ages) = 'array'
  ),
  CONSTRAINT booking_reservation_requests_request_payload_object_check CHECK (
    jsonb_typeof(request_payload) = 'object'
  ),
  CONSTRAINT booking_reservation_requests_provider_payload_object_check CHECK (
    jsonb_typeof(provider_payload) = 'object'
  ),
  CONSTRAINT booking_reservation_requests_metadata_object_check CHECK (
    jsonb_typeof(metadata) = 'object'
  )
);

CREATE INDEX booking_reservation_requests_tenant_created_idx
  ON public.booking_reservation_requests (tenant_id, created_at DESC);

CREATE INDEX booking_reservation_requests_tenant_status_created_idx
  ON public.booking_reservation_requests (tenant_id, status, created_at DESC);

CREATE INDEX booking_reservation_requests_customer_created_idx
  ON public.booking_reservation_requests (tenant_id, customer_id, created_at DESC)
  WHERE customer_id IS NOT NULL;

CREATE INDEX booking_reservation_requests_call_created_idx
  ON public.booking_reservation_requests (tenant_id, call_id, created_at DESC)
  WHERE call_id IS NOT NULL;

CREATE UNIQUE INDEX booking_reservation_requests_outbox_unique_idx
  ON public.booking_reservation_requests (hotelrunner_reservation_outbox_id)
  WHERE hotelrunner_reservation_outbox_id IS NOT NULL;

