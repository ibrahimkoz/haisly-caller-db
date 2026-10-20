SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.guard_historical_work_reactivation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE current_revision integer; state text; active_states text[];
BEGIN
 IF NEW.customer_id IS NULL THEN RETURN NEW; END IF;
 state:=COALESCE(to_jsonb(NEW)->>'status',to_jsonb(NEW)->>'outcome_status');
 active_states:=CASE TG_TABLE_NAME
  WHEN 'cases' THEN ARRAY['open','in_progress']
  WHEN 'leads' THEN ARRAY['new','qualified']
  WHEN 'follow_up_tasks' THEN ARRAY['pending','in_progress','snoozed']
  WHEN 'handoff_requests' THEN ARRAY['requested','assigned','accepted']
  WHEN 'workflow_runs' THEN ARRAY['queued','running','waiting']
  WHEN 'external_object_references' THEN ARRAY['pending','partial'] END;
 IF state=ANY(active_states) THEN
  SELECT identity_revision INTO STRICT current_revision FROM public.customers
   WHERE tenant_id=NEW.tenant_id AND id=NEW.customer_id FOR SHARE;
  IF current_revision<>NEW.customer_identity_revision THEN
   RAISE EXCEPTION 'Historical identity work cannot be reactivated' USING ERRCODE='23514',CONSTRAINT='caller_history_identity_guard';
  END IF;
 END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE tab text; BEGIN
 FOREACH tab IN ARRAY ARRAY['cases','leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references'] LOOP
  EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.guard_historical_work_reactivation()',tab||'_guard_reactivation',tab);
 END LOOP;
END $$;

-- Calls and identity correction share the tenant lock, including the gap where no interaction exists yet.
CREATE FUNCTION public.guard_historical_call_reactivation() RETURNS trigger LANGUAGE plpgsql AS $$
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
CREATE TRIGGER calls_guard_identity_reactivation BEFORE INSERT OR UPDATE ON public.calls FOR EACH ROW EXECUTE FUNCTION public.guard_historical_call_reactivation();
CREATE TRIGGER call_sessions_guard_identity_reactivation BEFORE INSERT OR UPDATE ON public.call_sessions FOR EACH ROW EXECUTE FUNCTION public.guard_historical_call_reactivation();
