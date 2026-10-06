CREATE TABLE public.retention_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  policy_name text NOT NULL,
  scope_type text NOT NULL,
  retention_days integer NOT NULL,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT retention_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT retention_policies_tenant_scope_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    scope_type,
    policy_name
  ),
  CONSTRAINT retention_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT retention_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT retention_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT retention_policies_name_not_blank_check CHECK (btrim(policy_name) <> ''),
  CONSTRAINT retention_policies_scope_type_check CHECK (scope_type IN (
    'call_recording',
    'transcript',
    'artifact',
    'audit_log',
    'export_file'
  )),
  CONSTRAINT retention_policies_days_positive_check CHECK (retention_days > 0),
  CONSTRAINT retention_policies_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT retention_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX retention_policies_tenant_status_updated_at_idx
  ON public.retention_policies (tenant_id, status, updated_at DESC);

CREATE TABLE public.consent_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  policy_name text NOT NULL,
  channel text NOT NULL,
  language text,
  version_no integer NOT NULL,
  disclosure_text text NOT NULL,
  rules_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft',
  effective_at timestamptz,
  retired_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT consent_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT consent_policies_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT consent_policies_tenant_env_name_version_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    policy_name,
    version_no
  ),
  CONSTRAINT consent_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT consent_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT consent_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT consent_policies_name_not_blank_check CHECK (btrim(policy_name) <> ''),
  CONSTRAINT consent_policies_channel_check CHECK (channel IN (
    'voice',
    'sms',
    'email',
    'chat'
  )),
  CONSTRAINT consent_policies_language_not_blank_check CHECK (
    language IS NULL OR btrim(language) <> ''
  ),
  CONSTRAINT consent_policies_version_positive_check CHECK (version_no > 0),
  CONSTRAINT consent_policies_disclosure_not_blank_check CHECK (btrim(disclosure_text) <> ''),
  CONSTRAINT consent_policies_status_check CHECK (status IN (
    'draft',
    'active',
    'retired'
  )),
  CONSTRAINT consent_policies_rules_object_check CHECK (jsonb_typeof(rules_config) = 'object'),
  CONSTRAINT consent_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT consent_policies_retired_requires_status_check CHECK (
    retired_at IS NULL OR status = 'retired'
  )
);

CREATE INDEX consent_policies_tenant_env_status_effective_idx
  ON public.consent_policies (tenant_id, tenant_environment_id, status, effective_at DESC);

CREATE TABLE public.consent_records (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  consent_policy_id bigint,
  call_id bigint,
  call_session_id bigint,
  customer_id bigint,
  channel text NOT NULL,
  consent_result text NOT NULL,
  reason text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  evidence_ref text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT consent_records_public_id_unique UNIQUE (public_id),
  CONSTRAINT consent_records_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT consent_records_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT consent_records_policy_tenant_fk FOREIGN KEY (consent_policy_id, tenant_id)
    REFERENCES public.consent_policies (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT consent_records_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT consent_records_call_session_tenant_fk FOREIGN KEY (call_session_id, tenant_id)
    REFERENCES public.call_sessions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT consent_records_customer_tenant_fk FOREIGN KEY (customer_id, tenant_id)
    REFERENCES public.customers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT consent_records_channel_check CHECK (channel IN (
    'voice',
    'sms',
    'email',
    'chat'
  )),
  CONSTRAINT consent_records_result_check CHECK (consent_result IN (
    'granted',
    'denied',
    'revoked',
    'unknown'
  )),
  CONSTRAINT consent_records_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT consent_records_evidence_ref_not_blank_check CHECK (
    evidence_ref IS NULL OR btrim(evidence_ref) <> ''
  ),
  CONSTRAINT consent_records_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX consent_records_tenant_call_captured_at_idx
  ON public.consent_records (tenant_id, call_id, captured_at DESC)
  WHERE call_id IS NOT NULL;

CREATE INDEX consent_records_tenant_result_captured_at_idx
  ON public.consent_records (tenant_id, consent_result, captured_at DESC);

CREATE TABLE public.data_export_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  requested_by_user_id bigint NOT NULL,
  request_scope text NOT NULL,
  target_entity_type text,
  target_entity_public_id uuid,
  status text NOT NULL DEFAULT 'requested',
  export_ref text,
  error_message text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT data_export_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT data_export_requests_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT data_export_requests_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT data_export_requests_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT data_export_requests_scope_check CHECK (request_scope IN (
    'tenant',
    'customer',
    'call',
    'case',
    'lead'
  )),
  CONSTRAINT data_export_requests_target_entity_type_not_blank_check CHECK (
    target_entity_type IS NULL OR btrim(target_entity_type) <> ''
  ),
  CONSTRAINT data_export_requests_status_check CHECK (status IN (
    'requested',
    'running',
    'completed',
    'failed',
    'cancelled',
    'expired'
  )),
  CONSTRAINT data_export_requests_export_ref_not_blank_check CHECK (
    export_ref IS NULL OR btrim(export_ref) <> ''
  ),
  CONSTRAINT data_export_requests_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT data_export_requests_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT data_export_requests_expires_after_requested_check CHECK (
    expires_at IS NULL OR expires_at >= requested_at
  ),
  CONSTRAINT data_export_requests_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX data_export_requests_tenant_status_requested_at_idx
  ON public.data_export_requests (tenant_id, status, requested_at DESC);

CREATE TABLE public.data_deletion_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  requested_by_user_id bigint NOT NULL,
  request_scope text NOT NULL,
  target_entity_type text,
  target_entity_public_id uuid,
  status text NOT NULL DEFAULT 'requested',
  reason text,
  error_message text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT data_deletion_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT data_deletion_requests_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT data_deletion_requests_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT data_deletion_requests_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT data_deletion_requests_scope_check CHECK (request_scope IN (
    'tenant',
    'customer',
    'call',
    'case',
    'lead'
  )),
  CONSTRAINT data_deletion_requests_target_entity_type_not_blank_check CHECK (
    target_entity_type IS NULL OR btrim(target_entity_type) <> ''
  ),
  CONSTRAINT data_deletion_requests_status_check CHECK (status IN (
    'requested',
    'running',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT data_deletion_requests_reason_not_blank_check CHECK (
    reason IS NULL OR btrim(reason) <> ''
  ),
  CONSTRAINT data_deletion_requests_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT data_deletion_requests_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT data_deletion_requests_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX data_deletion_requests_tenant_status_requested_at_idx
  ON public.data_deletion_requests (tenant_id, status, requested_at DESC);

CREATE TABLE public.pii_redaction_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint,
  requested_by_user_id bigint,
  source_type text NOT NULL,
  source_public_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  rule_set text,
  error_message text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pii_redaction_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT pii_redaction_jobs_tenant_source_unique UNIQUE (tenant_id, source_type, source_public_id),
  CONSTRAINT pii_redaction_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT pii_redaction_jobs_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT pii_redaction_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT pii_redaction_jobs_source_type_not_blank_check CHECK (btrim(source_type) <> ''),
  CONSTRAINT pii_redaction_jobs_status_check CHECK (status IN (
    'queued',
    'running',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT pii_redaction_jobs_rule_set_not_blank_check CHECK (
    rule_set IS NULL OR btrim(rule_set) <> ''
  ),
  CONSTRAINT pii_redaction_jobs_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT pii_redaction_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT pii_redaction_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX pii_redaction_jobs_tenant_status_requested_at_idx
  ON public.pii_redaction_jobs (tenant_id, status, requested_at DESC);
