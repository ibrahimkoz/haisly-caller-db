WITH demo_tenant AS (
  INSERT INTO public.tenants (
    slug,
    name,
    status,
    timezone,
    locale,
    onboarding_state,
    activated_at
  )
  VALUES (
    'demo-tenant',
    'Demo Tenant',
    'active',
    'Europe/Istanbul',
    'tr',
    '{"email_verified": true, "billing_started": false, "phone_setup_started": false, "agent_setup_started": false}'::jsonb,
    now()
  )
  ON CONFLICT ON CONSTRAINT tenants_slug_unique DO UPDATE SET
    name = EXCLUDED.name,
    status = EXCLUDED.status,
    timezone = EXCLUDED.timezone,
    locale = EXCLUDED.locale,
    onboarding_state = EXCLUDED.onboarding_state,
    activated_at = COALESCE(public.tenants.activated_at, EXCLUDED.activated_at),
    updated_at = now()
  RETURNING id, public_id
),
company_profile AS (
  INSERT INTO public.company_profiles (
    tenant_id,
    legal_name,
    display_name,
    industry_code,
    country_code,
    timezone,
    locale
  )
  SELECT
    id,
    'Demo Tenant Ltd.',
    'Demo Tenant',
    'demo',
    'TR',
    'Europe/Istanbul',
    'tr'
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT company_profiles_tenant_id_unique DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    display_name = EXCLUDED.display_name,
    industry_code = EXCLUDED.industry_code,
    country_code = EXCLUDED.country_code,
    timezone = EXCLUDED.timezone,
    locale = EXCLUDED.locale,
    updated_at = now()
  RETURNING id
),
billing_profile AS (
  INSERT INTO public.billing_info (
    tenant_id,
    billing_email,
    legal_name,
    country_code
  )
  SELECT
    id,
    'billing@demo.haisly.local',
    'Demo Tenant Ltd.',
    'TR'
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT billing_info_tenant_id_unique DO UPDATE SET
    billing_email = EXCLUDED.billing_email,
    legal_name = EXCLUDED.legal_name,
    country_code = EXCLUDED.country_code,
    updated_at = now()
  RETURNING id
),
payment_profile AS (
  INSERT INTO public.payment_info (
    tenant_id,
    status
  )
  SELECT
    id,
    'not_configured'
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT payment_info_tenant_id_unique DO UPDATE SET
    status = EXCLUDED.status,
    updated_at = now()
  RETURNING id
),
owner_user AS (
  INSERT INTO public.users (
    tenant_id,
    primary_email,
    first_name,
    last_name,
    status,
    email_verified_at,
    locale,
    timezone
  )
  SELECT
    id,
    'owner@demo.haisly.local',
    'Demo',
    'Owner',
    'active',
    now(),
    'tr',
    'Europe/Istanbul'
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT users_primary_email_normalized_unique DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    status = EXCLUDED.status,
    email_verified_at = COALESCE(public.users.email_verified_at, EXCLUDED.email_verified_at),
    locale = EXCLUDED.locale,
    timezone = EXCLUDED.timezone,
    updated_at = now()
  RETURNING id, tenant_id, public_id, primary_email_normalized
),
owner_settings AS (
  INSERT INTO public.user_settings (
    user_id,
    language,
    timezone,
    notification_preferences,
    mfa_delivery_preference
  )
  SELECT
    id,
    'tr',
    'Europe/Istanbul',
    '{"email": true, "sms": false}'::jsonb,
    'email_otp'
  FROM owner_user
  ON CONFLICT ON CONSTRAINT user_settings_user_id_unique DO UPDATE SET
    language = EXCLUDED.language,
    timezone = EXCLUDED.timezone,
    notification_preferences = EXCLUDED.notification_preferences,
    mfa_delivery_preference = EXCLUDED.mfa_delivery_preference,
    updated_at = now()
  RETURNING id
),
owner_email_contact AS (
  INSERT INTO public.user_verified_contacts (
    user_id,
    contact_type,
    contact_value,
    normalized_value,
    verified_at,
    is_primary
  )
  SELECT
    id,
    'email',
    'owner@demo.haisly.local',
    primary_email_normalized,
    now(),
    true
  FROM owner_user
  ON CONFLICT ON CONSTRAINT user_verified_contacts_user_contact_unique DO UPDATE SET
    verified_at = COALESCE(public.user_verified_contacts.verified_at, EXCLUDED.verified_at),
    is_primary = EXCLUDED.is_primary,
    updated_at = now()
  RETURNING id
),
owner_credential AS (
  INSERT INTO public.user_credentials (
    user_id,
    credential_type,
    identifier,
    secret_hash,
    hash_algorithm,
    status
  )
  SELECT
    id,
    'password',
    'owner@demo.haisly.local',
    '$argon2id$v=19$m=65536,t=3,p=4$demo-placeholder$safe-demo-placeholder-hash-not-a-real-secret',
    'argon2id',
    'active'
  FROM owner_user
  ON CONFLICT ON CONSTRAINT user_credentials_type_identifier_unique DO UPDATE SET
    user_id = EXCLUDED.user_id,
    secret_hash = EXCLUDED.secret_hash,
    hash_algorithm = EXCLUDED.hash_algorithm,
    status = EXCLUDED.status,
    updated_at = now()
  RETURNING id
),
tenant_roles AS (
  INSERT INTO public.roles (tenant_id, code, name, description, is_system, status)
  SELECT demo_tenant.id, role_seed.code, role_seed.name, role_seed.description, true, 'active'
  FROM demo_tenant
  CROSS JOIN (
    VALUES
      ('owner', 'Owner', 'Full tenant owner access.'),
      ('admin', 'Admin', 'Tenant administration and user management access.'),
      ('operations_manager', 'Operations Manager', 'Daily call, case, customer, handoff, SLA, and notification operations access.'),
      ('support_agent', 'Support Agent', 'Frontline call, customer, case, handoff, and task execution access.'),
      ('sales_manager', 'Sales Manager', 'Lead, opportunity, follow-up, customer, and sales reporting access.'),
      ('billing_manager', 'Billing Manager', 'Billing setup, usage, invoice, and payment access.'),
      ('ai_manager', 'AI Manager', 'AI agents, config versions, tools, workflows, knowledge, guardrails, and simulations access.'),
      ('integration_manager', 'Integration Manager', 'External system connection, credential, mapping, and webhook access.'),
      ('auditor', 'Auditor', 'Read-only audit, compliance, operational, and reporting review access.')
  ) AS role_seed(code, name, description)
  ON CONFLICT ON CONSTRAINT roles_tenant_code_unique DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_system = EXCLUDED.is_system,
    status = EXCLUDED.status,
    updated_at = now()
  RETURNING id, tenant_id, code
),
owner_role AS (
  SELECT id, tenant_id
  FROM tenant_roles
  WHERE code = 'owner'
),
owner_role_permissions AS (
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
  SELECT owner_role.tenant_id, owner_role.id, permissions.id
  FROM owner_role
  CROSS JOIN public.permissions
  ON CONFLICT ON CONSTRAINT role_permissions_role_permission_unique DO NOTHING
  RETURNING id
),
role_permission_seed AS (
  SELECT tenant_roles.tenant_id, tenant_roles.id AS role_id, permission_seed.permission_code
  FROM tenant_roles
  JOIN (
    VALUES
      ('admin', 'tenant.read'),
      ('admin', 'tenant.manage'),
      ('admin', 'company_profile.manage'),
      ('admin', 'billing.read'),
      ('admin', 'users.read'),
      ('admin', 'users.manage'),
      ('admin', 'roles.read'),
      ('admin', 'roles.manage'),
      ('admin', 'audit.read'),
      ('admin', 'sessions.manage'),
      ('admin', 'security.manage'),
      ('admin', 'agents.manage'),
      ('admin', 'calls.read'),
      ('admin', 'artifacts.access'),
      ('admin', 'operations.read'),
      ('admin', 'operations.manage'),
      ('admin', 'sales.read'),
      ('admin', 'sales.manage'),
      ('admin', 'integrations.read'),
      ('admin', 'integrations.manage'),
      ('admin', 'compliance.read'),
      ('admin', 'compliance.manage'),
      ('admin', 'ai.read'),
      ('admin', 'ai.manage'),
      ('admin', 'sla.read'),
      ('admin', 'sla.manage'),
      ('admin', 'notifications.read'),
      ('admin', 'notifications.manage'),
      ('admin', 'analytics.read'),
      ('admin', 'observability.read'),
      ('admin', 'telephony.read'),
      ('admin', 'telephony.manage'),
      ('operations_manager', 'tenant.read'),
      ('operations_manager', 'tenant.manage'),
      ('operations_manager', 'calls.read'),
      ('operations_manager', 'artifacts.access'),
      ('operations_manager', 'operations.read'),
      ('operations_manager', 'operations.manage'),
      ('operations_manager', 'sales.read'),
      ('operations_manager', 'integrations.read'),
      ('operations_manager', 'compliance.read'),
      ('operations_manager', 'sla.read'),
      ('operations_manager', 'sla.manage'),
      ('operations_manager', 'notifications.read'),
      ('operations_manager', 'notifications.manage'),
      ('operations_manager', 'analytics.read'),
      ('operations_manager', 'observability.read'),
      ('support_agent', 'tenant.read'),
      ('support_agent', 'tenant.manage'),
      ('support_agent', 'calls.read'),
      ('support_agent', 'artifacts.access'),
      ('support_agent', 'operations.read'),
      ('support_agent', 'operations.manage'),
      ('support_agent', 'sales.read'),
      ('support_agent', 'sla.read'),
      ('support_agent', 'notifications.read'),
      ('sales_manager', 'tenant.read'),
      ('sales_manager', 'tenant.manage'),
      ('sales_manager', 'calls.read'),
      ('sales_manager', 'artifacts.access'),
      ('sales_manager', 'operations.read'),
      ('sales_manager', 'sales.read'),
      ('sales_manager', 'sales.manage'),
      ('sales_manager', 'analytics.read'),
      ('billing_manager', 'tenant.read'),
      ('billing_manager', 'billing.read'),
      ('billing_manager', 'billing.manage'),
      ('billing_manager', 'audit.read'),
      ('ai_manager', 'tenant.read'),
      ('ai_manager', 'tenant.manage'),
      ('ai_manager', 'agents.manage'),
      ('ai_manager', 'calls.read'),
      ('ai_manager', 'artifacts.access'),
      ('ai_manager', 'integrations.read'),
      ('ai_manager', 'compliance.read'),
      ('ai_manager', 'compliance.manage'),
      ('ai_manager', 'ai.read'),
      ('ai_manager', 'ai.manage'),
      ('ai_manager', 'observability.read'),
      ('ai_manager', 'telephony.read'),
      ('integration_manager', 'tenant.read'),
      ('integration_manager', 'tenant.manage'),
      ('integration_manager', 'agents.manage'),
      ('integration_manager', 'integrations.read'),
      ('integration_manager', 'integrations.manage'),
      ('integration_manager', 'ai.read'),
      ('integration_manager', 'observability.read'),
      ('integration_manager', 'telephony.read'),
      ('auditor', 'tenant.read'),
      ('auditor', 'billing.read'),
      ('auditor', 'users.read'),
      ('auditor', 'roles.read'),
      ('auditor', 'audit.read'),
      ('auditor', 'calls.read'),
      ('auditor', 'artifacts.access'),
      ('auditor', 'operations.read'),
      ('auditor', 'sales.read'),
      ('auditor', 'integrations.read'),
      ('auditor', 'compliance.read'),
      ('auditor', 'ai.read'),
      ('auditor', 'sla.read'),
      ('auditor', 'notifications.read'),
      ('auditor', 'analytics.read'),
      ('auditor', 'observability.read'),
      ('auditor', 'telephony.read')
  ) AS permission_seed(role_code, permission_code)
    ON permission_seed.role_code = tenant_roles.code
),
system_role_permissions AS (
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
  SELECT role_permission_seed.tenant_id, role_permission_seed.role_id, permissions.id
  FROM role_permission_seed
  JOIN public.permissions
    ON permissions.code = role_permission_seed.permission_code
  ON CONFLICT ON CONSTRAINT role_permissions_role_permission_unique DO NOTHING
  RETURNING id
),
owner_membership AS (
  INSERT INTO public.tenant_memberships (
    tenant_id,
    user_id,
    status,
    joined_at
  )
  SELECT owner_user.tenant_id, owner_user.id, 'active', now()
  FROM owner_user
  ON CONFLICT ON CONSTRAINT tenant_memberships_user_tenant_unique DO UPDATE SET
    status = EXCLUDED.status,
    joined_at = COALESCE(public.tenant_memberships.joined_at, EXCLUDED.joined_at),
    deleted_at = NULL,
    updated_at = now()
  RETURNING tenant_id, user_id
),
owner_assignment AS (
  INSERT INTO public.user_roles (
    tenant_id,
    user_id,
    role_id,
    assigned_by_user_id,
    status
  )
  SELECT owner_user.tenant_id, owner_user.id, owner_role.id, owner_user.id, 'active'
  FROM owner_user
  JOIN owner_membership
    ON owner_membership.tenant_id = owner_user.tenant_id
   AND owner_membership.user_id = owner_user.id
  CROSS JOIN owner_role
  ON CONFLICT ON CONSTRAINT user_roles_user_role_unique DO UPDATE SET
    assigned_by_user_id = EXCLUDED.assigned_by_user_id,
    status = EXCLUDED.status,
    revoked_at = NULL
  RETURNING id, public_id, tenant_id, user_id
),
owner_mfa_factor AS (
  INSERT INTO public.mfa_factors (
    tenant_id,
    user_id,
    verified_contact_id,
    factor_type,
    status,
    verified_at
  )
  SELECT owner_user.tenant_id, owner_user.id, owner_email_contact.id, 'email_otp', 'active', now()
  FROM owner_user
  CROSS JOIN owner_email_contact
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.mfa_factors
    WHERE user_id = owner_user.id
      AND factor_type = 'email_otp'
      AND status = 'active'
  )
  RETURNING id
)
INSERT INTO public.audit_logs (
  tenant_id,
  actor_type,
  actor_user_id,
  action,
  entity_type,
  entity_public_id,
  category,
  severity,
  request_id,
  metadata
)
SELECT
  owner_assignment.tenant_id,
  'system',
  owner_assignment.user_id,
  'seed.demo_owner_ready',
  'user_role',
  owner_assignment.public_id,
  'seed',
  'info',
  'seed-demo-owner',
  '{"source": "002_demo_owner.sql"}'::jsonb
FROM owner_assignment
WHERE NOT EXISTS (
  SELECT 1
  FROM public.audit_logs
  WHERE request_id = 'seed-demo-owner'
    AND action = 'seed.demo_owner_ready'
);
