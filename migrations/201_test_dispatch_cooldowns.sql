SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_test_dispatch_cooldown() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE now_at timestamptz;
BEGIN
 IF current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Test cooldown requires READ COMMITTED' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 now_at:=clock_timestamp();
 IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_intents WHERE tenant_id=NEW.tenant_id AND canonical_phone=NEW.canonical_phone AND ended_at>now_at-interval '5 minutes') THEN
  RAISE EXCEPTION 'Test number cooldown has not elapsed' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND canonical_phone=NEW.canonical_phone AND ended_at>now_at-interval '24 hours') THEN
  RAISE EXCEPTION 'Production call cooldown blocks test dispatch' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.caller_inbound_completions WHERE tenant_id=NEW.tenant_id AND caller_phone=NEW.canonical_phone AND conversation_kind='human' AND completed_at>now_at-interval '24 hours') THEN
  RAISE EXCEPTION 'Inbound human cooldown blocks test dispatch' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_01_test_cooldown_guard BEFORE INSERT ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_cooldown();
COMMENT ON FUNCTION public.guard_test_dispatch_cooldown() IS 'Preparation guard for known authoritative history only. Final sender must recheck current history, contact policy, ownership and calling window.';
