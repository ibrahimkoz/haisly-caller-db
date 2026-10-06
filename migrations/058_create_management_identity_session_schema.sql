ALTER TABLE public.platform_admin_users
  ADD COLUMN password_setup_required boolean NOT NULL DEFAULT true,
  ADD COLUMN first_login_completed_at timestamptz,
  ADD COLUMN last_seen_at timestamptz,
  ADD CONSTRAINT platform_admin_users_first_login_after_created_check CHECK (
    first_login_completed_at IS NULL OR first_login_completed_at >= created_at
  ),
  ADD CONSTRAINT platform_admin_users_last_seen_after_created_check CHECK (
    last_seen_at IS NULL OR last_seen_at >= created_at
  );

CREATE TABLE public.platform_admin_credentials (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_user_id bigint NOT NULL,
  credential_type text NOT NULL DEFAULT 'password',
  credential_identifier text NOT NULL,
  secret_hash text NOT NULL,
  hash_algorithm text NOT NULL DEFAULT 'argon2id',
  hash_parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT platform_admin_credentials_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_credentials_user_type_identifier_unique UNIQUE (
    platform_admin_user_id,
    credential_type,
    credential_identifier
  ),
  CONSTRAINT platform_admin_credentials_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_credentials_type_check CHECK (credential_type IN (
    'password'
  )),
  CONSTRAINT platform_admin_credentials_identifier_not_blank_check CHECK (
    btrim(credential_identifier) <> ''
  ),
  CONSTRAINT platform_admin_credentials_secret_hash_not_blank_check CHECK (
    btrim(secret_hash) <> ''
  ),
  CONSTRAINT platform_admin_credentials_secret_hash_length_check CHECK (
    length(secret_hash) >= 20
  ),
  CONSTRAINT platform_admin_credentials_hash_algorithm_not_blank_check CHECK (
    btrim(hash_algorithm) <> ''
  ),
  CONSTRAINT platform_admin_credentials_hash_parameters_object_check CHECK (
    jsonb_typeof(hash_parameters) = 'object'
  ),
  CONSTRAINT platform_admin_credentials_status_check CHECK (status IN (
    'active',
    'rotated',
    'revoked'
  )),
  CONSTRAINT platform_admin_credentials_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE INDEX platform_admin_credentials_user_status_idx
  ON public.platform_admin_credentials (platform_admin_user_id, status);

CREATE TABLE public.platform_admin_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_user_id bigint NOT NULL,
  access_token_jti text NOT NULL,
  csrf_token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  ip_address inet,
  user_agent text,
  device_label text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  idle_expires_at timestamptz,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT platform_admin_sessions_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_sessions_access_token_jti_unique UNIQUE (access_token_jti),
  CONSTRAINT platform_admin_sessions_id_user_unique UNIQUE (id, platform_admin_user_id),
  CONSTRAINT platform_admin_sessions_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_sessions_status_check CHECK (status IN (
    'active',
    'revoked',
    'expired'
  )),
  CONSTRAINT platform_admin_sessions_access_token_jti_not_blank_check CHECK (
    btrim(access_token_jti) <> ''
  ),
  CONSTRAINT platform_admin_sessions_csrf_token_hash_not_blank_check CHECK (
    btrim(csrf_token_hash) <> ''
  ),
  CONSTRAINT platform_admin_sessions_csrf_token_hash_length_check CHECK (
    length(csrf_token_hash) >= 20
  ),
  CONSTRAINT platform_admin_sessions_device_label_not_blank_check CHECK (
    device_label IS NULL OR btrim(device_label) <> ''
  ),
  CONSTRAINT platform_admin_sessions_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT platform_admin_sessions_idle_expiry_check CHECK (
    idle_expires_at IS NULL OR idle_expires_at > created_at
  ),
  CONSTRAINT platform_admin_sessions_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  ),
  CONSTRAINT platform_admin_sessions_metadata_object_check CHECK (
    jsonb_typeof(metadata) = 'object'
  )
);

