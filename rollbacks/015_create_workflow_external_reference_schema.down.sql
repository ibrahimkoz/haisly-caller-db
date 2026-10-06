DROP INDEX IF EXISTS public.external_object_references_tenant_workflow_run_occurred_idx;
DROP INDEX IF EXISTS public.external_object_references_tenant_source_entity_occurred_idx;

DROP TABLE IF EXISTS public.external_object_references;

DROP INDEX IF EXISTS public.workflow_step_runs_tenant_status_created_at_idx;
DROP INDEX IF EXISTS public.workflow_step_runs_run_status_step_idx;

DROP TABLE IF EXISTS public.workflow_step_runs;

DROP INDEX IF EXISTS public.workflow_runs_tenant_template_version_status_idx;
DROP INDEX IF EXISTS public.workflow_runs_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.workflow_runs;

DROP INDEX IF EXISTS public.tenant_workflow_bindings_tenant_env_status_priority_idx;
DROP INDEX IF EXISTS public.tenant_workflow_bindings_agent_scope_unique_idx;
DROP INDEX IF EXISTS public.tenant_workflow_bindings_tenant_scope_unique_idx;

DROP TABLE IF EXISTS public.tenant_workflow_bindings;

DROP INDEX IF EXISTS public.workflow_template_versions_template_status_version_idx;
DROP INDEX IF EXISTS public.workflow_template_versions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.workflow_template_versions;

DROP INDEX IF EXISTS public.workflow_templates_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.workflow_templates;
