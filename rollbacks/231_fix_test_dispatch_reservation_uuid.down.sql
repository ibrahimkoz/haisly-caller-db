SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.guard_test_dispatch_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE selected record; now_at timestamptz;
BEGIN
 IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'Test dispatch history is immutable' USING ERRCODE='23514'; END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN RAISE EXCEPTION 'Test dispatch requires READ COMMITTED' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 now_at:=clock_timestamp();
 IF TG_OP='INSERT' THEN
  SELECT n.canonical_phone,t.timezone INTO selected FROM public.caller_test_numbers n
   JOIN public.tenants t ON t.id=n.tenant_id AND t.status='active' AND t.deleted_at IS NULL
   JOIN public.caller_release_artifacts a ON a.id=NEW.release_artifact_id AND a.tenant_id=n.tenant_id
   JOIN public.caller_campaign_snapshots snapshot ON snapshot.id=a.snapshot_id AND snapshot.tenant_id=a.tenant_id
   JOIN public.telephony_provider_accounts p ON p.id=NEW.provider_account_id AND p.tenant_id=n.tenant_id AND p.tenant_environment_id=a.tenant_environment_id AND p.status='active'
   JOIN public.billing_reservations r ON r.id=NEW.reservation_id AND r.tenant_id=n.tenant_id AND r.purpose='test' AND r.state='held' AND r.campaign_id=snapshot.campaign_id AND r.reference_key=NEW.request_key::text
   WHERE n.id=NEW.test_number_id AND n.tenant_id=NEW.tenant_id AND n.state='active';
  IF NOT FOUND OR NEW.canonical_phone<>selected.canonical_phone THEN RAISE EXCEPTION 'Test dispatch source binding invalid' USING ERRCODE='23514'; END IF;
  IF NEW.state<>'prepared' OR NEW.version<>1 THEN RAISE EXCEPTION 'Test dispatch must start prepared' USING ERRCODE='23514'; END IF;
  NEW.tenant_timezone:=selected.timezone; NEW.quota_date:=(now_at AT TIME ZONE selected.timezone)::date; NEW.created_at:=now_at;
  -- Unresolved submissions from earlier dates continue to consume today's quota.
  IF (SELECT count(*) FROM public.caller_test_dispatch_intents WHERE tenant_id=NEW.tenant_id AND
    (state IN ('prepared','submitting','uncertain') OR (state IN ('accepted','ended') AND accepted_at >= (NEW.quota_date::timestamp AT TIME ZONE NEW.tenant_timezone) AND accepted_at < ((NEW.quota_date+1)::timestamp AT TIME ZONE NEW.tenant_timezone))))>=20 THEN
   RAISE EXCEPTION 'Daily test dispatch quota exhausted' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.test_number_id,NEW.release_artifact_id,NEW.provider_account_id,NEW.reservation_id,NEW.canonical_phone,NEW.request_key,NEW.request_hash,NEW.tenant_timezone,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.test_number_id,OLD.release_artifact_id,OLD.provider_account_id,OLD.reservation_id,OLD.canonical_phone,OLD.request_key,OLD.request_hash,OLD.tenant_timezone,OLD.created_at) THEN
   RAISE EXCEPTION 'Test dispatch source identity is immutable' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.state='prepared' AND NEW.state IN ('submitting','canceled')) OR
    (OLD.state IN ('submitting','uncertain') AND NEW.state IN ('uncertain','accepted','ended','rejected') AND OLD.state<>NEW.state) OR
    (OLD.state='accepted' AND NEW.state='ended')) THEN
   RAISE EXCEPTION 'Invalid test dispatch transition' USING ERRCODE='23514'; END IF;
  IF OLD.accepted_at IS NOT NULL AND (NEW.accepted_at,NEW.provider_call_ref) IS DISTINCT FROM (OLD.accepted_at,OLD.provider_call_ref) THEN
   RAISE EXCEPTION 'Test dispatch acceptance binding is immutable' USING ERRCODE='23514'; END IF;
  NEW.quota_date:=CASE WHEN NEW.accepted_at IS NOT NULL THEN (NEW.accepted_at AT TIME ZONE NEW.tenant_timezone)::date ELSE OLD.quota_date END;
  NEW.version:=OLD.version+1;
 END IF;
 IF NEW.accepted_at>now_at OR NEW.ended_at>now_at THEN RAISE EXCEPTION 'Test dispatch evidence cannot be in the future' USING ERRCODE='23514'; END IF;
 NEW.updated_at:=now_at;
 RETURN NEW;
END $$;
