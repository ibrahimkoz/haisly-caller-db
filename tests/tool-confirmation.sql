-- Final verification only, after migration131 on an isolated *_test database.
BEGIN;
DO $$
DECLARE tenant_key bigint; other_tenant bigint; environment_key bigint; session_key bigint; confirmation_key bigint; tool_key bigint; version_key bigint; run_key bigint; consumed_time timestamptz;
BEGIN
  IF current_database() NOT LIKE '%\_test' ESCAPE '\' THEN
    RAISE EXCEPTION 'Requires isolated test database';
  END IF;
  INSERT INTO public.tenants(slug, name) VALUES ('confirmation-fixture-' || gen_random_uuid(), 'Confirmation test') RETURNING id INTO tenant_key;
  INSERT INTO public.tenants(slug, name) VALUES ('confirmation-other-' || gen_random_uuid(), 'Other tenant') RETURNING id INTO other_tenant;
  INSERT INTO public.tenant_environments(tenant_id, code, name) VALUES (tenant_key, 'test', 'Test') RETURNING id INTO environment_key;
  INSERT INTO public.call_sessions(tenant_id, tenant_environment_id, runtime_session_ref)
    VALUES (tenant_key, environment_key, 'confirmation-test') RETURNING id INTO session_key;
  INSERT INTO public.caller_tool_confirmations(tenant_id, call_session_id, tool_code, contract_version,
    intent_digest, token_hash, confirmation_event_ref, expires_at)
    VALUES (tenant_key, session_key, 'appointment_cancel', 1, repeat('a',64), repeat('b',64), 'event:1', clock_timestamp()+interval '4 minutes')
    RETURNING id INTO confirmation_key;
  BEGIN
    UPDATE public.caller_tool_confirmations SET intent_digest=repeat('c',64) WHERE id=confirmation_key;
    RAISE EXCEPTION 'Intent rewrite accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.caller_tool_confirmations SET expires_at=clock_timestamp()+interval '5 minutes' WHERE id=confirmation_key;
    RAISE EXCEPTION 'Expiry extension accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.caller_tool_confirmations(tenant_id, call_session_id, tool_code, contract_version,
      intent_digest, token_hash, confirmation_event_ref, expires_at)
      VALUES (other_tenant, session_key, 'appointment_cancel', 1, repeat('a',64), repeat('c',64), 'event:2', clock_timestamp()+interval '4 minutes');
    RAISE EXCEPTION 'Foreign tenant session accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.caller_tool_confirmations(tenant_id, call_session_id, tool_code, contract_version,
      intent_digest, token_hash, confirmation_event_ref, expires_at)
      VALUES (tenant_key, session_key, 'appointment_cancel', 1, repeat('a',64), repeat('c',64), 'event:1', clock_timestamp()+interval '4 minutes');
    RAISE EXCEPTION 'Same consent event reused';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.caller_tool_confirmations(tenant_id, call_session_id, tool_code, contract_version,
      intent_digest, token_hash, confirmation_event_ref, expires_at)
      VALUES (tenant_key, session_key, 'appointment_cancel', 1, repeat('a',64), repeat('c',64), 'event:2', clock_timestamp()+interval '6 minutes');
    RAISE EXCEPTION 'Excessive lifetime accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.caller_tool_confirmations SET consumed_at=clock_timestamp() WHERE id=confirmation_key;
    RAISE EXCEPTION 'Consumption without execution accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  UPDATE public.caller_tool_confirmations SET revoked_at=clock_timestamp() WHERE id=confirmation_key;
  BEGIN
    UPDATE public.caller_tool_confirmations SET revoked_at=NULL WHERE id=confirmation_key;
    RAISE EXCEPTION 'Revoked token reactivated';
  EXCEPTION WHEN check_violation THEN NULL; END;
  INSERT INTO public.tool_definitions(tenant_id, code, name) VALUES (tenant_key, 'appointment_cancel', 'Cancel') RETURNING id INTO tool_key;
  INSERT INTO public.tool_versions(tenant_id, tool_definition_id, version_no) VALUES (tenant_key, tool_key, 1) RETURNING id INTO version_key;
  INSERT INTO public.tool_execution_runs(tenant_id, tenant_environment_id, tool_definition_id, tool_version_id, execution_key)
    VALUES (tenant_key, environment_key, tool_key, version_key, 'confirmation:execution') RETURNING id INTO run_key;
  INSERT INTO public.caller_tool_confirmations(tenant_id, call_session_id, tool_code, contract_version,
    intent_digest, token_hash, confirmation_event_ref, expires_at)
    VALUES (tenant_key, session_key, 'appointment_cancel', 1, repeat('a',64), repeat('d',64), 'event:consume', clock_timestamp()+interval '4 minutes')
    RETURNING id INTO confirmation_key;
  UPDATE public.caller_tool_confirmations SET tool_execution_run_id=run_key WHERE id=confirmation_key RETURNING consumed_at INTO consumed_time;
  IF consumed_time IS NULL THEN RAISE EXCEPTION 'Consumption timestamp missing'; END IF;
  UPDATE public.caller_tool_confirmations SET tool_execution_run_id=run_key WHERE id=confirmation_key;
  IF (SELECT consumed_at FROM public.caller_tool_confirmations WHERE id=confirmation_key) <> consumed_time THEN
    RAISE EXCEPTION 'Identical terminal replay changed timestamp';
  END IF;
  BEGIN
    UPDATE public.caller_tool_confirmations SET consumed_at=NULL, tool_execution_run_id=NULL WHERE id=confirmation_key;
    RAISE EXCEPTION 'Consumed token reset';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.caller_tool_confirmations SET revoked_at=clock_timestamp() WHERE id=confirmation_key;
    RAISE EXCEPTION 'Consumed token retroactively revoked';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
ROLLBACK;
