DROP INDEX IF EXISTS public.agent_knowledge_bindings_tenant_env_status_priority_idx;

DROP TABLE IF EXISTS public.agent_knowledge_bindings;

DROP INDEX IF EXISTS public.knowledge_chunks_embedding_cosine_idx;
DROP INDEX IF EXISTS public.knowledge_chunks_tenant_source_created_at_idx;

DROP TABLE IF EXISTS public.knowledge_chunks;

DROP INDEX IF EXISTS public.knowledge_ingestion_jobs_tenant_status_created_at_idx;

DROP TABLE IF EXISTS public.knowledge_ingestion_jobs;

DROP INDEX IF EXISTS public.knowledge_source_versions_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.knowledge_source_versions;

DROP INDEX IF EXISTS public.knowledge_sources_tenant_collection_status_idx;

DROP TABLE IF EXISTS public.knowledge_sources;

DROP INDEX IF EXISTS public.knowledge_collections_tenant_status_updated_at_idx;

DROP TABLE IF EXISTS public.knowledge_collections;
