DROP INDEX IF EXISTS public.secret_rotation_events_tenant_status_requested_at_idx;
DROP INDEX IF EXISTS public.secret_rotation_events_secret_status_requested_at_idx;

DROP TABLE IF EXISTS public.secret_rotation_events;

DROP INDEX IF EXISTS public.secret_references_tenant_env_type_status_idx;
DROP INDEX IF EXISTS public.secret_references_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.secret_references;
