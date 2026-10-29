SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_shared_outbound_phone_admission() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('transaction_isolation')<>'read committed' THEN
  RAISE EXCEPTION 'Phone admission requires READ COMMITTED isolation' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 IF TG_TABLE_NAME='caller_dispatch_intents' THEN
  IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_intents WHERE tenant_id=NEW.tenant_id AND canonical_phone=NEW.canonical_phone AND state IN ('prepared','submitting','uncertain','accepted')) THEN
   RAISE EXCEPTION 'Open test dispatch blocks production phone admission' USING ERRCODE='23514'; END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM public.caller_dispatch_intents WHERE tenant_id=NEW.tenant_id AND canonical_phone=NEW.canonical_phone AND state IN ('prepared','submitting','uncertain','accepted')) THEN
   RAISE EXCEPTION 'Open production dispatch blocks test phone admission' USING ERRCODE='23514'; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM public.caller_inbound_bindings b WHERE b.tenant_id=NEW.tenant_id AND b.caller_phone=NEW.canonical_phone
  AND NOT EXISTS(SELECT 1 FROM public.caller_inbound_completions c WHERE c.tenant_id=b.tenant_id AND c.inbound_binding_id=b.id)) THEN
  RAISE EXCEPTION 'Unresolved inbound call blocks outbound phone admission' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
-- Sort before existing source guards to acquire the shared tenant lock first.
CREATE TRIGGER caller_00_phone_admission_guard BEFORE INSERT ON public.caller_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_shared_outbound_phone_admission();
CREATE TRIGGER caller_00_phone_admission_guard BEFORE INSERT ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_shared_outbound_phone_admission();
COMMENT ON FUNCTION public.guard_shared_outbound_phone_admission() IS 'Serializes production/test preparations per tenant and blocks unresolved bound inbound calls. Does not replace legacy/unbound call reconciliation, ownership, DNC, timing, budget or final provider admission.';
