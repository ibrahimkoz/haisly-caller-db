SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_ai_session_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF NEW.session_status=1 AND EXISTS(
  SELECT 1 FROM public.customers c JOIN public.contact_identity_revisions r ON r.customer_id=c.id AND r.tenant_id=c.tenant_id
  WHERE c.tenant_id=NEW.tenant_id AND r.valid_until>=NEW.created_at AND c.canonical_phone IS NOT NULL
   AND right(c.canonical_phone,10)=right(regexp_replace(COALESCE(NEW.data->>'caller',''),'[^0-9]','','g'),10)
 ) THEN
  RAISE EXCEPTION 'Old AI session requires identity reconciliation' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ai_call_sessions_guard_identity BEFORE INSERT OR UPDATE ON public.ai_call_sessions
 FOR EACH ROW EXECUTE FUNCTION public.guard_ai_session_identity();
