WITH tenant_roles AS (
  SELECT id, tenant_id, code
  FROM public.roles
  WHERE is_system IS TRUE
    AND code IN (
      'admin',
      'operations_manager',
      'support_agent',
      'sales_manager',
      'billing_manager',
      'ai_manager',
      'integration_manager',
      'auditor'
    )
),
desired_role_permissions AS (
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
      ('operations_manager', 'calls.read'),
      ('operations_manager', 'artifacts.access'),
      ('operations_manager', 'operations.read'),
      ('operations_manager', 'operations.manage'),
      ('operations_manager', 'sales.read'),
      ('operations_manager', 'sla.read'),
      ('operations_manager', 'sla.manage'),
      ('operations_manager', 'notifications.read'),
      ('operations_manager', 'notifications.manage'),
      ('support_agent', 'tenant.read'),
      ('support_agent', 'calls.read'),
      ('support_agent', 'artifacts.access'),
      ('support_agent', 'operations.read'),
      ('support_agent', 'operations.manage'),
      ('sales_manager', 'tenant.read'),
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
      ('ai_manager', 'calls.read'),
      ('ai_manager', 'artifacts.access'),
      ('ai_manager', 'compliance.read'),
      ('ai_manager', 'ai.read'),
      ('ai_manager', 'ai.manage'),
      ('integration_manager', 'tenant.read'),
      ('integration_manager', 'integrations.read'),
      ('integration_manager', 'integrations.manage'),
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
deleted_stale_role_permissions AS (
  DELETE FROM public.role_permissions
  USING tenant_roles, public.permissions
  WHERE role_permissions.role_id = tenant_roles.id
    AND role_permissions.tenant_id = tenant_roles.tenant_id
    AND role_permissions.permission_id = permissions.id
    AND NOT EXISTS (
      SELECT 1
      FROM desired_role_permissions
      WHERE desired_role_permissions.tenant_id = role_permissions.tenant_id
        AND desired_role_permissions.role_id = role_permissions.role_id
        AND desired_role_permissions.permission_code = permissions.code
    )
  RETURNING role_permissions.id
)
INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
SELECT desired_role_permissions.tenant_id, desired_role_permissions.role_id, permissions.id
FROM desired_role_permissions
JOIN public.permissions
  ON permissions.code = desired_role_permissions.permission_code
ON CONFLICT ON CONSTRAINT role_permissions_role_permission_unique DO NOTHING;
