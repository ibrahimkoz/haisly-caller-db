-- Downgrade only with identity association writers paused; restores 079 behavior.
DROP TRIGGER leads_validate_conversion_history ON public.leads;
DROP FUNCTION public.guard_lead_conversion_history();
CREATE OR REPLACE FUNCTION public.guard_related_customer_identity(
 tenant bigint, person bigint, revision integer, fields jsonb
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE key text; target text; ref_id bigint; linked_person bigint; linked_revision integer; call_ref bigint; identity_boundary timestamptz;
BEGIN
 FOREACH key IN ARRAY ARRAY['call_id','source_call_id','call_session_id','case_id','source_case_id','lead_id','workflow_run_id'] LOOP
  ref_id := (fields->>key)::bigint;
  IF ref_id IS NULL THEN CONTINUE; END IF;
  IF key IN ('call_id','source_call_id','call_session_id') THEN
   call_ref:=ref_id;
   IF key='call_session_id' THEN
    SELECT call_id INTO call_ref FROM public.call_sessions WHERE id=ref_id AND tenant_id=tenant;
   END IF;
   SELECT max(valid_until) INTO identity_boundary FROM public.contact_identity_revisions WHERE tenant_id=tenant AND customer_id=person;
   IF identity_boundary IS NOT NULL AND EXISTS(SELECT 1 FROM public.calls c WHERE c.id=call_ref AND c.tenant_id=tenant AND c.started_at<identity_boundary) THEN
    RAISE EXCEPTION 'Call predates the current identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
   IF EXISTS(SELECT 1 FROM public.customer_interactions i WHERE i.tenant_id=tenant AND i.call_id=call_ref AND
       (i.customer_id<>person OR i.customer_identity_revision<>revision)) THEN
    RAISE EXCEPTION 'Related call belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  ELSE
   target:=CASE WHEN key IN ('case_id','source_case_id') THEN 'cases' WHEN key='lead_id' THEN 'leads' ELSE 'workflow_runs' END;
   EXECUTE format('SELECT customer_id,customer_identity_revision FROM public.%I WHERE id=$1 AND tenant_id=$2',target)
    INTO linked_person,linked_revision USING ref_id,tenant;
   IF linked_person IS NOT NULL AND (linked_person<>person OR linked_revision<>revision) THEN
    RAISE EXCEPTION 'Related resource belongs to another identity' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
   END IF;
  END IF;
 END LOOP;
END $$;
