DROP INDEX IF EXISTS public.simulation_run_events_tenant_type_occurred_at_idx;
DROP INDEX IF EXISTS public.simulation_run_events_tenant_run_occurred_at_idx;

DROP TABLE IF EXISTS public.simulation_run_events;

DROP INDEX IF EXISTS public.simulation_runs_tenant_gate_decision_completed_at_idx;
DROP INDEX IF EXISTS public.simulation_runs_tenant_scenario_created_at_idx;
DROP INDEX IF EXISTS public.simulation_runs_tenant_env_status_created_at_idx;

DROP TABLE IF EXISTS public.simulation_runs;

DROP INDEX IF EXISTS public.simulation_assertions_tenant_scenario_status_idx;

DROP TABLE IF EXISTS public.simulation_assertions;

DROP INDEX IF EXISTS public.simulation_scenarios_tenant_agent_status_idx;
DROP INDEX IF EXISTS public.simulation_scenarios_tenant_env_status_updated_at_idx;

DROP TABLE IF EXISTS public.simulation_scenarios;
