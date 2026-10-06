CREATE TABLE public.ai_agent_settings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  greeting_message text NOT NULL DEFAULT '',
  instructions text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_agent_settings_public_id_unique UNIQUE (public_id),
  CONSTRAINT ai_agent_settings_tenant_unique UNIQUE (tenant_id),
  CONSTRAINT ai_agent_settings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT ai_agent_settings_greeting_length_check CHECK (
    char_length(greeting_message) <= 2000
  ),
  CONSTRAINT ai_agent_settings_instructions_length_check CHECK (
    char_length(instructions) <= 50000
  )
);

CREATE INDEX ai_agent_settings_tenant_updated_at_idx
  ON public.ai_agent_settings (tenant_id, updated_at DESC);

DROP INDEX IF EXISTS public.routing_rules_tenant_agent_status_idx;

ALTER TABLE public.routing_rules
  DROP CONSTRAINT IF EXISTS routing_rules_agent_tenant_fk,
  ALTER COLUMN ai_agent_id DROP NOT NULL,
  ADD CONSTRAINT routing_rules_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE SET NULL;

CREATE INDEX routing_rules_tenant_agent_status_idx
  ON public.routing_rules (tenant_id, ai_agent_id, status)
  WHERE ai_agent_id IS NOT NULL;
