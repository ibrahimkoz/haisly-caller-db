DROP TRIGGER IF EXISTS audit_logs_prevent_mutation ON public.audit_logs;
DROP FUNCTION IF EXISTS public.prevent_audit_logs_mutation();

DROP TABLE IF EXISTS public.audit_logs;
DROP TABLE IF EXISTS public.user_roles;
DROP TABLE IF EXISTS public.role_permissions;
DROP TABLE IF EXISTS public.permissions;
DROP TABLE IF EXISTS public.roles;
