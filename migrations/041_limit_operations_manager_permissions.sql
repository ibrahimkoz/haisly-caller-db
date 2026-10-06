WITH operations_roles AS (
  SELECT id, tenant_id
  FROM public.roles
  WHERE is_system IS TRUE
    AND code = 'operations_manager'
),
removed_permissions AS (
  DELETE FROM public.role_permissions
  USING operations_roles, public.permissions
  WHERE role_permissions.role_id = operations_roles.id
    AND role_permissions.tenant_id = operations_roles.tenant_id
    AND role_permissions.permission_id = permissions.id
    AND permissions.code IN (
      'sales.read',
      'sla.read',
      'sla.manage'
    )
  RETURNING role_permissions.id
)
UPDATE public.roles
SET description = 'Daily call, case, customer, handoff, and notification operations access.',
    updated_at = now()
FROM operations_roles
WHERE roles.id = operations_roles.id
  AND roles.tenant_id = operations_roles.tenant_id;
