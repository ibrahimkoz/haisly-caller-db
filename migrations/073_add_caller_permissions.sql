INSERT INTO public.permissions (code, name, description, category) VALUES
  ('caller.budgets.allocate', 'caller.budgets.allocate', 'Caller v1 capability.', 'caller'),
  ('caller.calls.assigned', 'caller.calls.assigned', 'Caller v1 capability.', 'caller'),
  ('caller.campaigns.control', 'caller.campaigns.control', 'Caller v1 capability.', 'caller'),
  ('caller.campaigns.edit', 'caller.campaigns.edit', 'Caller v1 capability.', 'caller'),
  ('caller.campaigns.publish', 'caller.campaigns.publish', 'Caller v1 capability.', 'caller'),
  ('caller.campaigns.read', 'caller.campaigns.read', 'Caller v1 capability.', 'caller'),
  ('caller.campaigns.test', 'caller.campaigns.test', 'Caller v1 capability.', 'caller'),
  ('caller.contacts.export', 'caller.contacts.export', 'Caller v1 capability.', 'caller'),
  ('caller.contacts.manage', 'caller.contacts.manage', 'Caller v1 capability.', 'caller'),
  ('caller.data.delete', 'caller.data.delete', 'Caller v1 capability.', 'caller'),
  ('caller.lists.manage', 'caller.lists.manage', 'Caller v1 capability.', 'caller'),
  ('caller.preferences.unblock', 'caller.preferences.unblock', 'Caller v1 capability.', 'caller'),
  ('caller.recordings.read', 'caller.recordings.read', 'Caller v1 capability.', 'caller'),
  ('caller.reports.export', 'caller.reports.export', 'Caller v1 capability.', 'caller'),
  ('caller.tasks.assign', 'caller.tasks.assign', 'Caller v1 capability.', 'caller'),
  ('caller.tasks.assigned', 'caller.tasks.assigned', 'Caller v1 capability.', 'caller'),
  ('caller.transcripts.read', 'caller.transcripts.read', 'Caller v1 capability.', 'caller')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.roles (tenant_id, code, name, description, is_system)
SELECT t.id, r.code, r.name, 'Caller scoped role.', true FROM public.tenants t
CROSS JOIN (VALUES ('campaign_editor', 'Campaign Editor'), ('analyst', 'Analyst')) r(code, name)
ON CONFLICT (tenant_id, code) DO NOTHING;
DELETE FROM public.role_permissions rp USING public.roles r WHERE rp.role_id = r.id AND r.is_system AND r.code IN ('operations_manager','campaign_editor','support_agent','sales_manager','analyst');
INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
SELECT r.tenant_id, r.id, p.id FROM public.roles r
JOIN (VALUES
 ('operations_manager', 'tenant.read'),
 ('operations_manager', 'operations.read'),
 ('operations_manager', 'operations.manage'),
 ('operations_manager', 'calls.read'),
 ('operations_manager', 'notifications.read'),
 ('operations_manager', 'notifications.manage'),
 ('operations_manager', 'analytics.read'),
 ('operations_manager', 'caller.contacts.manage'),
 ('operations_manager', 'caller.lists.manage'),
 ('operations_manager', 'caller.campaigns.read'),
 ('operations_manager', 'caller.campaigns.edit'),
 ('operations_manager', 'caller.campaigns.test'),
 ('operations_manager', 'caller.campaigns.publish'),
 ('operations_manager', 'caller.campaigns.control'),
 ('operations_manager', 'caller.budgets.allocate'),
 ('operations_manager', 'caller.tasks.assign'),
 ('campaign_editor', 'tenant.read'),
 ('campaign_editor', 'caller.contacts.manage'),
 ('campaign_editor', 'caller.lists.manage'),
 ('campaign_editor', 'caller.campaigns.read'),
 ('campaign_editor', 'caller.campaigns.edit'),
 ('campaign_editor', 'caller.campaigns.test'),
 ('support_agent', 'tenant.read'),
 ('support_agent', 'caller.tasks.assigned'),
 ('support_agent', 'caller.calls.assigned'),
 ('sales_manager', 'tenant.read'),
 ('sales_manager', 'caller.tasks.assigned'),
 ('sales_manager', 'caller.calls.assigned'),
 ('analyst', 'tenant.read'),
 ('analyst', 'analytics.read'),
 ('analyst', 'caller.reports.export')) m(role_code, permission_code) ON m.role_code = r.code
JOIN public.permissions p ON p.code = m.permission_code
WHERE r.is_system
ON CONFLICT (role_id, permission_id) DO NOTHING;
INSERT INTO public.role_permissions (tenant_id, role_id, permission_id)
SELECT r.tenant_id, r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE r.code = 'owner' AND p.category = 'caller'
ON CONFLICT (role_id, permission_id) DO NOTHING;
