CREATE TABLE public.business_hours_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  policy_name text NOT NULL,
  timezone text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  weekly_schedule jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_hours_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT business_hours_policies_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT business_hours_policies_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    policy_name
  ),
  CONSTRAINT business_hours_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT business_hours_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT business_hours_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT business_hours_policies_name_not_blank_check CHECK (btrim(policy_name) <> ''),
  CONSTRAINT business_hours_policies_timezone_not_blank_check CHECK (btrim(timezone) <> ''),
  CONSTRAINT business_hours_policies_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT business_hours_policies_schedule_object_check CHECK (jsonb_typeof(weekly_schedule) = 'object'),
  CONSTRAINT business_hours_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX business_hours_policies_tenant_env_status_idx
  ON public.business_hours_policies (tenant_id, tenant_environment_id, status);

CREATE TABLE public.holiday_calendars (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  business_hours_policy_id bigint,
  calendar_name text NOT NULL,
  country_code text,
  status text NOT NULL DEFAULT 'active',
  holiday_dates jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT holiday_calendars_public_id_unique UNIQUE (public_id),
  CONSTRAINT holiday_calendars_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    calendar_name
  ),
  CONSTRAINT holiday_calendars_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT holiday_calendars_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT holiday_calendars_business_hours_tenant_fk FOREIGN KEY (business_hours_policy_id, tenant_id)
    REFERENCES public.business_hours_policies (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT holiday_calendars_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT holiday_calendars_name_not_blank_check CHECK (btrim(calendar_name) <> ''),
  CONSTRAINT holiday_calendars_country_not_blank_check CHECK (
    country_code IS NULL OR btrim(country_code) <> ''
  ),
  CONSTRAINT holiday_calendars_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT holiday_calendars_holidays_array_check CHECK (jsonb_typeof(holiday_dates) = 'array'),
  CONSTRAINT holiday_calendars_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX holiday_calendars_tenant_env_status_idx
  ON public.holiday_calendars (tenant_id, tenant_environment_id, status);

CREATE TABLE public.sla_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  policy_name text NOT NULL,
  target_entity_type text NOT NULL,
  response_time_minutes integer,
  resolution_time_minutes integer,
  status text NOT NULL DEFAULT 'active',
  rules_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sla_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT sla_policies_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT sla_policies_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    policy_name
  ),
  CONSTRAINT sla_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT sla_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT sla_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT sla_policies_name_not_blank_check CHECK (btrim(policy_name) <> ''),
  CONSTRAINT sla_policies_entity_type_check CHECK (target_entity_type IN (
    'call',
    'case',
    'lead',
    'handoff_request'
  )),
  CONSTRAINT sla_policies_response_time_positive_check CHECK (
    response_time_minutes IS NULL OR response_time_minutes > 0
  ),
  CONSTRAINT sla_policies_resolution_time_positive_check CHECK (
    resolution_time_minutes IS NULL OR resolution_time_minutes > 0
  ),
  CONSTRAINT sla_policies_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT sla_policies_rules_object_check CHECK (jsonb_typeof(rules_config) = 'object'),
  CONSTRAINT sla_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX sla_policies_tenant_env_status_entity_idx
  ON public.sla_policies (tenant_id, tenant_environment_id, status, target_entity_type);

CREATE TABLE public.escalation_policies (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  sla_policy_id bigint,
  policy_name text NOT NULL,
  trigger_type text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  step_config jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT escalation_policies_public_id_unique UNIQUE (public_id),
  CONSTRAINT escalation_policies_tenant_env_name_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    policy_name
  ),
  CONSTRAINT escalation_policies_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT escalation_policies_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT escalation_policies_sla_policy_tenant_fk FOREIGN KEY (sla_policy_id, tenant_id)
    REFERENCES public.sla_policies (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT escalation_policies_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT escalation_policies_name_not_blank_check CHECK (btrim(policy_name) <> ''),
  CONSTRAINT escalation_policies_trigger_type_not_blank_check CHECK (btrim(trigger_type) <> ''),
  CONSTRAINT escalation_policies_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT escalation_policies_step_array_check CHECK (jsonb_typeof(step_config) = 'array'),
  CONSTRAINT escalation_policies_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX escalation_policies_tenant_env_status_trigger_idx
  ON public.escalation_policies (tenant_id, tenant_environment_id, status, trigger_type);
