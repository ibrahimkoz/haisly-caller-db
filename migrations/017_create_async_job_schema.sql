CREATE TABLE public.outbox_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  topic text NOT NULL,
  event_key text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  headers jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending',
  attempt_count integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 10,
  available_at timestamptz NOT NULL DEFAULT now(),
  locked_at timestamptz,
  processed_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT outbox_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT outbox_events_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT outbox_events_tenant_topic_key_unique UNIQUE (tenant_id, topic, event_key),
  CONSTRAINT outbox_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT outbox_events_topic_not_blank_check CHECK (btrim(topic) <> ''),
  CONSTRAINT outbox_events_event_key_not_blank_check CHECK (btrim(event_key) <> ''),
  CONSTRAINT outbox_events_status_check CHECK (status IN (
    'pending',
    'processing',
    'processed',
    'failed',
    'dead_letter'
  )),
  CONSTRAINT outbox_events_attempt_non_negative_check CHECK (attempt_count >= 0),
  CONSTRAINT outbox_events_max_attempts_positive_check CHECK (max_attempts > 0),
  CONSTRAINT outbox_events_last_error_not_blank_check CHECK (
    last_error IS NULL OR btrim(last_error) <> ''
  ),
  CONSTRAINT outbox_events_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT outbox_events_headers_object_check CHECK (jsonb_typeof(headers) = 'object')
);

CREATE INDEX outbox_events_tenant_status_available_at_idx
  ON public.outbox_events (tenant_id, status, available_at ASC);

CREATE INDEX outbox_events_status_available_at_idx
  ON public.outbox_events (status, available_at ASC);

CREATE TABLE public.inbox_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  source text NOT NULL,
  source_event_id text NOT NULL,
  topic text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  headers jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'received',
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inbox_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT inbox_events_tenant_source_event_unique UNIQUE (tenant_id, source, source_event_id),
  CONSTRAINT inbox_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT inbox_events_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT inbox_events_source_event_id_not_blank_check CHECK (btrim(source_event_id) <> ''),
  CONSTRAINT inbox_events_topic_not_blank_check CHECK (btrim(topic) <> ''),
  CONSTRAINT inbox_events_status_check CHECK (status IN (
    'received',
    'processed',
    'ignored',
    'failed'
  )),
  CONSTRAINT inbox_events_error_message_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT inbox_events_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT inbox_events_headers_object_check CHECK (jsonb_typeof(headers) = 'object')
);

CREATE INDEX inbox_events_tenant_status_received_at_idx
  ON public.inbox_events (tenant_id, status, received_at DESC);

CREATE INDEX inbox_events_source_topic_received_at_idx
  ON public.inbox_events (source, topic, received_at DESC);

CREATE TABLE public.background_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  queue_name text NOT NULL,
  job_type text NOT NULL,
  dedupe_key text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued',
  priority integer NOT NULL DEFAULT 100,
  max_attempts integer NOT NULL DEFAULT 10,
  available_at timestamptz NOT NULL DEFAULT now(),
  scheduled_for timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  last_error text,
  created_by_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT background_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT background_jobs_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT background_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT background_jobs_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT background_jobs_queue_name_not_blank_check CHECK (btrim(queue_name) <> ''),
  CONSTRAINT background_jobs_job_type_not_blank_check CHECK (btrim(job_type) <> ''),
  CONSTRAINT background_jobs_dedupe_key_not_blank_check CHECK (
    dedupe_key IS NULL OR btrim(dedupe_key) <> ''
  ),
  CONSTRAINT background_jobs_status_check CHECK (status IN (
    'queued',
    'running',
    'succeeded',
    'failed',
    'cancelled',
    'dead_letter'
  )),
  CONSTRAINT background_jobs_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT background_jobs_max_attempts_positive_check CHECK (max_attempts > 0),
  CONSTRAINT background_jobs_last_error_not_blank_check CHECK (
    last_error IS NULL OR btrim(last_error) <> ''
  ),
  CONSTRAINT background_jobs_payload_object_check CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT background_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT background_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  )
);

CREATE UNIQUE INDEX background_jobs_tenant_queue_dedupe_unique_idx
  ON public.background_jobs (tenant_id, queue_name, dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE INDEX background_jobs_tenant_status_available_at_idx
  ON public.background_jobs (tenant_id, status, available_at ASC);

CREATE INDEX background_jobs_queue_status_priority_idx
  ON public.background_jobs (queue_name, status, priority ASC, available_at ASC);

CREATE TABLE public.job_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  background_job_id bigint NOT NULL,
  attempt_no integer NOT NULL,
  status text NOT NULL DEFAULT 'running',
  worker_id text,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  error_message text,
  output_payload jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT job_attempts_public_id_unique UNIQUE (public_id),
  CONSTRAINT job_attempts_job_attempt_unique UNIQUE (background_job_id, attempt_no),
  CONSTRAINT job_attempts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT job_attempts_background_job_tenant_fk FOREIGN KEY (background_job_id, tenant_id)
    REFERENCES public.background_jobs (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT job_attempts_attempt_positive_check CHECK (attempt_no > 0),
  CONSTRAINT job_attempts_status_check CHECK (status IN (
    'running',
    'succeeded',
    'failed',
    'cancelled'
  )),
  CONSTRAINT job_attempts_worker_id_not_blank_check CHECK (
    worker_id IS NULL OR btrim(worker_id) <> ''
  ),
  CONSTRAINT job_attempts_error_message_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT job_attempts_output_payload_shape_check CHECK (
    output_payload IS NULL OR jsonb_typeof(output_payload) IN ('object', 'array')
  ),
  CONSTRAINT job_attempts_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT job_attempts_completed_after_started_check CHECK (
    completed_at IS NULL OR completed_at >= started_at
  )
);

CREATE INDEX job_attempts_job_status_started_at_idx
  ON public.job_attempts (background_job_id, status, started_at DESC);

CREATE INDEX job_attempts_tenant_status_started_at_idx
  ON public.job_attempts (tenant_id, status, started_at DESC);
