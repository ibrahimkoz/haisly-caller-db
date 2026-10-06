CREATE TABLE public.handoff_queues (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT handoff_queues_public_id_unique UNIQUE (public_id),
  CONSTRAINT handoff_queues_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT handoff_queues_tenant_env_code_unique UNIQUE (tenant_id, tenant_environment_id, code),
  CONSTRAINT handoff_queues_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_queues_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_queues_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT handoff_queues_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT handoff_queues_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT handoff_queues_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT handoff_queues_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT handoff_queues_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX handoff_queues_tenant_env_status_priority_idx
  ON public.handoff_queues (tenant_id, tenant_environment_id, status, priority ASC);

CREATE TABLE public.human_agent_presence (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  user_id bigint NOT NULL,
  handoff_queue_id bigint,
  presence_status text NOT NULL DEFAULT 'offline',
  capacity integer NOT NULL DEFAULT 1,
  current_load integer NOT NULL DEFAULT 0,
  last_seen_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT human_agent_presence_public_id_unique UNIQUE (public_id),
  CONSTRAINT human_agent_presence_tenant_env_user_unique UNIQUE (tenant_id, tenant_environment_id, user_id),
  CONSTRAINT human_agent_presence_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT human_agent_presence_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT human_agent_presence_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT human_agent_presence_queue_tenant_fk FOREIGN KEY (handoff_queue_id, tenant_id)
    REFERENCES public.handoff_queues (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT human_agent_presence_status_check CHECK (presence_status IN (
    'online',
    'busy',
    'away',
    'offline'
  )),
  CONSTRAINT human_agent_presence_capacity_positive_check CHECK (capacity > 0),
  CONSTRAINT human_agent_presence_current_load_non_negative_check CHECK (current_load >= 0),
  CONSTRAINT human_agent_presence_load_within_capacity_check CHECK (current_load <= capacity),
  CONSTRAINT human_agent_presence_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX human_agent_presence_tenant_env_status_seen_idx
  ON public.human_agent_presence (tenant_id, tenant_environment_id, presence_status, last_seen_at DESC);

CREATE TABLE public.handoff_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  call_id bigint,
  call_session_id bigint,
  case_id bigint,
  lead_id bigint,
  customer_id bigint,
  handoff_queue_id bigint,
  assigned_user_id bigint,
  requested_by_user_id bigint,
  requested_by_service_account_id bigint,
  reason text NOT NULL,
  priority text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'requested',
  requested_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT handoff_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT handoff_requests_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT handoff_requests_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_requests_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_requests_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_call_session_tenant_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_case_tenant_fk FOREIGN KEY (case_id, tenant_id)
    REFERENCES public.cases (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_lead_tenant_fk FOREIGN KEY (lead_id, tenant_id)
    REFERENCES public.leads (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_queue_tenant_fk FOREIGN KEY (handoff_queue_id, tenant_id)
    REFERENCES public.handoff_queues (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_assigned_user_tenant_fk FOREIGN KEY (assigned_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_requested_by_service_tenant_fk FOREIGN KEY (requested_by_service_account_id, tenant_id)
    REFERENCES public.service_accounts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_requests_reason_not_blank_check CHECK (btrim(reason) <> ''),
  CONSTRAINT handoff_requests_priority_check CHECK (priority IN (
    'low',
    'medium',
    'high',
    'urgent'
  )),
  CONSTRAINT handoff_requests_status_check CHECK (status IN (
    'requested',
    'assigned',
    'accepted',
    'completed',
    'failed',
    'missed',
    'cancelled'
  )),
  CONSTRAINT handoff_requests_actor_required_check CHECK (
    requested_by_user_id IS NOT NULL OR requested_by_service_account_id IS NOT NULL
  ),
  CONSTRAINT handoff_requests_accepted_after_requested_check CHECK (
    accepted_at IS NULL OR accepted_at >= requested_at
  ),
  CONSTRAINT handoff_requests_completed_after_accepted_check CHECK (
    completed_at IS NULL OR completed_at >= COALESCE(accepted_at, requested_at)
  ),
  CONSTRAINT handoff_requests_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX handoff_requests_tenant_status_requested_at_idx
  ON public.handoff_requests (tenant_id, status, requested_at DESC);

CREATE INDEX handoff_requests_queue_status_priority_idx
  ON public.handoff_requests (handoff_queue_id, status, priority, requested_at ASC)
  WHERE handoff_queue_id IS NOT NULL;

CREATE TABLE public.handoff_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  handoff_request_id bigint NOT NULL,
  actor_user_id bigint,
  actor_service_account_id bigint,
  event_type text NOT NULL,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT handoff_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT handoff_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_events_request_tenant_fk FOREIGN KEY (handoff_request_id, tenant_id)
    REFERENCES public.handoff_requests (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT handoff_events_actor_user_tenant_fk FOREIGN KEY (actor_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_events_actor_service_tenant_fk FOREIGN KEY (actor_service_account_id, tenant_id)
    REFERENCES public.service_accounts (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT handoff_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT handoff_events_actor_required_check CHECK (
    actor_user_id IS NOT NULL OR actor_service_account_id IS NOT NULL
  ),
  CONSTRAINT handoff_events_event_payload_object_check CHECK (jsonb_typeof(event_payload) = 'object'),
  CONSTRAINT handoff_events_note_not_blank_check CHECK (
    note IS NULL OR btrim(note) <> ''
  )
);

CREATE INDEX handoff_events_request_occurred_at_idx
  ON public.handoff_events (handoff_request_id, occurred_at ASC);

CREATE INDEX handoff_events_tenant_event_type_occurred_idx
  ON public.handoff_events (tenant_id, event_type, occurred_at DESC);
