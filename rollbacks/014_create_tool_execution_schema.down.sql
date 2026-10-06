DROP INDEX IF EXISTS public.tool_execution_runs_tenant_idempotency_idx;
DROP INDEX IF EXISTS public.tool_execution_runs_tenant_tool_version_status_idx;
DROP INDEX IF EXISTS public.tool_execution_runs_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.tool_execution_runs;

DROP INDEX IF EXISTS public.tenant_tool_bindings_tenant_env_status_priority_idx;
DROP INDEX IF EXISTS public.tenant_tool_bindings_agent_scope_unique_idx;
DROP INDEX IF EXISTS public.tenant_tool_bindings_tenant_scope_unique_idx;

DROP TABLE IF EXISTS public.tenant_tool_bindings;

DROP INDEX IF EXISTS public.tool_versions_definition_status_version_idx;
DROP INDEX IF EXISTS public.tool_versions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.tool_versions;

DROP INDEX IF EXISTS public.tool_definitions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.tool_definitions;
