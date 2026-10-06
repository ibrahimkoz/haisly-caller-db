DROP INDEX IF EXISTS public.idempotency_keys_tenant_state_created_at_idx;
DROP INDEX IF EXISTS public.idempotency_keys_tenant_scope_expires_at_idx;

DROP TABLE IF EXISTS public.idempotency_keys;

DROP INDEX IF EXISTS public.service_account_keys_tenant_status_expires_at_idx;
DROP INDEX IF EXISTS public.service_account_keys_service_status_created_at_idx;

DROP TABLE IF EXISTS public.service_account_keys;

DROP INDEX IF EXISTS public.service_account_scopes_tenant_scope_effect_idx;

DROP TABLE IF EXISTS public.service_account_scopes;

DROP INDEX IF EXISTS public.service_accounts_tenant_environment_status_idx;
DROP INDEX IF EXISTS public.service_accounts_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.service_accounts;

DROP INDEX IF EXISTS public.tenant_environments_tenant_status_updated_at_idx;
DROP INDEX IF EXISTS public.tenant_environments_single_default_idx;

DROP TABLE IF EXISTS public.tenant_environments;
