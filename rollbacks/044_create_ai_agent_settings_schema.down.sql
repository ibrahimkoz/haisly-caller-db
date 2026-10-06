DROP INDEX IF EXISTS public.routing_rules_tenant_agent_status_idx;

ALTER TABLE public.routing_rules
  DROP CONSTRAINT IF EXISTS routing_rules_agent_tenant_fk,
  ALTER COLUMN ai_agent_id SET NOT NULL,
  ADD CONSTRAINT routing_rules_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE RESTRICT;

CREATE INDEX routing_rules_tenant_agent_status_idx
  ON public.routing_rules (tenant_id, ai_agent_id, status);

DROP INDEX IF EXISTS public.ai_agent_settings_tenant_updated_at_idx;
DROP TABLE IF EXISTS public.ai_agent_settings;
