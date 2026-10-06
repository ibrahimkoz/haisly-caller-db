WITH tenant_roles AS (
  INSERT INTO public.roles (tenant_id, code, name, description, is_system, status)
  SELECT tenants.id, role_seed.code, role_seed.name, role_seed.description, true, 'active'
  FROM public.tenants
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
owner_role_permissions AS (
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
  SELECT tenant_roles.tenant_id, tenant_roles.id, permissions.id
  FROM tenant_roles
  CROSS JOIN public.permissions
  WHERE tenant_roles.code = 'owner'
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
)
UPDATE public.roles
SET
  status = 'disabled',
  updated_at = now()
WHERE code = 'security_admin'
  AND status = 'active';
