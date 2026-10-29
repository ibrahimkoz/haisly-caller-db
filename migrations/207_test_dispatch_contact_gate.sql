SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_test_dispatch_contact() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE contact_row record; status_blocks boolean;
BEGIN
 IF TG_OP='UPDATE' AND NOT (OLD.state='prepared' AND NEW.state='submitting') THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT c.* INTO contact_row FROM public.customers c
 WHERE c.tenant_id=NEW.tenant_id AND c.canonical_phone=NEW.canonical_phone FOR SHARE;
 IF NOT FOUND THEN RETURN NEW; END IF;
 SELECT s.blocks_calling INTO status_blocks FROM public.contact_statuses s
 WHERE s.id=contact_row.contact_status_id FOR SHARE;
 IF contact_row.do_not_call_at IS NOT NULL OR contact_row.archived_at IS NOT NULL
  OR contact_row.status IS DISTINCT FROM 'active' OR contact_row.contact_state IS DISTINCT FROM 'ready'
  OR status_blocks IS DISTINCT FROM FALSE OR contact_row.country_code IS NULL OR contact_row.country_code=''
 THEN RAISE EXCEPTION 'Test number contact restrictions block admission' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_02_test_dispatch_contact BEFORE INSERT OR UPDATE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_contact();
COMMENT ON FUNCTION public.guard_test_dispatch_contact() IS 'Canonical tenant contact restrictions apply to test intent insertion and first submission; no contact does not imply ownership proof or final dispatch authorization.';
