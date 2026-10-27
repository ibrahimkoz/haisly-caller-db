SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_marketing_result_revisions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 target_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 version integer NOT NULL CHECK(version>0),
 outcome text NOT NULL CHECK(outcome IN ('interested','not_interested','callback_requested','representative_requested','partial','uncertain')),
 request text CHECK(request IN ('information','quote','demo')),
 connection_outcome text NOT NULL CHECK(connection_outcome IN ('human','voicemail','unknown')),
 evidence_reference text NOT NULL CHECK(evidence_reference ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 request_key text NOT NULL CHECK(length(request_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,target_id,snapshot_id,version),
 UNIQUE(tenant_id,runtime_binding_id,request_key),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,tenant_id) ON DELETE RESTRICT,
 CHECK(request IS NULL OR outcome='interested')
);
CREATE INDEX caller_marketing_result_snapshot ON public.caller_marketing_result_revisions(tenant_id,snapshot_id);
CREATE FUNCTION public.guard_marketing_result_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous public.caller_marketing_result_revisions%ROWTYPE; accepted timestamptz;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Marketing result revisions are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT d.accepted_at INTO accepted FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=d.snapshot_id AND snap.tenant_id=d.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 WHERE b.id=NEW.runtime_binding_id AND b.tenant_id=NEW.tenant_id
 AND d.target_id=NEW.target_id AND d.snapshot_id=NEW.snapshot_id
 AND snap.document->>'campaign_type'='marketing'
 AND d.state='accepted' AND s.status='active' AND s.ended_at IS NULL
 AND c.status='in_progress' AND c.ended_at IS NULL AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 FOR SHARE OF b,d,s,c,snap,person;
 IF accepted IS NULL OR NEW.observed_at<accepted OR NEW.observed_at>clock_timestamp() THEN
  RAISE EXCEPTION 'Marketing result requires evidence from its active bound marketing call' USING ERRCODE='23514';
 END IF;
 SELECT * INTO previous FROM public.caller_marketing_result_revisions WHERE tenant_id=NEW.tenant_id AND target_id=NEW.target_id AND snapshot_id=NEW.snapshot_id ORDER BY version DESC LIMIT 1;
 IF NEW.version::bigint<>coalesce(previous.version::bigint,0)+1 OR (previous.id IS NOT NULL AND NEW.observed_at<previous.observed_at) THEN
  RAISE EXCEPTION 'Marketing result requires the next revision and ordered evidence' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_marketing_result_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_marketing_result_revisions FOR EACH ROW EXECUTE FUNCTION public.guard_marketing_result_revision();
