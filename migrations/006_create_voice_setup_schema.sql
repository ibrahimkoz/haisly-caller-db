CREATE TABLE public.ai_agents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  language text NOT NULL DEFAULT 'en',
  model_provider text NOT NULL,
  model_name text NOT NULL,
  voice_name text,
  instructions text,
  fallback_behavior text,
  max_concurrent_calls integer NOT NULL DEFAULT 1,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_agents_public_id_unique UNIQUE (public_id),
  CONSTRAINT ai_agents_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT ai_agents_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT ai_agents_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT ai_agents_status_check CHECK (status IN (
    'draft',
    'active',
    'inactive'
  )),
  CONSTRAINT ai_agents_language_not_blank_check CHECK (btrim(language) <> ''),
  CONSTRAINT ai_agents_model_provider_not_blank_check CHECK (btrim(model_provider) <> ''),
  CONSTRAINT ai_agents_model_name_not_blank_check CHECK (btrim(model_name) <> ''),
  CONSTRAINT ai_agents_voice_name_not_blank_check CHECK (
    voice_name IS NULL OR btrim(voice_name) <> ''
  ),
  CONSTRAINT ai_agents_fallback_behavior_not_blank_check CHECK (
    fallback_behavior IS NULL OR btrim(fallback_behavior) <> ''
  ),
  CONSTRAINT ai_agents_max_concurrent_calls_check CHECK (
    max_concurrent_calls > 0 AND max_concurrent_calls <= 10000
  ),
  CONSTRAINT ai_agents_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX ai_agents_tenant_status_created_at_idx
  ON public.ai_agents (tenant_id, status, created_at DESC);

CREATE TABLE public.phone_numbers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  phone_number text NOT NULL,
  display_name text,
  status text NOT NULL DEFAULT 'active',
  provider text,
  provider_phone_number_ref text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT phone_numbers_public_id_unique UNIQUE (public_id),
  CONSTRAINT phone_numbers_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT phone_numbers_tenant_phone_unique UNIQUE (tenant_id, phone_number),
  CONSTRAINT phone_numbers_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT phone_numbers_phone_number_e164_check CHECK (
    phone_number ~ '^\+[1-9][0-9]{7,14}$'
  ),
  CONSTRAINT phone_numbers_display_name_not_blank_check CHECK (
    display_name IS NULL OR btrim(display_name) <> ''
  ),
  CONSTRAINT phone_numbers_status_check CHECK (status IN (
    'active',
    'inactive',
    'suspended'
  )),
  CONSTRAINT phone_numbers_provider_not_blank_check CHECK (
    provider IS NULL OR btrim(provider) <> ''
  ),
  CONSTRAINT phone_numbers_provider_ref_not_blank_check CHECK (
    provider_phone_number_ref IS NULL OR btrim(provider_phone_number_ref) <> ''
  ),
  CONSTRAINT phone_numbers_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX phone_numbers_tenant_provider_ref_unique_idx
  ON public.phone_numbers (tenant_id, provider_phone_number_ref)
  WHERE provider_phone_number_ref IS NOT NULL;

CREATE INDEX phone_numbers_tenant_status_idx
  ON public.phone_numbers (tenant_id, status, created_at DESC);

CREATE TABLE public.routing_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  phone_number_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  match_expression text,
  fallback_action text NOT NULL DEFAULT 'reject',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT routing_rules_public_id_unique UNIQUE (public_id),
  CONSTRAINT routing_rules_phone_priority_unique UNIQUE (phone_number_id, priority),
  CONSTRAINT routing_rules_tenant_rule_name_unique UNIQUE (tenant_id, name),
  CONSTRAINT routing_rules_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT routing_rules_phone_tenant_fk FOREIGN KEY (phone_number_id, tenant_id)
    REFERENCES public.phone_numbers (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT routing_rules_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT routing_rules_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT routing_rules_status_check CHECK (status IN (
    'active',
    'inactive'
  )),
  CONSTRAINT routing_rules_priority_positive_check CHECK (priority > 0),
  CONSTRAINT routing_rules_match_expression_not_blank_check CHECK (
    match_expression IS NULL OR btrim(match_expression) <> ''
  ),
  CONSTRAINT routing_rules_fallback_action_check CHECK (fallback_action IN (
    'reject',
    'voicemail',
    'transfer_human'
  )),
  CONSTRAINT routing_rules_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX routing_rules_tenant_phone_status_priority_idx
  ON public.routing_rules (tenant_id, phone_number_id, status, priority ASC);

CREATE INDEX routing_rules_tenant_agent_status_idx
  ON public.routing_rules (tenant_id, ai_agent_id, status);
