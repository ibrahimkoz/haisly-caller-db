-- Deploy the API version that reads published agent_config_versions first.
-- This contract migration intentionally removes the legacy tenant-wide copy.
DROP TABLE IF EXISTS public.ai_agent_settings;

ALTER TABLE public.ai_agents
  DROP COLUMN IF EXISTS instructions;
