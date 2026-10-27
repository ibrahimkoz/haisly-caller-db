SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_marketing_result_revisions ADD COLUMN observation_phase text NOT NULL DEFAULT 'active' CHECK(observation_phase IN ('active','finalized'));
CREATE OR REPLACE FUNCTION public.guard_marketing_result_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous public.caller_marketing_result_revisions%ROWTYPE; accepted timestamptz; call_end timestamptz; session_end timestamptz;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Marketing result revisions are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT d.accepted_at,c.ended_at,s.ended_at INTO accepted,call_end,session_end FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=d.snapshot_id AND snap.tenant_id=d.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 WHERE b.id=NEW.runtime_binding_id AND b.tenant_id=NEW.tenant_id
 AND d.target_id=NEW.target_id AND d.snapshot_id=NEW.snapshot_id
 AND snap.document->>'campaign_type'='marketing'
 AND ((NEW.observation_phase='active' AND d.state='accepted') OR (NEW.observation_phase='finalized' AND d.state IN ('accepted','ended')))
 AND ((NEW.observation_phase='active' AND s.status='active' AND s.ended_at IS NULL AND c.status='in_progress' AND c.ended_at IS NULL)
   OR (NEW.observation_phase='finalized' AND s.status IN ('completed','failed','cancelled') AND s.ended_at IS NOT NULL
       AND c.status IN ('completed','failed','no_answer','busy','canceled') AND c.ended_at IS NOT NULL))
 AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 FOR SHARE OF b,d,s,c,snap,person;
 IF accepted IS NULL OR NEW.observed_at<accepted OR NEW.observed_at>clock_timestamp() OR (NEW.observation_phase='finalized' AND (NEW.observed_at>call_end OR NEW.observed_at>session_end OR call_end>clock_timestamp() OR session_end>clock_timestamp())) THEN
  RAISE EXCEPTION 'Marketing result evidence must match its bound call lifecycle and time window' USING ERRCODE='23514';
 END IF;
 SELECT * INTO previous FROM public.caller_marketing_result_revisions WHERE tenant_id=NEW.tenant_id AND target_id=NEW.target_id AND snapshot_id=NEW.snapshot_id ORDER BY version DESC LIMIT 1;
 IF NEW.version::bigint<>coalesce(previous.version::bigint,0)+1 OR (previous.id IS NOT NULL AND NEW.observed_at<previous.observed_at) THEN
  RAISE EXCEPTION 'Marketing result requires the next revision and ordered evidence' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
