CREATE TABLE public.leads (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  lead_no text NOT NULL,
  title text NOT NULL,
  summary text,
  status text NOT NULL DEFAULT 'new',
  source text,
  score integer,
  owner_user_id bigint,
  customer_id bigint,
  source_call_id bigint,
  source_case_id bigint,
  converted_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT leads_public_id_unique UNIQUE (public_id),
  CONSTRAINT leads_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT leads_tenant_lead_no_unique UNIQUE (tenant_id, lead_no),
  CONSTRAINT leads_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT leads_owner_user_tenant_fk FOREIGN KEY (owner_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT leads_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT leads_source_call_tenant_fk FOREIGN KEY (source_call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT leads_source_case_tenant_fk FOREIGN KEY (source_case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT leads_lead_no_not_blank_check CHECK (btrim(lead_no) <> ''),
  CONSTRAINT leads_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT leads_summary_not_blank_check CHECK (
    summary IS NULL OR btrim(summary) <> ''
  ),
  CONSTRAINT leads_status_check CHECK (status IN (
    'new',
    'qualified',
    'disqualified',
    'converted',
    'lost'
  )),
  CONSTRAINT leads_source_not_blank_check CHECK (
    source IS NULL OR btrim(source) <> ''
  ),
  CONSTRAINT leads_score_range_check CHECK (
    score IS NULL OR (score >= 0 AND score <= 100)
  ),
  CONSTRAINT leads_converted_at_status_check CHECK (
    (status = 'converted' AND converted_at IS NOT NULL)
    OR (status <> 'converted')
  ),
  CONSTRAINT leads_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX leads_tenant_status_owner_created_at_idx
  ON public.leads (tenant_id, status, owner_user_id, created_at DESC);

CREATE INDEX leads_tenant_customer_created_at_idx
  ON public.leads (tenant_id, customer_id, created_at DESC)
  WHERE customer_id IS NOT NULL;

CREATE TABLE public.lead_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  lead_id bigint NOT NULL,
  actor_user_id bigint,
  event_type text NOT NULL,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lead_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT lead_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT lead_events_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT lead_events_actor_user_tenant_fk FOREIGN KEY (actor_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT lead_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT lead_events_note_not_blank_check CHECK (
    note IS NULL OR btrim(note) <> ''
  ),
  CONSTRAINT lead_events_event_payload_object_check CHECK (
    jsonb_typeof(event_payload) = 'object'
  )
);

CREATE INDEX lead_events_lead_occurred_at_idx
  ON public.lead_events (lead_id, occurred_at ASC);

CREATE INDEX lead_events_tenant_event_type_occurred_at_idx
  ON public.lead_events (tenant_id, event_type, occurred_at DESC);

CREATE TABLE public.follow_up_tasks (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'pending',
  priority text NOT NULL DEFAULT 'medium',
  due_at timestamptz,
  snoozed_until timestamptz,
  completed_at timestamptz,
  assigned_user_id bigint,
  call_id bigint,
  case_id bigint,
  customer_id bigint,
  lead_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT follow_up_tasks_public_id_unique UNIQUE (public_id),
  CONSTRAINT follow_up_tasks_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT follow_up_tasks_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT follow_up_tasks_assigned_user_tenant_fk FOREIGN KEY (assigned_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT follow_up_tasks_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT follow_up_tasks_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT follow_up_tasks_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT follow_up_tasks_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT follow_up_tasks_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT follow_up_tasks_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT follow_up_tasks_status_check CHECK (status IN (
    'pending',
    'in_progress',
    'snoozed',
    'completed',
    'cancelled'
  )),
  CONSTRAINT follow_up_tasks_priority_check CHECK (priority IN (
    'low',
    'medium',
    'high',
    'urgent'
  )),
  CONSTRAINT follow_up_tasks_completed_status_check CHECK (
    (status = 'completed' AND completed_at IS NOT NULL)
    OR (status <> 'completed')
  ),
  CONSTRAINT follow_up_tasks_snoozed_status_check CHECK (
    (status = 'snoozed' AND snoozed_until IS NOT NULL)
    OR (status <> 'snoozed')
  ),
  CONSTRAINT follow_up_tasks_snoozed_after_due_check CHECK (
    due_at IS NULL OR snoozed_until IS NULL OR snoozed_until >= due_at
  ),
  CONSTRAINT follow_up_tasks_link_required_check CHECK (
    call_id IS NOT NULL
    OR case_id IS NOT NULL
    OR customer_id IS NOT NULL
    OR lead_id IS NOT NULL
  ),
  CONSTRAINT follow_up_tasks_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX follow_up_tasks_tenant_status_due_at_idx
  ON public.follow_up_tasks (tenant_id, status, due_at ASC);

CREATE INDEX follow_up_tasks_tenant_assigned_status_due_at_idx
  ON public.follow_up_tasks (tenant_id, assigned_user_id, status, due_at ASC)
  WHERE assigned_user_id IS NOT NULL;
