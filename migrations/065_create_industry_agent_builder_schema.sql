CREATE TABLE public.industry_agent_templates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  industry_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT industry_agent_templates_public_id_unique UNIQUE (public_id),
  CONSTRAINT industry_agent_templates_industry_code_unique UNIQUE (industry_id, code),
  CONSTRAINT industry_agent_templates_industry_id_fk FOREIGN KEY (industry_id)
    REFERENCES public.industries (id)
    ON DELETE RESTRICT,
  CONSTRAINT industry_agent_templates_code_format_check CHECK (
    code ~ '^[a-z][a-z0-9_]{1,79}$'
  ),
  CONSTRAINT industry_agent_templates_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT industry_agent_templates_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT industry_agent_templates_status_check CHECK (status IN (
    'active',
    'inactive',
    'deprecated'
  )),
  CONSTRAINT industry_agent_templates_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX industry_agent_templates_industry_status_code_idx
  ON public.industry_agent_templates (industry_id, status, code);

CREATE TABLE public.industry_agent_template_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  industry_agent_template_id bigint NOT NULL,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  change_summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT industry_agent_template_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT industry_agent_template_versions_template_version_unique UNIQUE (
    industry_agent_template_id,
    version_no
  ),
  CONSTRAINT industry_agent_template_versions_template_id_fk FOREIGN KEY (industry_agent_template_id)
    REFERENCES public.industry_agent_templates (id)
    ON DELETE CASCADE,
  CONSTRAINT industry_agent_template_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT industry_agent_template_versions_status_check CHECK (status IN (
    'draft',
    'active',
    'retired'
  )),
  CONSTRAINT industry_agent_template_versions_change_summary_not_blank_check CHECK (
    change_summary IS NULL OR btrim(change_summary) <> ''
  ),
  CONSTRAINT industry_agent_template_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX industry_agent_template_versions_one_active_idx
  ON public.industry_agent_template_versions (industry_agent_template_id)
  WHERE status = 'active';

CREATE TABLE public.industry_agent_template_sections (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  industry_agent_template_version_id bigint NOT NULL,
  section_key text NOT NULL,
  title text NOT NULL,
  description text,
  sort_order integer NOT NULL,
  is_required boolean NOT NULL DEFAULT true,
  validation_schema jsonb NOT NULL DEFAULT '{}'::jsonb,
  ui_schema jsonb NOT NULL DEFAULT '{}'::jsonb,
  compiler_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT industry_agent_template_sections_public_id_unique UNIQUE (public_id),
  CONSTRAINT industry_agent_template_sections_version_key_unique UNIQUE (
    industry_agent_template_version_id,
    section_key
  ),
  CONSTRAINT industry_agent_template_sections_version_order_unique UNIQUE (
    industry_agent_template_version_id,
    sort_order
  ),
  CONSTRAINT industry_agent_template_sections_template_version_id_fk FOREIGN KEY (
    industry_agent_template_version_id
  ) REFERENCES public.industry_agent_template_versions (id)
    ON DELETE CASCADE,
  CONSTRAINT industry_agent_template_sections_key_format_check CHECK (
    section_key ~ '^[a-z][a-z0-9_]{1,79}$'
  ),
  CONSTRAINT industry_agent_template_sections_title_not_blank_check CHECK (btrim(title) <> ''),
  CONSTRAINT industry_agent_template_sections_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT industry_agent_template_sections_sort_order_non_negative_check CHECK (sort_order >= 0),
  CONSTRAINT industry_agent_template_sections_validation_schema_object_check CHECK (
    jsonb_typeof(validation_schema) = 'object'
  ),
  CONSTRAINT industry_agent_template_sections_ui_schema_object_check CHECK (
    jsonb_typeof(ui_schema) = 'object'
  ),
  CONSTRAINT industry_agent_template_sections_compiler_config_object_check CHECK (
    jsonb_typeof(compiler_config) = 'object'
  )
);

ALTER TABLE public.agent_config_versions
  ADD COLUMN industry_agent_template_version_id bigint,
  ADD CONSTRAINT agent_config_versions_industry_template_version_fk FOREIGN KEY (
    industry_agent_template_version_id
  ) REFERENCES public.industry_agent_template_versions (id)
    ON DELETE RESTRICT;

CREATE INDEX agent_config_versions_industry_template_version_idx
  ON public.agent_config_versions (industry_agent_template_version_id)
  WHERE industry_agent_template_version_id IS NOT NULL;

