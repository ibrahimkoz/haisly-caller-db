ALTER TABLE public.ai_agents
  ADD COLUMN IF NOT EXISTS instructions text;

CREATE TABLE IF NOT EXISTS public.ai_agent_settings (
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

CREATE INDEX IF NOT EXISTS ai_agent_settings_tenant_updated_at_idx
  ON public.ai_agent_settings (tenant_id, updated_at DESC);
