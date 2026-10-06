CREATE TABLE public.platform_admin_users (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL,
  normalized_email text NOT NULL,
  display_name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  mfa_status text NOT NULL DEFAULT 'enforced',
  auth_subject_ref text,
  last_login_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_admin_users_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_users_normalized_email_unique UNIQUE (normalized_email),
  CONSTRAINT platform_admin_users_email_not_blank_check CHECK (btrim(email) <> ''),
  CONSTRAINT platform_admin_users_normalized_email_not_blank_check CHECK (btrim(normalized_email) <> ''),
  CONSTRAINT platform_admin_users_display_name_not_blank_check CHECK (btrim(display_name) <> ''),
  CONSTRAINT platform_admin_users_status_check CHECK (status IN (
    'active',
    'suspended',
    'revoked'
  )),
  CONSTRAINT platform_admin_users_mfa_status_check CHECK (mfa_status IN (
    'enforced',
    'recovery_pending',
    'disabled'
  )),
  CONSTRAINT platform_admin_users_auth_subject_not_blank_check CHECK (
    auth_subject_ref IS NULL OR btrim(auth_subject_ref) <> ''
  ),
  CONSTRAINT platform_admin_users_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX platform_admin_users_status_updated_at_idx
  ON public.platform_admin_users (status, updated_at DESC);

CREATE TABLE public.platform_admin_roles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_admin_roles_code_unique UNIQUE (code),
  CONSTRAINT platform_admin_roles_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT platform_admin_roles_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT platform_admin_roles_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT platform_admin_roles_status_check CHECK (status IN (
    'active',
    'retired'
  )),
  CONSTRAINT platform_admin_roles_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE TABLE public.platform_admin_user_roles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  platform_admin_user_id bigint NOT NULL,
  platform_admin_role_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'active',
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by_platform_admin_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_admin_user_roles_user_role_unique UNIQUE (platform_admin_user_id, platform_admin_role_id),
  CONSTRAINT platform_admin_user_roles_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_user_roles_role_fk FOREIGN KEY (platform_admin_role_id)
    REFERENCES public.platform_admin_roles (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_user_roles_assigned_by_fk FOREIGN KEY (assigned_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT platform_admin_user_roles_status_check CHECK (status IN (
    'active',
    'revoked'
  )),
  CONSTRAINT platform_admin_user_roles_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX platform_admin_user_roles_role_status_idx
  ON public.platform_admin_user_roles (platform_admin_role_id, status);

CREATE TABLE public.security_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  platform_admin_user_id bigint,
  source text NOT NULL,
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  summary text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT security_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT security_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT security_events_platform_admin_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT security_events_source_not_blank_check CHECK (btrim(source) <> ''),
  CONSTRAINT security_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT security_events_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT security_events_status_check CHECK (status IN (
    'open',
    'investigating',
    'resolved',
    'ignored'
  )),
  CONSTRAINT security_events_summary_not_blank_check CHECK (btrim(summary) <> ''),
  CONSTRAINT security_events_details_object_check CHECK (jsonb_typeof(details) = 'object'),
  CONSTRAINT security_events_resolved_after_occurred_check CHECK (
    resolved_at IS NULL OR resolved_at >= occurred_at
  ),
  CONSTRAINT security_events_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX security_events_status_severity_occurred_at_idx
  ON public.security_events (status, severity, occurred_at DESC);

CREATE INDEX security_events_tenant_occurred_at_idx
  ON public.security_events (tenant_id, occurred_at DESC)
  WHERE tenant_id IS NOT NULL;

CREATE TABLE public.security_incidents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  incident_code text NOT NULL,
  title text NOT NULL,
  description text,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  impact_scope text NOT NULL DEFAULT 'platform',
  opened_by_platform_admin_user_id bigint,
  owner_platform_admin_user_id bigint,
  started_at timestamptz NOT NULL DEFAULT now(),
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  postmortem_ref text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT security_incidents_public_id_unique UNIQUE (public_id),
  CONSTRAINT security_incidents_incident_code_unique UNIQUE (incident_code),
  CONSTRAINT security_incidents_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT security_incidents_opened_by_platform_admin_fk FOREIGN KEY (opened_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT security_incidents_owner_platform_admin_fk FOREIGN KEY (owner_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT security_incidents_incident_code_not_blank_check CHECK (btrim(incident_code) <> ''),
  CONSTRAINT security_incidents_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT security_incidents_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT security_incidents_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT security_incidents_status_check CHECK (status IN (
    'open',
    'investigating',
    'mitigated',
    'resolved',
    'cancelled'
  )),
  CONSTRAINT security_incidents_impact_scope_check CHECK (impact_scope IN (
    'platform',
    'tenant',
    'provider',
    'internal'
  )),
  CONSTRAINT security_incidents_postmortem_ref_not_blank_check CHECK (
    postmortem_ref IS NULL OR btrim(postmortem_ref) <> ''
  ),
  CONSTRAINT security_incidents_resolved_after_started_check CHECK (
    resolved_at IS NULL OR resolved_at >= started_at
  ),
  CONSTRAINT security_incidents_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX security_incidents_status_severity_detected_at_idx
  ON public.security_incidents (status, severity, detected_at DESC);

CREATE INDEX security_incidents_tenant_status_detected_at_idx
  ON public.security_incidents (tenant_id, status, detected_at DESC)
  WHERE tenant_id IS NOT NULL;

CREATE TABLE public.access_reviews (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint,
  review_scope text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft',
  due_at timestamptz,
  completed_at timestamptz,
  initiated_by_platform_admin_user_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT access_reviews_public_id_unique UNIQUE (public_id),
  CONSTRAINT access_reviews_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE SET NULL,
  CONSTRAINT access_reviews_initiated_by_platform_admin_fk FOREIGN KEY (initiated_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT access_reviews_scope_check CHECK (review_scope IN (
    'tenant_user_access',
    'service_account_access',
    'platform_admin_access'
  )),
  CONSTRAINT access_reviews_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT access_reviews_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT access_reviews_status_check CHECK (status IN (
    'draft',
    'active',
    'completed',
    'cancelled'
  )),
  CONSTRAINT access_reviews_completed_after_created_check CHECK (
    completed_at IS NULL OR completed_at >= created_at
  ),
  CONSTRAINT access_reviews_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX access_reviews_scope_status_due_at_idx
  ON public.access_reviews (review_scope, status, due_at ASC);

CREATE INDEX access_reviews_tenant_status_updated_at_idx
  ON public.access_reviews (tenant_id, status, updated_at DESC)
  WHERE tenant_id IS NOT NULL;

CREATE TABLE public.access_review_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  access_review_id bigint NOT NULL,
  subject_type text NOT NULL,
  subject_public_id uuid NOT NULL,
  permission_scope text NOT NULL,
  decision text NOT NULL DEFAULT 'pending',
  reviewed_by_platform_admin_user_id bigint,
  reviewed_at timestamptz,
  note text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT access_review_items_public_id_unique UNIQUE (public_id),
  CONSTRAINT access_review_items_review_subject_scope_unique UNIQUE (
    access_review_id,
    subject_type,
    subject_public_id,
    permission_scope
  ),
  CONSTRAINT access_review_items_access_review_fk FOREIGN KEY (access_review_id)
    REFERENCES public.access_reviews (id)
    ON DELETE CASCADE,
  CONSTRAINT access_review_items_reviewed_by_platform_admin_fk FOREIGN KEY (reviewed_by_platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL,
  CONSTRAINT access_review_items_subject_type_check CHECK (subject_type IN (
    'user',
    'service_account',
    'platform_admin'
  )),
  CONSTRAINT access_review_items_permission_scope_not_blank_check CHECK (
    btrim(permission_scope) <> ''
  ),
  CONSTRAINT access_review_items_decision_check CHECK (decision IN (
    'pending',
    'approved',
    'revoked',
    'needs_follow_up'
  )),
  CONSTRAINT access_review_items_note_not_blank_check CHECK (
    note IS NULL OR btrim(note) <> ''
  ),
  CONSTRAINT access_review_items_decision_review_pair_check CHECK (
    decision = 'pending'
    OR (reviewed_by_platform_admin_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT access_review_items_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX access_review_items_review_decision_idx
  ON public.access_review_items (access_review_id, decision, reviewed_at DESC);

CREATE TABLE public.vulnerability_scan_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  scanner_name text NOT NULL,
  scanner_type text NOT NULL,
  target_ref text NOT NULL,
  git_ref text,
  status text NOT NULL DEFAULT 'queued',
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vulnerability_scan_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT vulnerability_scan_runs_scanner_name_not_blank_check CHECK (btrim(scanner_name) <> ''),
  CONSTRAINT vulnerability_scan_runs_scanner_type_check CHECK (scanner_type IN (
    'osv',
    'npm_audit',
    'sast',
    'container',
    'custom'
  )),
  CONSTRAINT vulnerability_scan_runs_target_ref_not_blank_check CHECK (btrim(target_ref) <> ''),
  CONSTRAINT vulnerability_scan_runs_git_ref_not_blank_check CHECK (
    git_ref IS NULL OR btrim(git_ref) <> ''
  ),
  CONSTRAINT vulnerability_scan_runs_status_check CHECK (status IN (
    'queued',
    'running',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT vulnerability_scan_runs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT vulnerability_scan_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT vulnerability_scan_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX vulnerability_scan_runs_status_created_at_idx
  ON public.vulnerability_scan_runs (status, created_at DESC);

CREATE TABLE public.vulnerability_findings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  vulnerability_scan_run_id bigint NOT NULL,
  finding_key text NOT NULL,
  package_name text NOT NULL,
  package_version text,
  advisory_id text,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  cvss_score numeric(3,1),
  affected_range text,
  fixed_version text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  discovered_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vulnerability_findings_public_id_unique UNIQUE (public_id),
  CONSTRAINT vulnerability_findings_run_finding_key_unique UNIQUE (vulnerability_scan_run_id, finding_key),
  CONSTRAINT vulnerability_findings_scan_run_fk FOREIGN KEY (vulnerability_scan_run_id)
    REFERENCES public.vulnerability_scan_runs (id)
    ON DELETE CASCADE,
  CONSTRAINT vulnerability_findings_finding_key_not_blank_check CHECK (btrim(finding_key) <> ''),
  CONSTRAINT vulnerability_findings_package_name_not_blank_check CHECK (btrim(package_name) <> ''),
  CONSTRAINT vulnerability_findings_package_version_not_blank_check CHECK (
    package_version IS NULL OR btrim(package_version) <> ''
  ),
  CONSTRAINT vulnerability_findings_advisory_id_not_blank_check CHECK (
    advisory_id IS NULL OR btrim(advisory_id) <> ''
  ),
  CONSTRAINT vulnerability_findings_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT vulnerability_findings_status_check CHECK (status IN (
    'open',
    'accepted_risk',
    'resolved',
    'false_positive'
  )),
  CONSTRAINT vulnerability_findings_cvss_range_check CHECK (
    cvss_score IS NULL OR (cvss_score >= 0 AND cvss_score <= 10)
  ),
  CONSTRAINT vulnerability_findings_affected_range_not_blank_check CHECK (
    affected_range IS NULL OR btrim(affected_range) <> ''
  ),
  CONSTRAINT vulnerability_findings_fixed_version_not_blank_check CHECK (
    fixed_version IS NULL OR btrim(fixed_version) <> ''
  ),
  CONSTRAINT vulnerability_findings_details_object_check CHECK (jsonb_typeof(details) = 'object'),
  CONSTRAINT vulnerability_findings_resolved_after_discovered_check CHECK (
    resolved_at IS NULL OR resolved_at >= discovered_at
  ),
  CONSTRAINT vulnerability_findings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX vulnerability_findings_status_severity_discovered_at_idx
  ON public.vulnerability_findings (status, severity, discovered_at DESC);

CREATE TABLE public.sbom_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_ref text NOT NULL,
  source_type text NOT NULL DEFAULT 'repository',
  format text NOT NULL,
  format_version text,
  generated_at timestamptz NOT NULL DEFAULT now(),
  artifact_ref text,
  package_count integer,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sbom_snapshots_public_id_unique UNIQUE (public_id),
  CONSTRAINT sbom_snapshots_source_ref_not_blank_check CHECK (btrim(source_ref) <> ''),
  CONSTRAINT sbom_snapshots_source_type_check CHECK (source_type IN (
    'repository',
    'artifact',
    'container',
    'package'
  )),
  CONSTRAINT sbom_snapshots_format_check CHECK (format IN (
    'spdx',
    'cyclonedx',
    'custom'
  )),
  CONSTRAINT sbom_snapshots_format_version_not_blank_check CHECK (
    format_version IS NULL OR btrim(format_version) <> ''
  ),
  CONSTRAINT sbom_snapshots_artifact_ref_not_blank_check CHECK (
    artifact_ref IS NULL OR btrim(artifact_ref) <> ''
  ),
  CONSTRAINT sbom_snapshots_package_count_non_negative_check CHECK (
    package_count IS NULL OR package_count >= 0
  ),
  CONSTRAINT sbom_snapshots_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT sbom_snapshots_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX sbom_snapshots_source_generated_at_idx
  ON public.sbom_snapshots (source_ref, generated_at DESC);

CREATE TABLE public.dependency_scan_runs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  scanner_name text NOT NULL,
  ecosystem text NOT NULL DEFAULT 'nodejs',
  target_ref text NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dependency_scan_runs_public_id_unique UNIQUE (public_id),
  CONSTRAINT dependency_scan_runs_scanner_name_not_blank_check CHECK (btrim(scanner_name) <> ''),
  CONSTRAINT dependency_scan_runs_ecosystem_check CHECK (ecosystem IN (
    'nodejs',
    'python',
    'container',
    'os',
    'other'
  )),
  CONSTRAINT dependency_scan_runs_target_ref_not_blank_check CHECK (btrim(target_ref) <> ''),
  CONSTRAINT dependency_scan_runs_status_check CHECK (status IN (
    'queued',
    'running',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT dependency_scan_runs_summary_object_check CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT dependency_scan_runs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT dependency_scan_runs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX dependency_scan_runs_status_created_at_idx
  ON public.dependency_scan_runs (status, created_at DESC);

CREATE TABLE public.dependency_scan_findings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  dependency_scan_run_id bigint NOT NULL,
  package_name text NOT NULL,
  package_version text,
  issue_type text NOT NULL,
  severity text NOT NULL DEFAULT 'low',
  status text NOT NULL DEFAULT 'open',
  recommended_version text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dependency_scan_findings_public_id_unique UNIQUE (public_id),
  CONSTRAINT dependency_scan_findings_run_package_issue_unique UNIQUE (
    dependency_scan_run_id,
    package_name,
    issue_type
  ),
  CONSTRAINT dependency_scan_findings_scan_run_fk FOREIGN KEY (dependency_scan_run_id)
    REFERENCES public.dependency_scan_runs (id)
    ON DELETE CASCADE,
  CONSTRAINT dependency_scan_findings_package_name_not_blank_check CHECK (btrim(package_name) <> ''),
  CONSTRAINT dependency_scan_findings_package_version_not_blank_check CHECK (
    package_version IS NULL OR btrim(package_version) <> ''
  ),
  CONSTRAINT dependency_scan_findings_issue_type_check CHECK (issue_type IN (
    'outdated',
    'deprecated',
    'license',
    'integrity',
    'unknown'
  )),
  CONSTRAINT dependency_scan_findings_severity_check CHECK (severity IN (
    'low',
    'medium',
    'high',
    'critical'
  )),
  CONSTRAINT dependency_scan_findings_status_check CHECK (status IN (
    'open',
    'accepted_risk',
    'resolved',
    'ignored'
  )),
  CONSTRAINT dependency_scan_findings_recommended_version_not_blank_check CHECK (
    recommended_version IS NULL OR btrim(recommended_version) <> ''
  ),
  CONSTRAINT dependency_scan_findings_details_object_check CHECK (jsonb_typeof(details) = 'object'),
  CONSTRAINT dependency_scan_findings_resolved_after_detected_check CHECK (
    resolved_at IS NULL OR resolved_at >= detected_at
  ),
  CONSTRAINT dependency_scan_findings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX dependency_scan_findings_status_severity_detected_at_idx
  ON public.dependency_scan_findings (status, severity, detected_at DESC);
