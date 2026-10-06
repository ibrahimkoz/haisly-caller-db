CREATE TABLE public.customers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  customer_no text NOT NULL,
  display_name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  primary_email text,
  primary_phone text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT customers_public_id_unique UNIQUE (public_id),
  CONSTRAINT customers_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT customers_tenant_customer_no_unique UNIQUE (tenant_id, customer_no),
  CONSTRAINT customers_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT customers_customer_no_not_blank_check CHECK (btrim(customer_no) <> ''),
  CONSTRAINT customers_display_name_not_blank_check CHECK (btrim(display_name) <> ''),
  CONSTRAINT customers_status_check CHECK (status IN (
    'active',
    'inactive',
    'blocked'
  )),
  CONSTRAINT customers_primary_email_format_check CHECK (
    primary_email IS NULL
    OR (
      btrim(primary_email) <> ''
      AND primary_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    )
  ),
  CONSTRAINT customers_primary_phone_e164_check CHECK (
    primary_phone IS NULL
    OR (
      btrim(primary_phone) <> ''
      AND primary_phone ~ '^\+[1-9][0-9]{7,14}$'
    )
  ),
  CONSTRAINT customers_notes_not_blank_check CHECK (
    notes IS NULL OR btrim(notes) <> ''
  ),
  CONSTRAINT customers_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX customers_tenant_status_created_at_idx
  ON public.customers (tenant_id, status, created_at DESC);

CREATE INDEX customers_tenant_display_name_idx
  ON public.customers (tenant_id, display_name);

CREATE TABLE public.cases (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  case_no text NOT NULL,
  customer_id bigint,
  source_call_id bigint,
  assigned_user_id bigint,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'medium',
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  closed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cases_public_id_unique UNIQUE (public_id),
  CONSTRAINT cases_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT cases_tenant_case_no_unique UNIQUE (tenant_id, case_no),
  CONSTRAINT cases_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT cases_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT cases_source_call_tenant_fk FOREIGN KEY (source_call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT cases_assigned_user_tenant_fk FOREIGN KEY (assigned_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT cases_case_no_not_blank_check CHECK (btrim(case_no) <> ''),
  CONSTRAINT cases_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT cases_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT cases_status_check CHECK (status IN (
    'open',
    'in_progress',
    'resolved',
    'closed'
  )),
  CONSTRAINT cases_priority_check CHECK (priority IN (
    'low',
    'medium',
    'high',
    'urgent'
  )),
  CONSTRAINT cases_resolved_after_opened_check CHECK (
    resolved_at IS NULL OR resolved_at >= opened_at
  ),
  CONSTRAINT cases_closed_after_opened_check CHECK (
    closed_at IS NULL OR closed_at >= opened_at
  ),
  CONSTRAINT cases_closed_after_resolved_check CHECK (
    closed_at IS NULL OR resolved_at IS NULL OR closed_at >= resolved_at
  ),
  CONSTRAINT cases_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX cases_tenant_status_priority_opened_at_idx
  ON public.cases (tenant_id, status, priority, opened_at DESC);

CREATE INDEX cases_tenant_customer_opened_at_idx
  ON public.cases (tenant_id, customer_id, opened_at DESC)
  WHERE customer_id IS NOT NULL;

CREATE INDEX cases_tenant_assigned_user_opened_at_idx
  ON public.cases (tenant_id, assigned_user_id, opened_at DESC)
  WHERE assigned_user_id IS NOT NULL;

CREATE TABLE public.customer_contacts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  contact_type text NOT NULL,
  contact_value text NOT NULL,
  normalized_value text NOT NULL,
  label text,
  is_primary boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT customer_contacts_public_id_unique UNIQUE (public_id),
  CONSTRAINT customer_contacts_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT customer_contacts_customer_contact_unique UNIQUE (
    customer_id,
    contact_type,
    normalized_value
  ),
  CONSTRAINT customer_contacts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT customer_contacts_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT customer_contacts_type_check CHECK (contact_type IN (
    'email',
    'phone',
    'other'
  )),
  CONSTRAINT customer_contacts_contact_value_not_blank_check CHECK (btrim(contact_value) <> ''),
  CONSTRAINT customer_contacts_normalized_not_blank_check CHECK (btrim(normalized_value) <> ''),
  CONSTRAINT customer_contacts_label_not_blank_check CHECK (
    label IS NULL OR btrim(label) <> ''
  ),
  CONSTRAINT customer_contacts_verified_primary_check CHECK (
    verified_at IS NOT NULL OR is_primary = false
  ),
  CONSTRAINT customer_contacts_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX customer_contacts_primary_per_type_unique_idx
  ON public.customer_contacts (customer_id, contact_type)
  WHERE is_primary;

CREATE INDEX customer_contacts_customer_verified_idx
  ON public.customer_contacts (customer_id, contact_type, verified_at DESC);

CREATE TABLE public.customer_interactions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  call_id bigint,
  case_id bigint,
  interaction_type text NOT NULL,
  channel text,
  summary text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT customer_interactions_public_id_unique UNIQUE (public_id),
  CONSTRAINT customer_interactions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT customer_interactions_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT customer_interactions_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT customer_interactions_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT customer_interactions_type_not_blank_check CHECK (btrim(interaction_type) <> ''),
  CONSTRAINT customer_interactions_channel_not_blank_check CHECK (
    channel IS NULL OR btrim(channel) <> ''
  ),
  CONSTRAINT customer_interactions_summary_not_blank_check CHECK (btrim(summary) <> ''),
  CONSTRAINT customer_interactions_links_check CHECK (
    call_id IS NOT NULL OR case_id IS NOT NULL OR interaction_type IN (
      'note',
      'system'
    )
  ),
  CONSTRAINT customer_interactions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX customer_interactions_customer_occurred_at_idx
  ON public.customer_interactions (customer_id, occurred_at DESC);

CREATE INDEX customer_interactions_case_occurred_at_idx
  ON public.customer_interactions (case_id, occurred_at DESC)
  WHERE case_id IS NOT NULL;

CREATE INDEX customer_interactions_call_occurred_at_idx
  ON public.customer_interactions (call_id, occurred_at DESC)
  WHERE call_id IS NOT NULL;

CREATE TABLE public.case_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  case_id bigint NOT NULL,
  actor_user_id bigint,
  event_type text NOT NULL,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT case_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT case_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT case_events_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT case_events_actor_user_tenant_fk FOREIGN KEY (actor_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT case_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT case_events_note_not_blank_check CHECK (
    note IS NULL OR btrim(note) <> ''
  ),
  CONSTRAINT case_events_event_payload_object_check CHECK (
    jsonb_typeof(event_payload) = 'object'
  )
);

CREATE INDEX case_events_case_occurred_at_idx
  ON public.case_events (case_id, occurred_at ASC);

CREATE INDEX case_events_tenant_event_type_occurred_at_idx
  ON public.case_events (tenant_id, event_type, occurred_at DESC);
