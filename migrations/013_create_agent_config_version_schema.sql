CREATE TABLE public.agent_config_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  parent_version_id bigint,
  rollback_from_version_id bigint,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  change_summary text,
  config_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  diff_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  submitted_by_user_id bigint,
  submitted_at timestamptz,
  published_by_user_id bigint,
  published_at timestamptz,
  archived_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_config_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_config_versions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT agent_config_versions_env_agent_version_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    ai_agent_id,
    version_no
  ),
  CONSTRAINT agent_config_versions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_versions_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_versions_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_versions_parent_tenant_fk FOREIGN KEY (parent_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_versions_rollback_from_tenant_fk FOREIGN KEY (rollback_from_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_versions_submitted_by_user_tenant_fk FOREIGN KEY (submitted_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_versions_published_by_user_tenant_fk FOREIGN KEY (published_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT agent_config_versions_status_check CHECK (status IN (
    'draft',
    'review',
    'published',
    'archived'
  )),
  CONSTRAINT agent_config_versions_change_summary_not_blank_check CHECK (
    change_summary IS NULL OR btrim(change_summary) <> ''
  ),
  CONSTRAINT agent_config_versions_snapshot_object_check CHECK (jsonb_typeof(config_snapshot) = 'object'),
  CONSTRAINT agent_config_versions_diff_object_check CHECK (jsonb_typeof(diff_summary) = 'object'),
  CONSTRAINT agent_config_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT agent_config_versions_submitted_pair_check CHECK (
    (submitted_by_user_id IS NULL AND submitted_at IS NULL)
    OR (submitted_by_user_id IS NOT NULL AND submitted_at IS NOT NULL)
  ),
  CONSTRAINT agent_config_versions_published_pair_check CHECK (
    (published_by_user_id IS NULL AND published_at IS NULL)
    OR (published_by_user_id IS NOT NULL AND published_at IS NOT NULL)
  ),
  CONSTRAINT agent_config_versions_archived_requires_status_check CHECK (
    archived_at IS NULL OR status = 'archived'
  )
);

CREATE INDEX agent_config_versions_tenant_env_agent_status_updated_idx
  ON public.agent_config_versions (tenant_id, tenant_environment_id, ai_agent_id, status, updated_at DESC);

CREATE INDEX agent_config_versions_tenant_status_published_at_idx
  ON public.agent_config_versions (tenant_id, status, published_at DESC);

CREATE TABLE public.agent_config_publish_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  agent_config_version_id bigint NOT NULL,
  published_version_id bigint,
  requested_by_user_id bigint NOT NULL,
  reviewer_user_id bigint,
  request_type text NOT NULL DEFAULT 'publish',
  status text NOT NULL DEFAULT 'pending',
  requested_reason text,
  decision_note text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_config_publish_requests_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_config_publish_requests_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_publish_requests_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_publish_requests_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_publish_requests_version_tenant_fk FOREIGN KEY (agent_config_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_publish_requests_published_version_tenant_fk FOREIGN KEY (published_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_publish_requests_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE RESTRICT,
  CONSTRAINT agent_config_publish_requests_reviewer_user_tenant_fk FOREIGN KEY (reviewer_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_publish_requests_type_check CHECK (request_type IN (
    'publish',
    'rollback'
  )),
  CONSTRAINT agent_config_publish_requests_status_check CHECK (status IN (
    'pending',
    'approved',
    'rejected',
    'cancelled',
    'completed'
  )),
  CONSTRAINT agent_config_publish_requests_requested_reason_not_blank_check CHECK (
    requested_reason IS NULL OR btrim(requested_reason) <> ''
  ),
  CONSTRAINT agent_config_publish_requests_decision_note_not_blank_check CHECK (
    decision_note IS NULL OR btrim(decision_note) <> ''
  ),
  CONSTRAINT agent_config_publish_requests_decision_pair_check CHECK (
    (reviewer_user_id IS NULL AND decided_at IS NULL)
    OR (reviewer_user_id IS NOT NULL AND decided_at IS NOT NULL)
  ),
  CONSTRAINT agent_config_publish_requests_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX agent_config_publish_requests_tenant_status_requested_at_idx
  ON public.agent_config_publish_requests (tenant_id, status, requested_at DESC);

CREATE INDEX agent_config_publish_requests_version_status_idx
  ON public.agent_config_publish_requests (tenant_id, agent_config_version_id, status);

CREATE UNIQUE INDEX agent_config_publish_requests_pending_per_agent_idx
  ON public.agent_config_publish_requests (tenant_id, tenant_environment_id, ai_agent_id, request_type)
  WHERE status = 'pending';

CREATE TABLE public.agent_config_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  active_version_id bigint,
  draft_version_id bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_config_bindings_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_config_bindings_tenant_env_agent_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    ai_agent_id
  ),
  CONSTRAINT agent_config_bindings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_bindings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_bindings_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_config_bindings_active_version_tenant_fk FOREIGN KEY (active_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_bindings_draft_version_tenant_fk FOREIGN KEY (draft_version_id, tenant_id)
    REFERENCES public.agent_config_versions (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_config_bindings_distinct_versions_check CHECK (
    active_version_id IS NULL
    OR draft_version_id IS NULL
    OR active_version_id <> draft_version_id
  ),
  CONSTRAINT agent_config_bindings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX agent_config_bindings_tenant_environment_updated_at_idx
  ON public.agent_config_bindings (tenant_id, tenant_environment_id, updated_at DESC);

CREATE OR REPLACE FUNCTION public.prevent_published_agent_config_snapshot_mutation()
RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'published' THEN
    IF NEW.config_snapshot IS DISTINCT FROM OLD.config_snapshot
      OR NEW.tenant_environment_id IS DISTINCT FROM OLD.tenant_environment_id
      OR NEW.ai_agent_id IS DISTINCT FROM OLD.ai_agent_id
      OR NEW.version_no IS DISTINCT FROM OLD.version_no
    THEN
      RAISE EXCEPTION 'Published agent config snapshots are immutable.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_config_versions_prevent_published_snapshot_mutation
BEFORE UPDATE ON public.agent_config_versions
FOR EACH ROW EXECUTE FUNCTION public.prevent_published_agent_config_snapshot_mutation();