CREATE INDEX platform_admin_sessions_user_status_expires_at_idx
  ON public.platform_admin_sessions (platform_admin_user_id, status, expires_at);

CREATE INDEX platform_admin_sessions_status_last_seen_idx
  ON public.platform_admin_sessions (status, last_seen_at DESC);

CREATE TABLE public.platform_admin_refresh_tokens (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_user_id bigint NOT NULL,
  platform_admin_session_id bigint NOT NULL,
  token_hash text NOT NULL,
  token_family_id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_refresh_token_id bigint,
  status text NOT NULL DEFAULT 'active',
  issued_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  rotated_at timestamptz,
  revoked_at timestamptz,
  reused_at timestamptz,
  CONSTRAINT platform_admin_refresh_tokens_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_refresh_tokens_token_hash_unique UNIQUE (token_hash),
  CONSTRAINT platform_admin_refresh_tokens_session_user_fk FOREIGN KEY (
    platform_admin_session_id,
    platform_admin_user_id
  )
    REFERENCES public.platform_admin_sessions (id, platform_admin_user_id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_refresh_tokens_user_fk FOREIGN KEY (platform_admin_user_id)
    REFERENCES public.platform_admin_users (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_refresh_tokens_parent_fk FOREIGN KEY (parent_refresh_token_id)
    REFERENCES public.platform_admin_refresh_tokens (id)
    ON DELETE SET NULL,
  CONSTRAINT platform_admin_refresh_tokens_status_check CHECK (status IN (
    'active',
    'rotated',
    'revoked',
    'expired',
    'reused'
  )),
  CONSTRAINT platform_admin_refresh_tokens_token_hash_not_blank_check CHECK (
    btrim(token_hash) <> ''
  ),
  CONSTRAINT platform_admin_refresh_tokens_token_hash_length_check CHECK (
    length(token_hash) >= 20
  ),
  CONSTRAINT platform_admin_refresh_tokens_expiry_check CHECK (expires_at > issued_at),
  CONSTRAINT platform_admin_refresh_tokens_rotated_timestamp_check CHECK (
    status <> 'rotated' OR rotated_at IS NOT NULL
  ),
  CONSTRAINT platform_admin_refresh_tokens_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  ),
  CONSTRAINT platform_admin_refresh_tokens_reused_timestamp_check CHECK (
    status <> 'reused' OR reused_at IS NOT NULL
  )
);

CREATE INDEX platform_admin_refresh_tokens_user_status_expires_at_idx
  ON public.platform_admin_refresh_tokens (platform_admin_user_id, status, expires_at);

CREATE INDEX platform_admin_refresh_tokens_family_status_idx
  ON public.platform_admin_refresh_tokens (token_family_id, status);

CREATE TABLE public.platform_admin_permissions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_admin_permissions_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_permissions_code_unique UNIQUE (code),
  CONSTRAINT platform_admin_permissions_code_format_check CHECK (
    code ~ '^management\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
  ),
  CONSTRAINT platform_admin_permissions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT platform_admin_permissions_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT platform_admin_permissions_category_not_blank_check CHECK (
    btrim(category) <> ''
  ),
  CONSTRAINT platform_admin_permissions_status_check CHECK (status IN (
    'active',
    'retired'
  ))
);

CREATE INDEX platform_admin_permissions_category_code_idx
  ON public.platform_admin_permissions (category, code);

