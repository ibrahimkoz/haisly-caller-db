DROP INDEX IF EXISTS public.policy_evaluation_logs_tenant_policy_occurred_at_idx;
DROP INDEX IF EXISTS public.policy_evaluation_logs_tenant_result_occurred_at_idx;

DROP TABLE IF EXISTS public.policy_evaluation_logs;

DROP INDEX IF EXISTS public.agent_guardrail_bindings_tenant_env_status_priority_idx;

DROP TABLE IF EXISTS public.agent_guardrail_bindings;

DROP INDEX IF EXISTS public.guardrail_policy_versions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.guardrail_policy_versions;

DROP INDEX IF EXISTS public.guardrail_policies_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.guardrail_policies;
