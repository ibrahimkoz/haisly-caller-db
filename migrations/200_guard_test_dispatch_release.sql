SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_dispatch_intents d JOIN public.billing_reservations r ON r.id=d.reservation_id AND r.tenant_id=d.tenant_id WHERE r.state='released' AND d.state<>'canceled') THEN
  RAISE EXCEPTION 'Released reservation has non-canceled dispatch history; reconcile before migration.';
 END IF;
END $$;
CREATE FUNCTION public.guard_submitted_test_dispatch_release() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_reservations r JOIN public.caller_test_dispatch_intents d ON d.reservation_id=r.id AND d.tenant_id=r.tenant_id
  WHERE r.id=NEW.id AND r.state='released' AND d.state<>'canceled') THEN
  RAISE EXCEPTION 'Submitted test dispatch cannot release cost as unsubmitted; verified final cost is required.' USING ERRCODE='23514';
 END IF;
 RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER caller_test_dispatch_release_guard AFTER UPDATE ON public.billing_reservations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.guard_submitted_test_dispatch_release();