CREATE TABLE public.platform_admin_role_permissions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform_admin_role_id bigint NOT NULL,
  platform_admin_permission_id bigint NOT NULL,
  granted_by_platform_admin_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT platform_admin_role_permissions_public_id_unique UNIQUE (public_id),
  CONSTRAINT platform_admin_role_permissions_role_permission_unique UNIQUE (
    platform_admin_role_id,
    platform_admin_permission_id
  ),
  CONSTRAINT platform_admin_role_permissions_role_fk FOREIGN KEY (platform_admin_role_id)
    REFERENCES public.platform_admin_roles (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_role_permissions_permission_fk FOREIGN KEY (platform_admin_permission_id)
    REFERENCES public.platform_admin_permissions (id)
    ON DELETE CASCADE,
  CONSTRAINT platform_admin_role_permissions_granted_by_fk FOREIGN KEY (
    granted_by_platform_admin_user_id
  )
    REFERENCES public.platform_admin_users (id)
    ON DELETE SET NULL
);

CREATE INDEX platform_admin_role_permissions_permission_idx
  ON public.platform_admin_role_permissions (platform_admin_permission_id);

ALTER TABLE public.audit_logs
  ADD COLUMN actor_platform_admin_user_id bigint,
  ADD COLUMN management_session_id bigint,
  ADD CONSTRAINT audit_logs_actor_platform_admin_user_fk FOREIGN KEY (
    actor_platform_admin_user_id
  )
    REFERENCES public.platform_admin_users (id)
    ON DELETE RESTRICT
    NOT VALID,
  ADD CONSTRAINT audit_logs_management_session_fk FOREIGN KEY (
    management_session_id,
    actor_platform_admin_user_id
  )
    REFERENCES public.platform_admin_sessions (id, platform_admin_user_id)
    ON DELETE RESTRICT
    NOT VALID,
  ADD CONSTRAINT audit_logs_platform_actor_required_check CHECK (
    actor_type <> 'platform_user' OR actor_platform_admin_user_id IS NOT NULL
  ) NOT VALID,
  ADD CONSTRAINT audit_logs_single_human_actor_check CHECK (
    NOT (
      actor_user_id IS NOT NULL
      AND actor_platform_admin_user_id IS NOT NULL
    )
  ) NOT VALID;

CREATE INDEX audit_logs_platform_actor_created_at_idx
  ON public.audit_logs (actor_platform_admin_user_id, created_at DESC)
  WHERE actor_platform_admin_user_id IS NOT NULL;

CREATE INDEX audit_logs_management_session_created_at_idx
  ON public.audit_logs (management_session_id, created_at DESC)
  WHERE management_session_id IS NOT NULL;

INSERT INTO public.platform_admin_permissions (code, name, description, category)
VALUES
  ('management.dashboard.read', 'Read management dashboard', 'View platform-level dashboard summaries.', 'dashboard'),
  ('management.tenants.read', 'Read tenants', 'Search and inspect tenant directory records.', 'tenants'),
  ('management.tenants.manage_lifecycle', 'Manage tenant lifecycle', 'Change tenant lifecycle state after policy approval.', 'tenants'),
  ('management.tenants.manage_plan', 'Manage tenant plan', 'Assign or change tenant plans after policy approval.', 'tenants'),
  ('management.users.read', 'Read platform users', 'View management users and role assignments.', 'users'),
  ('management.users.manage', 'Manage platform users', 'Create, update, suspend, or revoke management users.', 'users'),
  ('management.roles.read', 'Read platform roles', 'View management roles and permissions.', 'roles'),
  ('management.roles.manage', 'Manage platform roles', 'Change management role permission assignments.', 'roles'),
  ('management.sessions.read', 'Read management sessions', 'View active and historical management sessions.', 'sessions'),
  ('management.sessions.revoke', 'Revoke management sessions', 'Revoke management sessions and refresh token families.', 'sessions'),
  ('management.support_sessions.read', 'Read support sessions', 'View support access requests and history.', 'support_sessions'),
  ('management.support_sessions.create', 'Create support sessions', 'Request scoped tenant support access.', 'support_sessions'),
  ('management.support_sessions.approve', 'Approve support sessions', 'Approve support access when policy requires it.', 'support_sessions'),
  ('management.support_sessions.revoke', 'Revoke support sessions', 'Revoke active support access.', 'support_sessions'),
  ('management.billing.read', 'Read billing', 'View billing, usage, and plan summaries.', 'billing'),
  ('management.billing.manage', 'Manage billing', 'Manage billing operations after commercial policy approval.', 'billing'),
  ('management.feature_flags.read', 'Read feature flags', 'View feature flag and rollout configuration.', 'feature_flags'),
  ('management.feature_flags.manage', 'Manage feature flags', 'Change feature flag and rollout configuration.', 'feature_flags'),
  ('management.quotas.read', 'Read quotas', 'View quota policies and usage snapshots.', 'quotas'),
  ('management.quotas.manage', 'Manage quotas', 'Change quota policies after policy approval.', 'quotas'),
  ('management.operations.read', 'Read operations', 'View operational health, jobs, runbooks, and incidents.', 'operations'),
  ('management.operations.manage', 'Manage operations', 'Run approved operational actions.', 'operations'),
  ('management.security.read', 'Read security', 'View security events, incidents, scans, and SBOM summaries.', 'security'),
  ('management.security.manage', 'Manage security', 'Run approved security containment and governance actions.', 'security'),
  ('management.audit.read', 'Read audit', 'View immutable management and tenant audit records.', 'audit'),
  ('management.elevated_actions.approve', 'Approve elevated actions', 'Approve future elevated management actions after policy approval.', 'elevated_actions')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  status = 'active',
  updated_at = now();

