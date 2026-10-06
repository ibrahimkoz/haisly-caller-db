CREATE TABLE public.artifacts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  owner_entity_type text NOT NULL,
  owner_entity_id bigint NOT NULL,
  artifact_type text NOT NULL,
  storage_provider text,
  storage_ref text NOT NULL,
  content_type text NOT NULL,
  byte_size bigint NOT NULL DEFAULT 0,
  checksum_sha256 text,
  retention_class text,
  privacy_classification text NOT NULL DEFAULT 'internal',
  status text NOT NULL DEFAULT 'available',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  redacted_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT artifacts_public_id_unique UNIQUE (public_id),
  CONSTRAINT artifacts_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT artifacts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT artifacts_owner_entity_type_not_blank_check CHECK (btrim(owner_entity_type) <> ''),
  CONSTRAINT artifacts_owner_entity_id_positive_check CHECK (owner_entity_id > 0),
  CONSTRAINT artifacts_artifact_type_not_blank_check CHECK (btrim(artifact_type) <> ''),
  CONSTRAINT artifacts_storage_provider_not_blank_check CHECK (
    storage_provider IS NULL OR btrim(storage_provider) <> ''
  ),
  CONSTRAINT artifacts_storage_ref_not_blank_check CHECK (btrim(storage_ref) <> ''),
  CONSTRAINT artifacts_content_type_not_blank_check CHECK (btrim(content_type) <> ''),
  CONSTRAINT artifacts_byte_size_non_negative_check CHECK (byte_size >= 0),
  CONSTRAINT artifacts_checksum_sha256_format_check CHECK (
    checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-f0-9]{64}$'
  ),
  CONSTRAINT artifacts_retention_class_not_blank_check CHECK (
    retention_class IS NULL OR btrim(retention_class) <> ''
  ),
  CONSTRAINT artifacts_privacy_classification_check CHECK (privacy_classification IN (
    'public',
    'internal',
    'restricted',
    'sensitive'
  )),
  CONSTRAINT artifacts_status_check CHECK (status IN (
    'available',
    'redaction_requested',
    'redacted',
    'deletion_requested',
    'deleted',
    'failed'
  )),
  CONSTRAINT artifacts_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT artifacts_deleted_after_created_check CHECK (
    deleted_at IS NULL OR deleted_at >= created_at
  )
);

CREATE INDEX artifacts_tenant_owner_entity_created_at_idx
  ON public.artifacts (tenant_id, owner_entity_type, owner_entity_id, created_at DESC);

CREATE INDEX artifacts_tenant_status_created_at_idx
  ON public.artifacts (tenant_id, status, created_at DESC);

CREATE TABLE public.artifact_access_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  artifact_id bigint NOT NULL,
  actor_user_id bigint,
  actor_type text NOT NULL DEFAULT 'tenant_user',
  action text NOT NULL,
  outcome text NOT NULL DEFAULT 'allowed',
  reason text,
  ip_address inet,
  user_agent text,
  request_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT artifact_access_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT artifact_access_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_access_events_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_access_events_actor_user_tenant_fk FOREIGN KEY (actor_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT artifact_access_events_actor_type_check CHECK (actor_type IN (
    'tenant_user',
    'platform_user',
    'service_account',
    'system'
  )),
  CONSTRAINT artifact_access_events_action_not_blank_check CHECK (btrim(action) <> ''),
  CONSTRAINT artifact_access_events_outcome_check CHECK (outcome IN (
    'allowed',
    'denied',
    'error'
  )),
  CONSTRAINT artifact_access_events_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT artifact_access_events_user_agent_not_blank_check CHECK (
    user_agent IS NULL OR btrim(user_agent) <> ''
  ),
  CONSTRAINT artifact_access_events_request_id_not_blank_check CHECK (
    request_id IS NULL OR btrim(request_id) <> ''
  ),
  CONSTRAINT artifact_access_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX artifact_access_events_artifact_occurred_at_idx
  ON public.artifact_access_events (artifact_id, occurred_at DESC);

CREATE INDEX artifact_access_events_tenant_action_occurred_at_idx
  ON public.artifact_access_events (tenant_id, action, occurred_at DESC);

CREATE TABLE public.artifact_redaction_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  artifact_id bigint NOT NULL,
  requested_by_user_id bigint,
  status text NOT NULL DEFAULT 'pending',
  reason text,
  error_message text,
  job_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  CONSTRAINT artifact_redaction_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT artifact_redaction_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_redaction_jobs_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_redaction_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT artifact_redaction_jobs_status_check CHECK (status IN (
    'pending',
    'in_progress',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT artifact_redaction_jobs_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT artifact_redaction_jobs_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT artifact_redaction_jobs_job_payload_object_check CHECK (jsonb_typeof(job_payload) = 'object'),
  CONSTRAINT artifact_redaction_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT artifact_redaction_jobs_started_after_requested_check CHECK (
    started_at IS NULL OR started_at >= requested_at
  ),
  CONSTRAINT artifact_redaction_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR completed_at >= COALESCE(started_at, requested_at)
  )
);

CREATE INDEX artifact_redaction_jobs_artifact_status_requested_at_idx
  ON public.artifact_redaction_jobs (artifact_id, status, requested_at DESC);

CREATE INDEX artifact_redaction_jobs_tenant_status_requested_at_idx
  ON public.artifact_redaction_jobs (tenant_id, status, requested_at DESC);

CREATE TABLE public.artifact_deletion_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  artifact_id bigint NOT NULL,
  requested_by_user_id bigint,
  status text NOT NULL DEFAULT 'pending',
  reason text,
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  CONSTRAINT artifact_deletion_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT artifact_deletion_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_deletion_jobs_artifact_tenant_fk FOREIGN KEY (artifact_id, tenant_id)
    REFERENCES public.artifacts (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT artifact_deletion_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT artifact_deletion_jobs_status_check CHECK (status IN (
    'pending',
    'in_progress',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT artifact_deletion_jobs_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT artifact_deletion_jobs_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT artifact_deletion_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT artifact_deletion_jobs_started_after_requested_check CHECK (
    started_at IS NULL OR started_at >= requested_at
  ),
  CONSTRAINT artifact_deletion_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR completed_at >= COALESCE(started_at, requested_at)
  )
);

CREATE INDEX artifact_deletion_jobs_artifact_status_requested_at_idx
  ON public.artifact_deletion_jobs (artifact_id, status, requested_at DESC);

CREATE INDEX artifact_deletion_jobs_tenant_status_requested_at_idx
  ON public.artifact_deletion_jobs (tenant_id, status, requested_at DESC);
