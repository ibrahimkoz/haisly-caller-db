SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_test_submission_capacity_policy() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE platform_limit integer; tenant_limit integer; provider_limit integer;
BEGIN
 IF NOT (OLD.state='prepared' AND NEW.state='submitting') THEN RETURN NEW; END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Test capacity admission requires READ COMMITTED isolation' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-shared-capacity',0));
 SELECT hard_limit INTO platform_limit FROM public.caller_capacity_policies WHERE scope='platform';
 SELECT requested_limit INTO tenant_limit FROM public.caller_capacity_policies WHERE scope='tenant' AND tenant_id=NEW.tenant_id;
 SELECT hard_limit INTO provider_limit FROM public.caller_capacity_policies WHERE scope='provider'
  AND tenant_id=NEW.tenant_id AND provider_account_id=NEW.provider_account_id;
 IF platform_limit IS NULL OR tenant_limit IS NULL OR provider_limit IS NULL
  OR platform_limit<1 OR tenant_limit<1 OR provider_limit<1 THEN
  RAISE EXCEPTION 'Current capacity policy blocks test submission' USING ERRCODE='23514'; END IF;
 -- The source already owns a claim: equality is allowed; do not count it twice.
 IF (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held')>platform_limit
  OR (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id)>tenant_limit
  OR (SELECT count(*) FROM public.caller_capacity_claims WHERE state='held' AND tenant_id=NEW.tenant_id
      AND provider_account_id=NEW.provider_account_id)>provider_limit THEN
  RAISE EXCEPTION 'Current capacity policy blocks test submission' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_025_test_submission_capacity_policy BEFORE UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_submission_capacity_policy();
COMMENT ON FUNCTION public.guard_test_submission_capacity_policy() IS 'Recheck current shared limits against registered held claims before first test submission, counting own held claim once. Legacy/unclaimed occupancy still requires final admission serialization.';
