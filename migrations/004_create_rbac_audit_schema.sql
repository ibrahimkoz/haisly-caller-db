CREATE TABLE public.roles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT roles_public_id_unique UNIQUE (public_id),
  CONSTRAINT roles_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT roles_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT roles_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT roles_code_format_check CHECK (code ~ '^[a-z][a-z0-9_]{1,79}$'),
  CONSTRAINT roles_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT roles_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT roles_status_check CHECK (status IN ('active', 'disabled'))
);

CREATE INDEX roles_tenant_status_idx
  ON public.roles (tenant_id, status);

CREATE TABLE public.permissions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permissions_public_id_unique UNIQUE (public_id),
  CONSTRAINT permissions_code_unique UNIQUE (code),
  CONSTRAINT permissions_code_format_check CHECK (code ~ '^[a-z][a-z0-9_.:]{1,119}$'),
  CONSTRAINT permissions_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT permissions_category_not_blank_check CHECK (btrim(category) <> ''),
  CONSTRAINT permissions_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  )
);

CREATE INDEX permissions_category_code_idx
  ON public.permissions (category, code);

CREATE TABLE public.role_permissions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  role_id bigint NOT NULL,
  permission_id bigint NOT NULL,
  granted_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT role_permissions_public_id_unique UNIQUE (public_id),
  CONSTRAINT role_permissions_role_permission_unique UNIQUE (role_id, permission_id),
  CONSTRAINT role_permissions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT role_permissions_role_tenant_fk FOREIGN KEY (role_id, tenant_id)
    REFERENCES public.roles (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT role_permissions_permission_id_fk FOREIGN KEY (permission_id)
    REFERENCES public.permissions (id)
    ON DELETE CASCADE,
  CONSTRAINT role_permissions_granted_by_user_tenant_fk FOREIGN KEY (
    granted_by_user_id,
    tenant_id
  )
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT
);

CREATE INDEX role_permissions_tenant_role_idx
  ON public.role_permissions (tenant_id, role_id);

CREATE INDEX role_permissions_permission_id_idx
  ON public.role_permissions (permission_id);

CREATE TABLE public.user_roles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  user_id bigint NOT NULL,
  role_id bigint NOT NULL,
  assigned_by_user_id bigint,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CONSTRAINT user_roles_public_id_unique UNIQUE (public_id),
  CONSTRAINT user_roles_user_role_unique UNIQUE (user_id, role_id),
  CONSTRAINT user_roles_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT user_roles_user_tenant_fk FOREIGN KEY (user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT user_roles_role_tenant_fk FOREIGN KEY (role_id, tenant_id)
    REFERENCES public.roles (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT user_roles_assigned_by_user_tenant_fk FOREIGN KEY (
    assigned_by_user_id,
    tenant_id
  )
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT user_roles_status_check CHECK (status IN ('active', 'revoked')),
  CONSTRAINT user_roles_revoked_timestamp_check CHECK (
    status <> 'revoked' OR revoked_at IS NOT NULL
  )
);

CREATE INDEX user_roles_tenant_user_status_idx
  ON public.user_roles (tenant_id, user_id, status);

CREATE INDEX user_roles_tenant_role_status_idx
  ON public.user_roles (tenant_id, role_id, status);

CREATE TABLE public.audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  scope_type text NOT NULL DEFAULT 'tenant',
  tenant_id bigint,
  actor_type text NOT NULL,
  actor_user_id bigint,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_public_id uuid,
  category text NOT NULL DEFAULT 'general',
  severity text NOT NULL DEFAULT 'info',
  request_id text,
  ip_address inet,
  user_agent text,
  before_values jsonb,
  after_values jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_public_id_unique UNIQUE (public_id),
  CONSTRAINT audit_logs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE RESTRICT,
  CONSTRAINT audit_logs_actor_user_tenant_fk FOREIGN KEY (actor_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT audit_logs_scope_type_check CHECK (scope_type IN ('tenant', 'platform')),
  CONSTRAINT audit_logs_scope_tenant_check CHECK (
    (scope_type = 'tenant' AND tenant_id IS NOT NULL)
    OR (scope_type = 'platform' AND tenant_id IS NULL)
  ),
  CONSTRAINT audit_logs_actor_type_check CHECK (actor_type IN (
    'tenant_user',
    'platform_user',
    'service_account',
    'system'
  )),
  CONSTRAINT audit_logs_action_not_blank_check CHECK (btrim(action) <> ''),
  CONSTRAINT audit_logs_entity_type_not_blank_check CHECK (btrim(entity_type) <> ''),
  CONSTRAINT audit_logs_category_not_blank_check CHECK (btrim(category) <> ''),
  CONSTRAINT audit_logs_severity_check CHECK (severity IN (
    'info',
    'warning',
    'critical'
  )),
  CONSTRAINT audit_logs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT audit_logs_before_values_object_check CHECK (
    before_values IS NULL OR jsonb_typeof(before_values) = 'object'
  ),
  CONSTRAINT audit_logs_after_values_object_check CHECK (
    after_values IS NULL OR jsonb_typeof(after_values) = 'object'
  )
);

COMMENT ON TABLE public.audit_logs IS
  'Append-only audit event table. Application code must not update or delete rows; trigger audit_logs_prevent_mutation enforces this at the database layer.';

CREATE INDEX audit_logs_tenant_created_at_idx
  ON public.audit_logs (tenant_id, created_at DESC)
  WHERE tenant_id IS NOT NULL;

CREATE INDEX audit_logs_actor_user_created_at_idx
  ON public.audit_logs (actor_user_id, created_at DESC)
  WHERE actor_user_id IS NOT NULL;

CREATE INDEX audit_logs_entity_created_at_idx
  ON public.audit_logs (entity_type, entity_public_id, created_at DESC);

CREATE INDEX audit_logs_action_created_at_idx
  ON public.audit_logs (action, created_at DESC);

CREATE FUNCTION public.prevent_audit_logs_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only and cannot be updated or deleted';
END;
$$;

CREATE TRIGGER audit_logs_prevent_mutation
  BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_audit_logs_mutation();
