DROP TRIGGER IF EXISTS agent_config_versions_prevent_published_snapshot_mutation
  ON public.agent_config_versions;

DROP FUNCTION IF EXISTS public.prevent_published_agent_config_snapshot_mutation();

DROP INDEX IF EXISTS public.agent_config_bindings_tenant_environment_updated_at_idx;

DROP TABLE IF EXISTS public.agent_config_bindings;

DROP INDEX IF EXISTS public.agent_config_publish_requests_pending_per_agent_idx;
DROP INDEX IF EXISTS public.agent_config_publish_requests_version_status_idx;
DROP INDEX IF EXISTS public.agent_config_publish_requests_tenant_status_requested_at_idx;

DROP TABLE IF EXISTS public.agent_config_publish_requests;

DROP INDEX IF EXISTS public.agent_config_versions_tenant_status_published_at_idx;
DROP INDEX IF EXISTS public.agent_config_versions_tenant_env_agent_status_updated_idx;

DROP TABLE IF EXISTS public.agent_config_versions;
