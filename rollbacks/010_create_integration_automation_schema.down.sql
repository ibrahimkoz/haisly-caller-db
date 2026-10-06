DROP INDEX IF EXISTS public.automation_rules_tenant_integration_status_idx;
DROP INDEX IF EXISTS public.automation_rules_tenant_status_trigger_idx;

DROP TABLE IF EXISTS public.automation_rules;

DROP INDEX IF EXISTS public.integration_mappings_tenant_entity_status_idx;
DROP INDEX IF EXISTS public.integration_mappings_tenant_integration_status_idx;

DROP TABLE IF EXISTS public.integration_mappings;

DROP INDEX IF EXISTS public.integrations_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.integrations;
