DROP TRIGGER IF EXISTS agent_config_versions_prevent_template_version_mutation
  ON public.agent_config_versions;
DROP FUNCTION IF EXISTS public.prevent_agent_config_template_version_mutation();

DROP TRIGGER IF EXISTS agent_config_section_values_validate_mutation
  ON public.agent_config_section_values;
DROP FUNCTION IF EXISTS public.validate_agent_config_section_value_mutation();

DROP TABLE IF EXISTS public.agent_config_section_values;

DROP INDEX IF EXISTS public.agent_config_versions_industry_template_version_idx;
ALTER TABLE public.agent_config_versions
  DROP CONSTRAINT IF EXISTS agent_config_versions_industry_template_version_fk,
  DROP COLUMN IF EXISTS industry_agent_template_version_id;

DROP TABLE IF EXISTS public.industry_agent_template_sections;
DROP TABLE IF EXISTS public.industry_agent_template_versions;
DROP TABLE IF EXISTS public.industry_agent_templates;