INSERT INTO public.platform_admin_roles (code, name, description, status)
VALUES
  ('platform_owner', 'Platform owner', 'Full platform ownership and final-owner protected governance.', 'active'),
  ('platform_admin', 'Platform admin', 'Routine tenant, plan, flag, quota, and platform administration.', 'active'),
  ('platform_operator', 'Platform operator', 'Operational health, jobs, incidents, backups, and runbooks.', 'active'),
  ('support_agent', 'Support agent', 'Audited tenant support access after support policy approval.', 'active'),
  ('security_operator', 'Security operator', 'Security events, incidents, scans, sessions, and containment.', 'active'),
  ('billing_operator', 'Billing operator', 'Billing, plans, usage, invoices, and adjustments.', 'active'),
  ('platform_auditor', 'Platform auditor', 'Read-only management audit, security, billing, and operations visibility.', 'active')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
CROSS JOIN public.platform_admin_permissions permission
WHERE role.code = 'platform_owner'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.dashboard.read',
    'management.tenants.read',
    'management.users.read',
    'management.roles.read',
    'management.sessions.read',
    'management.audit.read'
  )
WHERE role.code = 'platform_admin'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.dashboard.read',
    'management.operations.read',
    'management.operations.manage',
    'management.security.read',
    'management.audit.read'
  )
WHERE role.code = 'platform_operator'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.tenants.read',
    'management.support_sessions.read',
    'management.support_sessions.create',
    'management.audit.read'
  )
WHERE role.code = 'support_agent'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.security.read',
    'management.security.manage',
    'management.sessions.read',
    'management.sessions.revoke',
    'management.audit.read'
  )
WHERE role.code = 'security_operator'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.billing.read',
    'management.billing.manage',
    'management.tenants.read',
    'management.audit.read'
  )
WHERE role.code = 'billing_operator'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;

INSERT INTO public.platform_admin_role_permissions (
  platform_admin_role_id,
  platform_admin_permission_id
)
SELECT role.id, permission.id
FROM public.platform_admin_roles role
JOIN public.platform_admin_permissions permission
  ON permission.code IN (
    'management.dashboard.read',
    'management.tenants.read',
    'management.users.read',
    'management.roles.read',
    'management.sessions.read',
    'management.support_sessions.read',
    'management.billing.read',
    'management.feature_flags.read',
    'management.quotas.read',
    'management.operations.read',
    'management.security.read',
    'management.audit.read'
  )
WHERE role.code = 'platform_auditor'
ON CONFLICT (platform_admin_role_id, platform_admin_permission_id) DO NOTHING;
