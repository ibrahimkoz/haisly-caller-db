CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE public.knowledge_collections (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_collections_public_id_unique UNIQUE (public_id),
  CONSTRAINT knowledge_collections_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT knowledge_collections_tenant_code_unique UNIQUE (tenant_id, code),
  CONSTRAINT knowledge_collections_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_collections_code_not_blank_check CHECK (btrim(code) <> ''),
  CONSTRAINT knowledge_collections_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT knowledge_collections_description_not_blank_check CHECK (
    description IS NULL OR btrim(description) <> ''
  ),
  CONSTRAINT knowledge_collections_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT knowledge_collections_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX knowledge_collections_tenant_status_updated_at_idx
  ON public.knowledge_collections (tenant_id, status, updated_at DESC);

CREATE TABLE public.knowledge_sources (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  knowledge_collection_id bigint NOT NULL,
  source_type text NOT NULL,
  source_ref text NOT NULL,
  display_name text NOT NULL,
  language text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_sources_public_id_unique UNIQUE (public_id),
  CONSTRAINT knowledge_sources_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT knowledge_sources_tenant_collection_source_unique UNIQUE (
    tenant_id,
    knowledge_collection_id,
    source_type,
    source_ref
  ),
  CONSTRAINT knowledge_sources_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_sources_collection_tenant_fk FOREIGN KEY (knowledge_collection_id, tenant_id)
    REFERENCES public.knowledge_collections (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_sources_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT knowledge_sources_source_type_check CHECK (source_type IN (
    'url',
    'document',
    'text',
    'faq',
    'api'
  )),
  CONSTRAINT knowledge_sources_source_ref_not_blank_check CHECK (btrim(source_ref) <> ''),
  CONSTRAINT knowledge_sources_display_name_not_blank_check CHECK (btrim(display_name) <> ''),
  CONSTRAINT knowledge_sources_language_not_blank_check CHECK (
    language IS NULL OR btrim(language) <> ''
  ),
  CONSTRAINT knowledge_sources_status_check CHECK (status IN (
    'active',
    'paused',
    'archived'
  )),
  CONSTRAINT knowledge_sources_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX knowledge_sources_tenant_collection_status_idx
  ON public.knowledge_sources (tenant_id, knowledge_collection_id, status);

CREATE TABLE public.knowledge_source_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  knowledge_source_id bigint NOT NULL,
  version_no integer NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  content_ref text,
  content_checksum text,
  token_count integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_source_versions_public_id_unique UNIQUE (public_id),
  CONSTRAINT knowledge_source_versions_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT knowledge_source_versions_source_version_unique UNIQUE (knowledge_source_id, version_no),
  CONSTRAINT knowledge_source_versions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_source_versions_source_tenant_fk FOREIGN KEY (knowledge_source_id, tenant_id)
    REFERENCES public.knowledge_sources (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_source_versions_version_positive_check CHECK (version_no > 0),
  CONSTRAINT knowledge_source_versions_status_check CHECK (status IN (
    'draft',
    'published',
    'archived'
  )),
  CONSTRAINT knowledge_source_versions_content_ref_not_blank_check CHECK (
    content_ref IS NULL OR btrim(content_ref) <> ''
  ),
  CONSTRAINT knowledge_source_versions_checksum_not_blank_check CHECK (
    content_checksum IS NULL OR btrim(content_checksum) <> ''
  ),
  CONSTRAINT knowledge_source_versions_token_count_non_negative_check CHECK (
    token_count IS NULL OR token_count >= 0
  ),
  CONSTRAINT knowledge_source_versions_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT knowledge_source_versions_archived_requires_status_check CHECK (
    archived_at IS NULL OR status = 'archived'
  )
);

CREATE INDEX knowledge_source_versions_tenant_status_updated_at_idx
  ON public.knowledge_source_versions (tenant_id, status, updated_at DESC);

CREATE TABLE public.knowledge_ingestion_jobs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  knowledge_source_version_id bigint NOT NULL,
  requested_by_user_id bigint,
  status text NOT NULL DEFAULT 'queued',
  chunk_count integer,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_ingestion_jobs_public_id_unique UNIQUE (public_id),
  CONSTRAINT knowledge_ingestion_jobs_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_ingestion_jobs_source_version_tenant_fk FOREIGN KEY (knowledge_source_version_id, tenant_id)
    REFERENCES public.knowledge_source_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_ingestion_jobs_requested_by_user_tenant_fk FOREIGN KEY (requested_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT knowledge_ingestion_jobs_status_check CHECK (status IN (
    'queued',
    'running',
    'completed',
    'failed',
    'cancelled'
  )),
  CONSTRAINT knowledge_ingestion_jobs_chunk_count_non_negative_check CHECK (
    chunk_count IS NULL OR chunk_count >= 0
  ),
  CONSTRAINT knowledge_ingestion_jobs_error_not_blank_check CHECK (
    error_message IS NULL OR btrim(error_message) <> ''
  ),
  CONSTRAINT knowledge_ingestion_jobs_completed_after_started_check CHECK (
    completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at
  ),
  CONSTRAINT knowledge_ingestion_jobs_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX knowledge_ingestion_jobs_tenant_status_created_at_idx
  ON public.knowledge_ingestion_jobs (tenant_id, status, created_at DESC);

CREATE TABLE public.knowledge_chunks (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  knowledge_source_version_id bigint NOT NULL,
  chunk_index integer NOT NULL,
  content text NOT NULL,
  content_hash text,
  token_count integer,
  embedding vector(1536),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_chunks_public_id_unique UNIQUE (public_id),
  CONSTRAINT knowledge_chunks_source_chunk_unique UNIQUE (knowledge_source_version_id, chunk_index),
  CONSTRAINT knowledge_chunks_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_chunks_source_version_tenant_fk FOREIGN KEY (knowledge_source_version_id, tenant_id)
    REFERENCES public.knowledge_source_versions (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT knowledge_chunks_chunk_index_non_negative_check CHECK (chunk_index >= 0),
  CONSTRAINT knowledge_chunks_content_not_blank_check CHECK (btrim(content) <> ''),
  CONSTRAINT knowledge_chunks_content_hash_not_blank_check CHECK (
    content_hash IS NULL OR btrim(content_hash) <> ''
  ),
  CONSTRAINT knowledge_chunks_token_count_non_negative_check CHECK (
    token_count IS NULL OR token_count >= 0
  ),
  CONSTRAINT knowledge_chunks_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX knowledge_chunks_tenant_source_created_at_idx
  ON public.knowledge_chunks (tenant_id, knowledge_source_version_id, created_at DESC);

CREATE INDEX knowledge_chunks_embedding_cosine_idx
  ON public.knowledge_chunks USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100)
  WHERE embedding IS NOT NULL;

CREATE TABLE public.agent_knowledge_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  tenant_environment_id bigint NOT NULL,
  ai_agent_id bigint NOT NULL,
  knowledge_collection_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'active',
  priority integer NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by_user_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agent_knowledge_bindings_public_id_unique UNIQUE (public_id),
  CONSTRAINT agent_knowledge_bindings_tenant_env_agent_collection_unique UNIQUE (
    tenant_id,
    tenant_environment_id,
    ai_agent_id,
    knowledge_collection_id
  ),
  CONSTRAINT agent_knowledge_bindings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT agent_knowledge_bindings_environment_tenant_fk FOREIGN KEY (tenant_environment_id, tenant_id)
    REFERENCES public.tenant_environments (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_knowledge_bindings_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_knowledge_bindings_collection_tenant_fk FOREIGN KEY (knowledge_collection_id, tenant_id)
    REFERENCES public.knowledge_collections (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT agent_knowledge_bindings_created_by_user_tenant_fk FOREIGN KEY (created_by_user_id, tenant_id)
    REFERENCES public.users (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT agent_knowledge_bindings_status_check CHECK (status IN (
    'active',
    'paused',
    'disabled'
  )),
  CONSTRAINT agent_knowledge_bindings_priority_non_negative_check CHECK (priority >= 0),
  CONSTRAINT agent_knowledge_bindings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX agent_knowledge_bindings_tenant_env_status_priority_idx
  ON public.agent_knowledge_bindings (tenant_id, tenant_environment_id, status, priority ASC);
