SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_test_submission_reservations() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NOT (OLD.state='prepared' AND NEW.state='submitting') THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM 1 FROM public.billing_reservations r WHERE r.tenant_id=NEW.tenant_id AND r.id=NEW.reservation_id
  AND r.reference_key=NEW.request_key AND r.purpose='test' AND r.state='held' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Test submission requires held test funding' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM public.caller_capacity_claims c WHERE c.tenant_id=NEW.tenant_id AND c.test_dispatch_id=NEW.id
  AND c.provider_account_id=NEW.provider_account_id AND c.state='held' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Test submission requires a held capacity claim' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_03_test_submission_reservations BEFORE UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_submission_reservations();
COMMENT ON FUNCTION public.guard_test_submission_reservations() IS 'First test submission requires its still-held test funding and matching provider capacity claim. Does not replace policy, all-source inventory, routing or provider admission.';
