-- Retire the generic simulation editor; preserve campaign release test evidence.
SET LOCAL lock_timeout='5s';
DROP TABLE public.simulation_run_events;
DROP TABLE public.simulation_assertions;
DELETE FROM public.simulation_runs r
WHERE NOT EXISTS (SELECT 1 FROM public.caller_release_simulation_results e WHERE e.simulation_run_id=r.id AND e.tenant_id=r.tenant_id)
 AND NOT EXISTS (SELECT 1 FROM public.background_jobs j WHERE j.tenant_id=r.tenant_id AND j.payload->>'simulation_run_public_id'=r.public_id::text)
 AND r.metadata->>'suite_version' IS DISTINCT FROM 'caller-publication-v1';
DELETE FROM public.simulation_scenarios s
WHERE NOT EXISTS (SELECT 1 FROM public.simulation_runs r WHERE r.simulation_scenario_id=s.id AND r.tenant_id=s.tenant_id)
 AND s.metadata->>'suite_version' IS DISTINCT FROM 'caller-publication-v1';
COMMENT ON TABLE public.simulation_scenarios IS 'Shared scenario storage for campaign release testing. Generic simulation editor and APIs retired.';
COMMENT ON TABLE public.simulation_runs IS 'Shared run storage for campaign release testing. Generic simulation editor and APIs retired.';
