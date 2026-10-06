DROP INDEX IF EXISTS public.routing_rules_tenant_agent_status_idx;
DROP INDEX IF EXISTS public.routing_rules_tenant_phone_status_priority_idx;

DROP TABLE IF EXISTS public.routing_rules;

DROP INDEX IF EXISTS public.phone_numbers_tenant_status_idx;
DROP INDEX IF EXISTS public.phone_numbers_tenant_provider_ref_unique_idx;

DROP TABLE IF EXISTS public.phone_numbers;

DROP INDEX IF EXISTS public.ai_agents_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.ai_agents;
