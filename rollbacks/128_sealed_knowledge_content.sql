SET LOCAL lock_timeout = '5s';
LOCK TABLE public.knowledge_source_versions,public.knowledge_chunks IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.knowledge_source_versions WHERE sealed_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Sealed knowledge versions exist; use a forward fix.';
 END IF;
END $$;
DROP TRIGGER sealed_knowledge_chunk_guard ON public.knowledge_chunks;
DROP FUNCTION public.guard_sealed_knowledge_chunk();
DROP TRIGGER knowledge_content_seal_guard ON public.knowledge_source_versions;
DROP FUNCTION public.guard_knowledge_content_seal();
ALTER TABLE public.knowledge_source_versions DROP CONSTRAINT knowledge_seal_fields_check,
 DROP COLUMN sealed_at, DROP COLUMN ingest_format, DROP COLUMN normalized_bytes;
