BEGIN;

UPDATE public.industry_agent_template_sections AS section
SET
  validation_schema = section.validation_schema #- '{properties,currencies,items,pattern}',
  updated_at = now()
FROM public.industry_agent_template_versions AS template_version
JOIN public.industry_agent_templates AS template
  ON template.id = template_version.industry_agent_template_id
WHERE section.industry_agent_template_version_id = template_version.id
  AND template.code = 'hotel_guest_assistant'
  AND template_version.version_no = 1
  AND section.section_key = 'payment_cancellation'
  AND section.validation_schema #>> '{properties,currencies,items,pattern}' = '^[A-Z]{3}$';

COMMIT;
