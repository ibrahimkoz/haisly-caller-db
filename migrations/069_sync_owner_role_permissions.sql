INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
SELECT roles.tenant_id, roles.id, permissions.id
FROM public.roles
CROSS JOIN public.permissions
WHERE roles.is_system IS TRUE
  AND roles.code = 'owner'
  AND roles.status = 'active'
ON CONFLICT ON CONSTRAINT role_permissions_role_permission_unique DO NOTHING;
