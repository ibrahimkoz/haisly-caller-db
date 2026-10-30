SET LOCAL lock_timeout='5s';
-- Serialize admission with expiry/cancellation. Submission has its independent
-- current-state guard; historical provider outcomes must remain processable.
CREATE FUNCTION public.guard_dispatch_active_target() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 PERFORM id FROM public.caller_campaign_targets
  WHERE tenant_id=NEW.tenant_id AND id=NEW.target_id AND state='held' FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'New dispatch requires an open campaign target.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_dispatch_active_target_guard BEFORE INSERT
 ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.guard_dispatch_active_target();
