SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_transcript_snapshots (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 call_id bigint NOT NULL,
 version integer NOT NULL CHECK(version>0),
 request_key text NOT NULL CHECK(length(request_key) BETWEEN 8 AND 200),
 segments jsonb NOT NULL CHECK(jsonb_typeof(segments)='array' AND jsonb_array_length(segments) BETWEEN 1 AND 1000 AND octet_length(segments::text)<=2097152),
 segment_count integer NOT NULL CHECK(segment_count BETWEEN 1 AND 1000),
 content_hash text NOT NULL CHECK(content_hash ~ '^[0-9a-f]{64}$'),
 captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,runtime_binding_id,version), UNIQUE(tenant_id,runtime_binding_id,request_key),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(call_id,tenant_id) REFERENCES public.calls(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_quality_transcript_call_idx ON public.caller_quality_transcript_snapshots(tenant_id,call_id,version DESC);
CREATE FUNCTION public.guard_quality_transcript_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE bound_call bigint; count_segments bigint; bytes bigint; previous integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality transcript snapshots are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT call_id INTO bound_call FROM public.caller_call_end_snapshots
 WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quality transcript capture requires a bound call end' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.caller_runtime_release_bindings b
  JOIN public.call_sessions session ON session.id=b.call_session_id AND session.tenant_id=b.tenant_id
  WHERE b.tenant_id=NEW.tenant_id AND session.call_id=bound_call AND b.id<>NEW.runtime_binding_id) THEN
  RAISE EXCEPTION 'Quality transcript call attribution is ambiguous' USING ERRCODE='23514';
 END IF;
 SELECT count(*),coalesce(sum(octet_length(content)),0) INTO count_segments,bytes FROM public.call_transcripts
 WHERE tenant_id=NEW.tenant_id AND call_id=bound_call;
 IF count_segments=0 THEN RAISE EXCEPTION 'Quality transcript is not available' USING ERRCODE='23514'; END IF;
 IF count_segments>1000 OR bytes>1048576 THEN RAISE EXCEPTION 'Quality transcript exceeds capture limits' USING ERRCODE='23514'; END IF;
 SELECT jsonb_agg(jsonb_build_object('public_id',public_id,'segment_index',segment_index,
   'speaker_type',speaker_type,'content',content,'language',language,
   'started_at',started_at,'ended_at',ended_at) ORDER BY segment_index,id)
 INTO NEW.segments FROM public.call_transcripts WHERE tenant_id=NEW.tenant_id AND call_id=bound_call;
 NEW.segment_count:=jsonb_array_length(NEW.segments);
 NEW.call_id:=bound_call;
 NEW.content_hash:=encode(digest(NEW.segments::text,'sha256'),'hex');
 SELECT coalesce(max(version),0) INTO previous FROM public.caller_quality_transcript_snapshots
 WHERE tenant_id=NEW.tenant_id AND runtime_binding_id=NEW.runtime_binding_id;
 NEW.version:=previous+1;
 NEW.captured_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_transcript_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_transcript_snapshots
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_transcript_snapshot();
