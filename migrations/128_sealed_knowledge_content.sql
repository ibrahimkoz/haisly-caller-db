SET LOCAL lock_timeout = '5s';
ALTER TABLE public.knowledge_source_versions
 ADD COLUMN sealed_at timestamptz,
 ADD COLUMN ingest_format text,
 ADD COLUMN normalized_bytes integer,
 ADD CONSTRAINT knowledge_seal_fields_check CHECK (COALESCE((
  (sealed_at IS NULL AND ingest_format IS NULL AND normalized_bytes IS NULL)
  OR (sealed_at IS NOT NULL AND ingest_format IN ('text','pdf','docx','csv','xlsx','https')
      AND normalized_bytes BETWEEN 1 AND 10485760 AND content_checksum ~ '^[a-f0-9]{64}$')
 ), false));
CREATE FUNCTION public.guard_knowledge_content_seal() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE n bigint; lo integer; hi integer; bytes bigint; invalid bigint; body text;
BEGIN
 IF TG_OP = 'DELETE' THEN
  IF OLD.sealed_at IS NOT NULL THEN RAISE EXCEPTION 'Sealed knowledge content is immutable.' USING ERRCODE='23514'; END IF;
  RETURN OLD;
 END IF;
 IF TG_OP = 'INSERT' THEN
  IF NEW.sealed_at IS NOT NULL OR NEW.ingest_format IS NOT NULL OR NEW.normalized_bytes IS NOT NULL THEN
   RAISE EXCEPTION 'Knowledge content must be ingested before sealing.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF OLD.sealed_at IS NOT NULL THEN
  IF NEW.status NOT IN ('published','archived') OR (OLD.status='archived' AND NEW.status<>'archived') THEN
   RAISE EXCEPTION 'Sealed knowledge versions cannot be reopened as drafts.' USING ERRCODE='23514';
  END IF;
  IF (to_jsonb(NEW) - ARRAY['status','archived_at','updated_at']) IS DISTINCT FROM
     (to_jsonb(OLD) - ARRAY['status','archived_at','updated_at']) THEN
   RAISE EXCEPTION 'Sealed knowledge content is immutable.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF NEW.sealed_at IS NULL THEN RETURN NEW; END IF;
 IF NEW.ingest_format IS NULL OR NEW.status <> 'published' THEN
  RAISE EXCEPTION 'Sealing requires a format and published version.' USING ERRCODE='23514';
 END IF;
 SELECT count(*), min(chunk_index), max(chunk_index), sum(octet_length(content)),
   count(*) FILTER (WHERE content_hash IS DISTINCT FROM encode(digest(content,'sha256'),'hex'))
 INTO n,lo,hi,bytes,invalid FROM public.knowledge_chunks
 WHERE tenant_id=NEW.tenant_id AND knowledge_source_version_id=NEW.id;
 IF n < 1 OR n > 4096 OR lo <> 0 OR hi <> n-1 OR bytes > 10485760 OR invalid <> 0 THEN
  RAISE EXCEPTION 'Knowledge chunks are incomplete or invalid.' USING ERRCODE='23514';
 END IF;
 SELECT string_agg(content,'' ORDER BY chunk_index) INTO body FROM public.knowledge_chunks
 WHERE tenant_id=NEW.tenant_id AND knowledge_source_version_id=NEW.id;
 NEW.content_checksum := encode(digest(body,'sha256'),'hex');
 NEW.normalized_bytes := bytes;
 NEW.sealed_at := clock_timestamp();
 NEW.published_at := NEW.sealed_at;
 RETURN NEW;
END;
$$;
CREATE TRIGGER knowledge_content_seal_guard BEFORE INSERT OR UPDATE OR DELETE ON public.knowledge_source_versions
 FOR EACH ROW EXECUTE FUNCTION public.guard_knowledge_content_seal();
CREATE FUNCTION public.guard_sealed_knowledge_chunk() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE sealed timestamptz; version_id bigint; scope_id bigint;
BEGIN
 IF TG_OP='UPDATE' AND (NEW.knowledge_source_version_id,NEW.tenant_id) IS DISTINCT FROM (OLD.knowledge_source_version_id,OLD.tenant_id) THEN
  RAISE EXCEPTION 'Knowledge chunk ownership is immutable.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN version_id:=OLD.knowledge_source_version_id; scope_id:=OLD.tenant_id;
 ELSE version_id:=NEW.knowledge_source_version_id; scope_id:=NEW.tenant_id; END IF;
 SELECT sealed_at INTO sealed FROM public.knowledge_source_versions
 WHERE id=version_id AND tenant_id=scope_id FOR UPDATE;
 IF sealed IS NOT NULL THEN RAISE EXCEPTION 'Sealed knowledge chunks are immutable.' USING ERRCODE='23514'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER sealed_knowledge_chunk_guard BEFORE INSERT OR UPDATE OR DELETE ON public.knowledge_chunks
 FOR EACH ROW EXECUTE FUNCTION public.guard_sealed_knowledge_chunk();
