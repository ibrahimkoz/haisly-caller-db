CREATE OR REPLACE FUNCTION public.guard_historical_call_reactivation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE call_key bigint; tab text; field text; stale boolean;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_TABLE_NAME='calls' THEN
  IF NEW.status NOT IN ('ringing','in_progress') THEN RETURN NEW; END IF;
  call_key:=NEW.id;
 ELSE
  IF NEW.status NOT IN ('initiated','active','handoff') THEN RETURN NEW; END IF;
  call_key:=NEW.call_id;
 END IF;
 FOREACH tab IN ARRAY ARRAY['customer_interactions','cases','leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  field:=CASE WHEN tab IN ('cases','leads') THEN 'source_call_id' ELSE 'call_id' END;
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I r JOIN public.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id WHERE r.tenant_id=$1 AND r.%I=$2 AND r.customer_identity_revision<>c.identity_revision)',tab,field)
   INTO stale USING NEW.tenant_id,call_key;
  IF stale THEN RAISE EXCEPTION 'Historical identity call cannot be reactivated' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
