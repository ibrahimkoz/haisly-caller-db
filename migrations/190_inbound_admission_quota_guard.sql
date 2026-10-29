SET LOCAL lock_timeout='5s';
-- A statement lock precedes row locks for all policy writers, including legacy
-- management paths. Admission holds the shared counterpart through its pin insert.
CREATE FUNCTION public.lock_caller_quota_configuration() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-quota-configuration',0));
 RETURN NULL;
END $$;
CREATE TRIGGER caller_quota_configuration_lock BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.quota_policies FOR EACH STATEMENT EXECUTE FUNCTION public.lock_caller_quota_configuration();
CREATE FUNCTION public.guard_inbound_admission_quota() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE environment_id bigint; policy record; checked_at timestamptz; window_start timestamptz; used bigint; policy_count integer:=0; has_tenant boolean:=false;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM pg_advisory_xact_lock_shared(hashtextextended('caller-quota-configuration',0));
 SELECT tenant_environment_id INTO environment_id FROM public.caller_inbound_bindings WHERE id=NEW.inbound_binding_id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Inbound quota binding missing' USING ERRCODE='23514'; END IF;
 checked_at:=clock_timestamp();
 FOR policy IN SELECT * FROM public.quota_policies WHERE tenant_id=NEW.tenant_id AND quota_code='caller.inbound.greeting_admissions'
  AND status<>'archived' AND (tenant_environment_id IS NULL OR tenant_environment_id=environment_id) ORDER BY id LIMIT 11 LOOP
  policy_count:=policy_count+1;
  IF policy_count>10 OR policy.enforcement_mode<>'block' OR policy.hard_limit<>trunc(policy.hard_limit) OR policy.hard_limit>9007199254740991
   OR ((policy.quota_scope='tenant' AND policy.tenant_environment_id IS NULL) OR (policy.quota_scope='environment' AND policy.tenant_environment_id=environment_id)) IS NOT TRUE THEN
   RAISE EXCEPTION 'Inbound quota configuration invalid' USING ERRCODE='23514'; END IF;
  IF policy.status<>'active' THEN RAISE EXCEPTION 'Inbound quota paused' USING ERRCODE='23514'; END IF;
  has_tenant:=has_tenant OR policy.quota_scope='tenant';
  window_start:=date_trunc(policy.period_unit,checked_at AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  SELECT count(*) INTO used FROM public.caller_inbound_greeting_pins pin
   JOIN public.caller_inbound_bindings binding ON binding.id=pin.inbound_binding_id AND binding.tenant_id=pin.tenant_id
   WHERE pin.tenant_id=NEW.tenant_id AND pin.created_at>=window_start AND pin.created_at<=checked_at
    AND (policy.quota_scope='tenant' OR binding.tenant_environment_id=environment_id);
  IF used>=policy.hard_limit THEN RAISE EXCEPTION 'Inbound quota exhausted' USING ERRCODE='23514'; END IF;
 END LOOP;
 IF NOT has_tenant THEN RAISE EXCEPTION 'Inbound quota missing' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_greeting_admission_guard BEFORE INSERT ON public.caller_inbound_greeting_pins FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_admission_quota();
