CREATE OR REPLACE FUNCTION public.guard_related_customer_identity(
 tenant bigint, person bigint, revision integer, fields jsonb
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE key text; target text; ref_id bigint; linked_person bigint; linked_revision integer; call_ref bigint; identity_boundary timestamptz; relation text; call_column text; mismatched boolean;
BEGIN
 FOREACH key IN ARRAY ARRAY['call_id','source_call_id','call_session_id','case_id','source_case_id','lead_id','workflow_run_id'] LOOP
  ref_id := (fields->>key)::bigint;
  IF ref_id IS NULL THEN CONTINUE; END IF;
  IF key IN ('call_id','source_call_id','call_session_id') THEN
   call_ref:=ref_id;
   IF key='call_session_id' THEN
    SELECT call_id INTO call_ref FROM public.call_sessions WHERE id=ref_id AND tenant_id=tenant;
   END IF;
   PERFORM 1 FROM public.calls WHERE id=call_ref AND tenant_id=tenant FOR UPDATE;
   SELECT max(valid_until) INTO identity_boundary FROM public.contact_identity_revisions WHERE tenant_id=tenant AND customer_id=person;
   IF identity_boundary IS NOT NULL AND EXISTS(SELECT 1 FROM public.calls c WHERE c.id=call_ref AND c.tenant_id=tenant AND c.started_at<identity_boundary) THEN
    RAISE EXCEPTION 'Call predates the current identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
   IF EXISTS(SELECT 1 FROM public.customer_interactions i WHERE i.tenant_id=tenant AND i.call_id=call_ref AND
       (i.customer_id<>person OR i.customer_identity_revision<>revision)) THEN
    RAISE EXCEPTION 'Related call belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
   -- Serialize first identity associations too, even before a call interaction exists.
   FOREACH relation IN ARRAY ARRAY['cases','leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
    call_column:=CASE WHEN relation IN ('cases','leads') THEN 'source_call_id' ELSE 'call_id' END;
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I h WHERE h.tenant_id=$1 AND h.%I=$2 AND h.customer_id IS NOT NULL AND (h.customer_id<>$3 OR h.customer_identity_revision<>$4))',relation,call_column)
     INTO mismatched USING tenant,call_ref,person,revision;
    IF mismatched THEN RAISE EXCEPTION 'Call has another historical identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard'; END IF;
    IF relation IN ('handoff_requests','consent_records') THEN
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I h JOIN public.call_sessions s ON s.id=h.call_session_id AND s.tenant_id=h.tenant_id WHERE h.tenant_id=$1 AND s.call_id=$2 AND h.customer_id IS NOT NULL AND (h.customer_id<>$3 OR h.customer_identity_revision<>$4))',relation)
      INTO mismatched USING tenant,call_ref,person,revision;
     IF mismatched THEN RAISE EXCEPTION 'Call session has another historical identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard'; END IF;
    END IF;
   END LOOP;
  ELSE
   target:=CASE WHEN key IN ('case_id','source_case_id') THEN 'cases' WHEN key='lead_id' THEN 'leads' ELSE 'workflow_runs' END;
   EXECUTE format('SELECT customer_id,customer_identity_revision FROM public.%I WHERE id=$1 AND tenant_id=$2 FOR SHARE',target)
    INTO linked_person,linked_revision USING ref_id,tenant;
   IF linked_person IS NOT NULL AND (linked_person<>person OR linked_revision<>revision) THEN
    RAISE EXCEPTION 'Related resource belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  END IF;
 END LOOP;
END $$;

CREATE FUNCTION public.guard_lead_conversion_history() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE relation text; mismatched boolean;
BEGIN
 IF OLD.customer_id IS NULL AND NEW.customer_id IS NOT NULL THEN
  FOREACH relation IN ARRAY ARRAY['follow_up_tasks','handoff_requests','workflow_runs','external_object_references'] LOOP
   EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I h WHERE h.tenant_id=$1 AND h.lead_id=$2 AND h.customer_id IS NOT NULL AND (h.customer_id<>$3 OR h.customer_identity_revision<>$4))',relation)
    INTO mismatched USING NEW.tenant_id,NEW.id,NEW.customer_id,NEW.customer_identity_revision;
   IF mismatched THEN RAISE EXCEPTION 'Lead dependents belong to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard'; END IF;
  END LOOP;
 END IF;
 RETURN NEW;
END $$;
-- Runs after leads_snapshot_identity has assigned the revision.
CREATE TRIGGER leads_validate_conversion_history BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.guard_lead_conversion_history();
