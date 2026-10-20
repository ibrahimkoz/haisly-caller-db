SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.guard_historical_call_reactivation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE call_key bigint; tab text; field text; stale boolean; session_key bigint; predicate text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_TABLE_NAME='calls' THEN
  IF NEW.status NOT IN ('ringing','in_progress') THEN RETURN NEW; END IF;
  call_key:=NEW.id;
 ELSE
  IF NEW.status NOT IN ('initiated','active','handoff') THEN RETURN NEW; END IF;
  call_key:=NEW.call_id;
  session_key:=NEW.id;
 END IF;
 FOREACH tab IN ARRAY ARRAY['customer_interactions','cases','leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  field:=CASE WHEN tab IN ('cases','leads') THEN 'source_call_id' ELSE 'call_id' END;
  predicate:=format('r.%I=$2',field);
  IF tab IN ('handoff_requests','consent_records') THEN
   predicate:=predicate||' OR r.call_session_id=$3 OR r.call_session_id IN (SELECT id FROM public.call_sessions WHERE tenant_id=$1 AND call_id=$2)';
  END IF;
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I r JOIN public.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id WHERE r.tenant_id=$1 AND (%s) AND r.customer_identity_revision<>c.identity_revision)',tab,predicate)
   INTO stale USING NEW.tenant_id,call_key,session_key;
  IF stale THEN RAISE EXCEPTION 'Historical identity call cannot be reactivated' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
