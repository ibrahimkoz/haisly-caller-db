DROP INDEX IF EXISTS public.audit_logs_management_session_created_at_idx;
DROP INDEX IF EXISTS public.audit_logs_platform_actor_created_at_idx;

ALTER TABLE public.audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_single_human_actor_check,
  DROP CONSTRAINT IF EXISTS audit_logs_platform_actor_required_check,
  DROP CONSTRAINT IF EXISTS audit_logs_management_session_fk,
  DROP CONSTRAINT IF EXISTS audit_logs_actor_platform_admin_user_fk,
  DROP COLUMN IF EXISTS management_session_id,
  DROP COLUMN IF EXISTS actor_platform_admin_user_id;

DROP INDEX IF EXISTS public.platform_admin_role_permissions_permission_idx;
DROP TABLE IF EXISTS public.platform_admin_role_permissions;

DROP INDEX IF EXISTS public.platform_admin_permissions_category_code_idx;
DROP TABLE IF EXISTS public.platform_admin_permissions;

DROP INDEX IF EXISTS public.platform_admin_refresh_tokens_family_status_idx;
DROP INDEX IF EXISTS public.platform_admin_refresh_tokens_user_status_expires_at_idx;
DROP TABLE IF EXISTS public.platform_admin_refresh_tokens;

DROP INDEX IF EXISTS public.platform_admin_sessions_status_last_seen_idx;
DROP INDEX IF EXISTS public.platform_admin_sessions_user_status_expires_at_idx;
DROP TABLE IF EXISTS public.platform_admin_sessions;

DROP INDEX IF EXISTS public.platform_admin_credentials_user_status_idx;
DROP TABLE IF EXISTS public.platform_admin_credentials;

ALTER TABLE public.platform_admin_users
  DROP CONSTRAINT IF EXISTS platform_admin_users_last_seen_after_created_check,
  DROP CONSTRAINT IF EXISTS platform_admin_users_first_login_after_created_check,
  DROP COLUMN IF EXISTS last_seen_at,
  DROP COLUMN IF EXISTS first_login_completed_at,
  DROP COLUMN IF EXISTS password_setup_required;
