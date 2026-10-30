SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_production_submission_capacity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE platform_limit integer; tenant_limit integer; provider_limit integer; campaign_limit integer;
BEGIN
 IF NOT (OLD.state='prepared' AND NEW.state='submitting') THEN RETURN NEW; END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Production capacity admission requires READ COMMITTED isolation' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-shared-capacity',0));
 PERFORM 1 FROM public.caller_capacity_claims
  WHERE tenant_id=NEW.tenant_id AND dispatch_id=NEW.id AND provider_account_id=NEW.provider_account_id
   AND campaign_id=NEW.campaign_id AND state='held' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Production submission requires a held capacity claim' USING ERRCODE='23514'; END IF;
 SELECT hard_limit INTO platform_limit FROM public.caller_capacity_policies WHERE scope='platform';
 SELECT requested_limit INTO tenant_limit FROM public.caller_capacity_policies WHERE scope='tenant' AND tenant_id=NEW.tenant_id;
 SELECT hard_limit INTO provider_limit FROM public.caller_capacity_policies
  WHERE scope='provider' AND tenant_id=NEW.tenant_id AND provider_account_id=NEW.provider_account_id;
 SELECT (document->'settings'->>'requested_concurrency')::integer INTO campaign_limit
  FROM public.caller_campaign_snapshots WHERE tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id AND id=NEW.snapshot_id;
 IF platform_limit IS NULL OR tenant_limit IS NULL OR provider_limit IS NULL OR campaign_limit IS NULL
  OR platform_limit<1 OR tenant_limit<1 OR provider_limit<1 OR campaign_limit<1 THEN
  RAISE EXCEPTION 'Current capacity policy blocks production submission' USING ERRCODE='23514'; END IF;
 -- Own held claim is already counted. Equality must not charge another slot.
 IF (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held')>platform_limit
  OR (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id)>tenant_limit
  OR (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id AND provider_account_id=NEW.provider_account_id)>provider_limit
  OR (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id AND campaign_id=NEW.campaign_id)>campaign_limit THEN
  RAISE EXCEPTION 'Current capacity policy blocks production submission' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_025_production_submission_capacity BEFORE UPDATE ON public.caller_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_production_submission_capacity();
COMMENT ON FUNCTION public.guard_production_submission_capacity() IS 'Requires own held claim and current registered-claim limits. Does not certify legacy/unclaimed occupancy. Existing unclaimed prepared requests require reconciliation or cancellation; no fabricated automatic backfill.';
