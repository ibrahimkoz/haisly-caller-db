CREATE TABLE public.integrations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  provider text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  connection_mode text,
  credentials_ref text,
  configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_tested_at timestamptz,
  last_success_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT integrations_public_id_unique UNIQUE (public_id),
  CONSTRAINT integrations_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT integrations_tenant_provider_name_unique UNIQUE (tenant_id, provider, name),
  CONSTRAINT integrations_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT integrations_provider_not_blank_check CHECK (btrim(provider) <> ''),
  CONSTRAINT integrations_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT integrations_status_check CHECK (status IN (
    'draft',
    'active',
    'paused',
    'error',
    'disabled'
  )),
  CONSTRAINT integrations_connection_mode_not_blank_check CHECK (
    connection_mode IS NULL OR btrim(connection_mode) <> ''
  ),
  CONSTRAINT integrations_credentials_ref_not_blank_check CHECK (
    credentials_ref IS NULL OR btrim(credentials_ref) <> ''
  ),
  CONSTRAINT integrations_configuration_object_check CHECK (jsonb_typeof(configuration) = 'object'),
  CONSTRAINT integrations_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX integrations_tenant_status_updated_at_idx
  ON public.integrations (tenant_id, status, updated_at DESC);

CREATE TABLE public.integration_mappings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint NOT NULL,
  entity_type text NOT NULL,
  source_field text NOT NULL,
  target_field text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  transform_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT integration_mappings_public_id_unique UNIQUE (public_id),
  CONSTRAINT integration_mappings_integration_entity_source_unique UNIQUE (
    integration_id,
    entity_type,
    source_field
  ),
  CONSTRAINT integration_mappings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT integration_mappings_integration_tenant_fk FOREIGN KEY (integration_id, tenant_id)
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT integration_mappings_entity_type_not_blank_check CHECK (btrim(entity_type) <> ''),
  CONSTRAINT integration_mappings_source_field_not_blank_check CHECK (btrim(source_field) <> ''),
  CONSTRAINT integration_mappings_target_field_not_blank_check CHECK (btrim(target_field) <> ''),
  CONSTRAINT integration_mappings_status_check CHECK (status IN (
    'active',
    'inactive'
  )),
  CONSTRAINT integration_mappings_transform_object_check CHECK (jsonb_typeof(transform_config) = 'object'),
  CONSTRAINT integration_mappings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX integration_mappings_tenant_integration_status_idx
  ON public.integration_mappings (tenant_id, integration_id, status, updated_at DESC);

CREATE INDEX integration_mappings_tenant_entity_status_idx
  ON public.integration_mappings (tenant_id, entity_type, status);

CREATE TABLE public.automation_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  integration_id bigint,
  run_as_user_id bigint,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  trigger_type text NOT NULL,
  trigger_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  action_type text NOT NULL,
  action_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_run_at timestamptz,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT automation_rules_public_id_unique UNIQUE (public_id),
  CONSTRAINT automation_rules_tenant_name_unique UNIQUE (tenant_id, name),
  CONSTRAINT automation_rules_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT automation_rules_integration_tenant_fk FOREIGN KEY (integration_id, tenant_id)
    REFERENCES public.integrations (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT automation_rules_run_as_user_tenant_fk FOREIGN KEY (run_as_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT automation_rules_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT automation_rules_status_check CHECK (status IN (
    'draft',
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT automation_rules_trigger_type_not_blank_check CHECK (btrim(trigger_type) <> ''),
  CONSTRAINT automation_rules_action_type_not_blank_check CHECK (btrim(action_type) <> ''),
  CONSTRAINT automation_rules_trigger_object_check CHECK (jsonb_typeof(trigger_config) = 'object'),
  CONSTRAINT automation_rules_action_object_check CHECK (jsonb_typeof(action_config) = 'object'),
  CONSTRAINT automation_rules_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX automation_rules_tenant_status_trigger_idx
  ON public.automation_rules (tenant_id, status, trigger_type, updated_at DESC);

CREATE INDEX automation_rules_tenant_integration_status_idx
  ON public.automation_rules (tenant_id, integration_id, status)
  WHERE integration_id IS NOT NULL;
