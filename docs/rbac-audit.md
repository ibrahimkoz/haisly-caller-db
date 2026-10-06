# RBAC And Audit Contract

## RBAC

- Tenant roles are stored in `roles` and scoped by `tenant_id`.
- System permissions are stored globally in `permissions`.
- `role_permissions` links tenant roles to global permissions.
- `user_roles` links tenant users to tenant roles.
- Role codes are unique per tenant.
- Permission codes are globally unique.
- New tenants and local demo seeds start with these system roles:
  - `owner`
  - `admin`
  - `operations_manager`
  - `support_agent`
  - `sales_manager`
  - `billing_manager`
  - `ai_manager`
  - `integration_manager`
  - `auditor`
- Current application services still enforce several broad permissions such as
  `tenant.read`, `tenant.manage`, and `agents.manage`. The system role
  permission sets therefore include both domain-facing permissions
  (`operations.manage`, `integrations.manage`, `ai.manage`, and similar) and
  the broad permissions required by existing endpoint authorization checks.

## Management RBAC

- Management users are stored in `platform_admin_users`, independently from tenant users.
- Management credentials, sessions, and refresh tokens are stored in `platform_admin_credentials`, `platform_admin_sessions`, and `platform_admin_refresh_tokens`.
- Management permissions are stored in `platform_admin_permissions`.
- `platform_admin_role_permissions` links platform admin roles to management permissions.
- Management permission codes use the `management.<resource>.<action>` pattern.
- `platform_owner` receives all seeded management permissions.

## Audit

`audit_logs` is append-only.

Application code must insert audit events and must not update or delete audit rows. The database enforces this with the `audit_logs_prevent_mutation` trigger.

Audit rows may be tenant-scoped or platform-scoped:

- Tenant-scoped rows require `tenant_id`.
- Platform-scoped rows must not set `tenant_id`.
- Platform-user audit rows use `actor_platform_admin_user_id` and may reference `management_session_id`.

Audit metadata must avoid secrets and should store redacted before/after values where needed.