CREATE TABLE public.agent_config_section_values (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  agent_config_version_id bigint NOT NULL,
  industry_agent_template_section_id bigint NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_config_section_values_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_config_section_values_version_section_unique UNIQUE (
    agent_config_version_id,
    industry_agent_template_section_id
  ),
  CONSTRAINT agent_config_section_values_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_section_values_version_tenant_fk FOREIGN KEY (
    agent_config_version_id,
    tenant_id
  ) REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_section_values_template_section_id_fk FOREIGN KEY (
    industry_agent_template_section_id
  ) REFERENCES public.industry_agent_template_sections (id)
    ON DELETE RESTRICT,
  CONSTRAINT agent_config_section_values_payload_object_check CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX agent_config_section_values_tenant_version_idx
  ON public.agent_config_section_values (tenant_id, agent_config_version_id, updated_at DESC);

CREATE OR REPLACE FUNCTION public.validate_agent_config_section_value_mutation()
RETURNS trigger AS $$
DECLARE
  target_agent_config_version_id bigint;
  config_status text;
  config_template_version_id bigint;
  section_template_version_id bigint;
BEGIN
  target_agent_config_version_id := COALESCE(NEW.agent_config_version_id, OLD.agent_config_version_id);

  SELECT status, industry_agent_template_version_id
    INTO config_status, config_template_version_id
  FROM public.agent_config_versions
  WHERE id = target_agent_config_version_id;

  IF config_status IS NULL THEN
    RAISE EXCEPTION 'Agent config version does not exist.';
  END IF;

  IF config_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft agent config sections can be changed.';
  END IF;

  IF TG_OP <> 'DELETE' THEN
    IF config_template_version_id IS NULL THEN
      RAISE EXCEPTION 'Agent config version has no industry template version.';
    END IF;

    SELECT industry_agent_template_version_id
      INTO section_template_version_id
    FROM public.industry_agent_template_sections
    WHERE id = NEW.industry_agent_template_section_id;

    IF section_template_version_id IS DISTINCT FROM config_template_version_id THEN
      RAISE EXCEPTION 'Agent config section does not belong to the selected industry template version.';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_config_section_values_validate_mutation
BEFORE INSERT OR UPDATE OR DELETE ON public.agent_config_section_values
FOR EACH ROW EXECUTE FUNCTION public.validate_agent_config_section_value_mutation();

CREATE OR REPLACE FUNCTION public.prevent_agent_config_template_version_mutation()
RETURNS trigger AS $$
BEGIN
  IF OLD.status <> 'draft'
    AND NEW.industry_agent_template_version_id IS DISTINCT FROM OLD.industry_agent_template_version_id
  THEN
    RAISE EXCEPTION 'Non-draft agent config template versions are immutable.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_config_versions_prevent_template_version_mutation
BEFORE UPDATE ON public.agent_config_versions
FOR EACH ROW EXECUTE FUNCTION public.prevent_agent_config_template_version_mutation();

WITH hotel_template AS (
  INSERT INTO public.industry_agent_templates (
    industry_id,
    code,
    name,
    description,
    status
  )
  SELECT
    id,
    'hotel_guest_assistant',
    'Otel Misafir Asistanı',
    'Konaklama işletmeleri için misafir iletişimi ve tesis bilgisi yapılandırması.',
    'active'
  FROM public.industries
  WHERE code = 'hospitality_accommodation'
  RETURNING id
), hotel_template_version AS (
  INSERT INTO public.industry_agent_template_versions (
    industry_agent_template_id,
    version_no,
    status,
    change_summary,
    metadata
  )
  SELECT
    id,
    1,
    'active',
    'İlk otel misafir asistanı şablonu.',
    '{"schema_version":1,"locale":"tr-TR"}'::jsonb
  FROM hotel_template
  RETURNING id
)
INSERT INTO public.industry_agent_template_sections (
  industry_agent_template_version_id,
  section_key,
  title,
  description,
  sort_order,
  is_required,
  validation_schema,
  ui_schema,
  compiler_config
)
SELECT
  hotel_template_version.id,
  section.section_key,
  section.title,
  section.description,
  section.sort_order,
  section.is_required,
  section.validation_schema,
  section.ui_schema,
  section.compiler_config
FROM hotel_template_version
CROSS JOIN (
  VALUES
    (
      'agent_identity',
      'Asistan kimliği',
      'Asistanın adı, karşılama cümlesi, konuşma tonu ve desteklediği diller.',
      10,
      true,
      '{"type":"object","required":["title","greeting_message","tone"],"properties":{"title":{"type":"string","minLength":1,"maxLength":120},"greeting_message":{"type":"string","minLength":1,"maxLength":1000},"tone":{"type":"string","minLength":1,"maxLength":80},"languages":{"type":"array","items":{"type":"string","minLength":2,"maxLength":35},"maxItems":12}}}'::jsonb,
      '{"fields":[{"key":"title","control":"text"},{"key":"greeting_message","control":"textarea"},{"key":"tone","control":"text"},{"key":"languages","control":"tag-list"}]}'::jsonb,
      '{"heading":"ASİSTAN KİMLİĞİ","field_order":["title","tone","languages","greeting_message"]}'::jsonb
    ),
    (
      'hotel_identity_location',
      'Otel kimliği ve konum',
      'Tesisin sabit kimlik, iletişim ve konum bilgileri.',
      20,
      true,
      '{"type":"object","required":["hotel_name","short_name","concept","class","phone","email","address","region"],"properties":{"hotel_name":{"type":"string","minLength":1,"maxLength":180},"short_name":{"type":"string","minLength":1,"maxLength":120},"concept":{"type":"string","minLength":1,"maxLength":160},"class":{"type":"string","minLength":1,"maxLength":120},"phone":{"type":"string","minLength":3,"maxLength":120},"email":{"type":"string","format":"email","maxLength":254},"address":{"type":"string","minLength":1,"maxLength":500},"region":{"type":"string","minLength":1,"maxLength":160},"airport_distance":{"type":"string","maxLength":80},"center_distance":{"type":"string","maxLength":80},"location_description":{"type":"string","maxLength":1200}}}'::jsonb,
      '{"fields":[{"key":"hotel_name","control":"text"},{"key":"short_name","control":"text"},{"key":"concept","control":"text"},{"key":"class","control":"text"},{"key":"phone","control":"text"},{"key":"email","control":"email"},{"key":"address","control":"textarea"},{"key":"region","control":"text"},{"key":"airport_distance","control":"text"},{"key":"center_distance","control":"text"},{"key":"location_description","control":"textarea"}]}'::jsonb,
      '{"heading":"OTEL KİMLİĞİ VE KONUM","field_order":["hotel_name","short_name","concept","class","phone","email","address","region","airport_distance","center_distance","location_description"]}'::jsonb
    ),
    (
      'stay_rules',
      'Konaklama kuralları',
      'Giriş, çıkış, evcil hayvan, sigara ve esneklik kuralları.',
      30,
      true,
      '{"type":"object","required":["check_in_time","check_out_time","pet_policy","smoking_policy"],"properties":{"check_in_time":{"type":"string","minLength":1,"maxLength":30},"check_out_time":{"type":"string","minLength":1,"maxLength":30},"pet_policy":{"type":"string","minLength":1,"maxLength":500},"smoking_policy":{"type":"string","minLength":1,"maxLength":500},"early_check_in_policy":{"type":"string","maxLength":500},"late_check_out_policy":{"type":"string","maxLength":500},"additional_rules":{"type":"array","items":{"type":"string","minLength":1,"maxLength":500},"maxItems":30}}}'::jsonb,
      '{"fields":[{"key":"check_in_time","control":"text"},{"key":"check_out_time","control":"text"},{"key":"pet_policy","control":"textarea"},{"key":"smoking_policy","control":"textarea"},{"key":"early_check_in_policy","control":"textarea"},{"key":"late_check_out_policy","control":"textarea"},{"key":"additional_rules","control":"list"}]}'::jsonb,
      '{"heading":"GİRİŞ, ÇIKIŞ VE TEMEL KURALLAR","field_order":["check_in_time","check_out_time","pet_policy","smoking_policy","early_check_in_policy","late_check_out_policy","additional_rules"]}'::jsonb
    ),
    (
      'room_catalog',
      'Oda kataloğu',
      'Oda tiplerinin özellikleri; fiyat ve tarih bazlı müsaitlik bu bölümde tutulmaz.',
      40,
      true,
      '{"type":"object","required":["room_types"],"properties":{"room_types":{"type":"array","minItems":1,"maxItems":100,"items":{"type":"object","required":["code","name","description"],"properties":{"code":{"type":"string","minLength":1,"maxLength":50},"name":{"type":"string","minLength":1,"maxLength":160},"description":{"type":"string","minLength":1,"maxLength":2000}}}}}}'::jsonb,
      '{"fields":[{"key":"room_types","control":"repeater"}],"notice":"Bu katalog müsaitlik veya fiyat anlamına gelmez."}'::jsonb,
      '{"heading":"ODA KATALOĞU — MÜSAİTLİK DEĞİLDİR","field_order":["room_types"]}'::jsonb
    ),
    (
      'facilities_services',
      'Tesis ve hizmetler',
      'Yeme-içme, havuz, aktivite, transfer, internet ve diğer sabit hizmetler.',
      50,
      false,
      '{"type":"object","properties":{"room_amenities":{"type":"array","items":{"type":"string","minLength":1,"maxLength":500},"maxItems":100},"food_beverage":{"type":"array","items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":100},"pools_beach":{"type":"array","items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":50},"activities":{"type":"array","items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":100},"spa_wellness":{"type":"array","items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":50},"service_hours":{"type":"array","items":{"type":"string","minLength":1,"maxLength":500},"maxItems":100},"transfer":{"type":"string","maxLength":1200},"internet":{"type":"string","maxLength":1200},"parking":{"type":"string","maxLength":1200},"additional_services":{"type":"array","items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":100},"dietary_options":{"type":"array","items":{"type":"string","minLength":1,"maxLength":200},"maxItems":50},"nearby_places":{"type":"array","items":{"type":"string","minLength":1,"maxLength":500},"maxItems":100},"staff_languages":{"type":"array","items":{"type":"string","minLength":1,"maxLength":80},"maxItems":30},"accessibility":{"type":"string","maxLength":1500}}}'::jsonb,
      '{"fields":[{"key":"room_amenities","control":"list"},{"key":"food_beverage","control":"list"},{"key":"pools_beach","control":"list"},{"key":"activities","control":"list"},{"key":"spa_wellness","control":"list"},{"key":"service_hours","control":"list"},{"key":"transfer","control":"textarea"},{"key":"internet","control":"textarea"},{"key":"parking","control":"textarea"},{"key":"additional_services","control":"list"},{"key":"dietary_options","control":"tag-list"},{"key":"nearby_places","control":"list"},{"key":"staff_languages","control":"tag-list"},{"key":"accessibility","control":"textarea"}]}'::jsonb,
      '{"heading":"TESİS VE HİZMET BİLGİSİ","field_order":["room_amenities","food_beverage","pools_beach","activities","spa_wellness","service_hours","transfer","internet","parking","additional_services","dietary_options","nearby_places","staff_languages","accessibility"]}'::jsonb
    ),
    (
      'payment_cancellation',
      'Ödeme ve iptal',
      'Kabul edilen ödeme yöntemleri, para birimleri ve iptal politikası.',
      60,
      true,
      '{"type":"object","required":["payment_methods","currencies","cancellation_policy"],"properties":{"payment_methods":{"type":"array","minItems":1,"items":{"type":"string","minLength":1,"maxLength":80},"maxItems":30},"currencies":{"type":"array","minItems":1,"items":{"type":"string","pattern":"^[A-Z]{3}$"},"maxItems":20},"cancellation_policy":{"type":"string","minLength":1,"maxLength":2000},"payment_safety_note":{"type":"string","maxLength":1000}}}'::jsonb,
      '{"fields":[{"key":"payment_methods","control":"tag-list"},{"key":"currencies","control":"tag-list"},{"key":"cancellation_policy","control":"textarea"},{"key":"payment_safety_note","control":"textarea"}]}'::jsonb,
      '{"heading":"ÖDEME VE İPTAL","field_order":["payment_methods","currencies","cancellation_policy","payment_safety_note"]}'::jsonb
    ),
    (
      'conversation_escalation',
      'Konuşma ve insana yönlendirme',
      'Asistanın yanıt sınırları ve görüşmeyi insana devretmesi gereken durumlar.',
      70,
      true,
      '{"type":"object","required":["response_principles","handoff_conditions"],"properties":{"response_principles":{"type":"array","minItems":1,"items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":50},"handoff_conditions":{"type":"array","minItems":1,"items":{"type":"string","minLength":1,"maxLength":1000},"maxItems":50},"handoff_message":{"type":"string","maxLength":1000}}}'::jsonb,
      '{"fields":[{"key":"response_principles","control":"list"},{"key":"handoff_conditions","control":"list"},{"key":"handoff_message","control":"textarea"}]}'::jsonb,
      '{"heading":"KONUŞMA VE İNSANA YÖNLENDİRME","field_order":["response_principles","handoff_conditions","handoff_message"]}'::jsonb
    )
) AS section(
  section_key,
  title,
  description,
  sort_order,
  is_required,
  validation_schema,
  ui_schema,
  compiler_config
);

COMMENT ON TABLE public.industry_agent_templates IS
  'Global, industry-specific agent builder template catalog.';
COMMENT ON TABLE public.industry_agent_template_versions IS
  'Versioned schemas for industry agent builder templates; exactly one active version per template.';
COMMENT ON TABLE public.industry_agent_template_sections IS
  'Ordered section definitions, validation rules, UI hints, and deterministic compiler metadata.';
COMMENT ON TABLE public.agent_config_section_values IS
  'Tenant-scoped structured values belonging to a draft agent configuration version.';
COMMENT ON COLUMN public.agent_config_versions.industry_agent_template_version_id IS
  'The immutable industry template version used to author and compile this configuration.';
