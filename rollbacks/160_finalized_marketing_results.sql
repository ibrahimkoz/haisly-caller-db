-- Do not erase provenance after finalized evidence has been stored.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_marketing_result_revisions WHERE observation_phase='finalized') THEN
  RAISE EXCEPTION 'Finalized marketing evidence exists; retain migration160 and roll forward';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.guard_marketing_result_revision() RETURNS trigger LANGUAGE plpgsql AS $$
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
ALTER TABLE public.caller_marketing_result_revisions DROP COLUMN observation_phase;
