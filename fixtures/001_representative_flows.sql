WITH pending_tenant AS (
  INSERT INTO public.tenants (
    slug,
    name,
    status,
    timezone,
    locale,
    onboarding_state
  )
  VALUES (
    'pending-tenant-fixture',
    'Pending Tenant Fixture',
    'pending_email_verification',
    'Europe/Istanbul',
    'tr',
    '{"email_verified": false, "billing_started": false, "phone_setup_started": false, "agent_setup_started": false}'::jsonb
  )
  ON CONFLICT ON CONSTRAINT tenants_slug_unique DO UPDATE SET
    name = EXCLUDED.name,
    status = EXCLUDED.status,
    timezone = EXCLUDED.timezone,
    locale = EXCLUDED.locale,
    onboarding_state = EXCLUDED.onboarding_state,
    updated_at = now()
  RETURNING id, public_id
),
pending_owner AS (
  INSERT INTO public.users (
    tenant_id,
    primary_email,
    first_name,
    last_name,
    status,
    locale,
    timezone
  )
  SELECT
    id,
    'pending-owner@fixture.haisly.local',
    'Pending',
    'Owner Fixture',
    'pending_email_verification',
    'tr',
    'Europe/Istanbul'
  FROM pending_tenant
  ON CONFLICT ON CONSTRAINT users_primary_email_normalized_unique DO UPDATE SET
    tenant_id = EXCLUDED.tenant_id,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    status = EXCLUDED.status,
    locale = EXCLUDED.locale,
    timezone = EXCLUDED.timezone,
    updated_at = now()
  RETURNING id, tenant_id
),
pending_owner_membership AS (
  INSERT INTO public.tenant_memberships (
    tenant_id,
    user_id,
    status,
    joined_at
  )
  SELECT tenant_id, id, 'pending_email_verification', NULL
  FROM pending_owner
  ON CONFLICT ON CONSTRAINT tenant_memberships_user_tenant_unique DO UPDATE SET
    status = EXCLUDED.status,
    joined_at = EXCLUDED.joined_at,
    deleted_at = NULL,
    updated_at = now()
  RETURNING tenant_id, user_id
),
pending_owner_invite AS (
  INSERT INTO public.user_invitations (
    tenant_id,
    invited_email,
    inviter_user_id,
    status,
    token_hash,
    role_codes,
    expires_at
  )
  SELECT
    tenant_id,
    'ops.pending@fixture.haisly.local',
    id,
    'pending',
    'sha256:fixture_invite_pending_4ea80e0f1ecbd63f2cfa59fa7342',
    '["operations_manager"]'::jsonb,
    now() + interval '7 days'
  FROM pending_owner
  ON CONFLICT ON CONSTRAINT user_invitations_token_hash_unique DO UPDATE SET
    status = EXCLUDED.status,
    role_codes = EXCLUDED.role_codes,
    expires_at = EXCLUDED.expires_at,
    updated_at = now()
  RETURNING id
),
pending_owner_challenge AS (
  INSERT INTO public.otp_challenges (
    tenant_id,
    user_id,
    purpose,
    delivery_channel,
    destination_hash,
    code_hash,
    status,
    attempt_count,
    max_attempts,
    expires_at
  )
  SELECT
    pending_owner.tenant_id,
    pending_owner.id,
    'email_verification',
    'email',
    'sha256:destination_fixture_pending_owner_7dc5b9ba3b327a57',
    'sha256:otp_fixture_pending_owner_1191cb76c391b8c822ebee7d',
    'pending',
    0,
    5,
    now() + interval '10 minutes'
  FROM pending_owner
  JOIN pending_owner_membership
    ON pending_owner_membership.tenant_id = pending_owner.tenant_id
   AND pending_owner_membership.user_id = pending_owner.id
  ON CONFLICT ON CONSTRAINT otp_challenges_code_hash_unique DO UPDATE SET
    status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at
  RETURNING id
),
demo_tenant AS (
  SELECT id, public_id
  FROM public.tenants
  WHERE slug = 'demo-tenant'
  LIMIT 1
),
demo_owner AS (
  SELECT id, tenant_id, public_id
  FROM public.users
  WHERE primary_email_normalized = 'owner@demo.haisly.local'
  LIMIT 1
),
demo_environment AS (
  INSERT INTO public.tenant_environments (
    tenant_id,
    code,
    name,
    environment_type,
    status,
    is_default,
    metadata
  )
  SELECT
    id,
    'production',
    'Production',
    'production',
    'active',
    true,
    '{"source":"fixture"}'::jsonb
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT tenant_environments_tenant_code_unique DO UPDATE SET
    name = EXCLUDED.name,
    environment_type = EXCLUDED.environment_type,
    status = EXCLUDED.status,
    is_default = EXCLUDED.is_default,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_agent AS (
  SELECT id, tenant_id
  FROM public.ai_agents
  WHERE tenant_id = (SELECT id FROM demo_tenant)
    AND name = 'Demo Concierge Agent'
  ORDER BY id
  LIMIT 1
),
demo_agent_insert AS (
  INSERT INTO public.ai_agents (
    tenant_id,
    name,
    status,
    language,
    model_provider,
    model_name,
    voice_name,
    metadata
  )
  SELECT
    demo_tenant.id,
    'Demo Concierge Agent',
    'active',
    'tr',
    'openai',
    'gpt-4o-realtime',
    'alloy',
    '{"vertical":"hotel"}'::jsonb
  FROM demo_tenant
  WHERE NOT EXISTS (
    SELECT 1
    FROM demo_agent
  )
  RETURNING id, tenant_id
),
demo_agent_final AS (
  SELECT id, tenant_id FROM demo_agent
  UNION ALL
  SELECT id, tenant_id FROM demo_agent_insert
),
demo_phone_number AS (
  INSERT INTO public.phone_numbers (
    tenant_id,
    phone_number,
    display_name,
    status,
    provider,
    provider_phone_number_ref,
    metadata
  )
  SELECT
    id,
    '+905551234567',
    'Demo Hotel Main Line',
    'active',
    'mock_telephony',
    'pn_demo_hotel_main',
    '{"vertical":"hotel"}'::jsonb
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT phone_numbers_tenant_phone_unique DO UPDATE SET
    display_name = EXCLUDED.display_name,
    status = EXCLUDED.status,
    provider = EXCLUDED.provider,
    provider_phone_number_ref = EXCLUDED.provider_phone_number_ref,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_call AS (
  INSERT INTO public.calls (
    tenant_id,
    ai_agent_id,
    phone_number_id,
    provider_call_id,
    direction,
    status,
    started_at,
    ended_at,
    duration_seconds,
    recording_available,
    metadata
  )
  SELECT
    demo_tenant.id,
    demo_agent_final.id,
    demo_phone_number.id,
    'pc_fixture_demo_call_001',
    'inbound',
    'completed',
    now() - interval '1 day',
    now() - interval '1 day' + interval '4 minutes',
    240,
    true,
    '{"source":"fixture","intent":"reservation"}'::jsonb
  FROM demo_tenant
  CROSS JOIN demo_agent_final
  CROSS JOIN demo_phone_number
  ON CONFLICT ON CONSTRAINT calls_tenant_provider_call_unique DO UPDATE SET
    status = EXCLUDED.status,
    ended_at = EXCLUDED.ended_at,
    duration_seconds = EXCLUDED.duration_seconds,
    recording_available = EXCLUDED.recording_available,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_call_event AS (
  INSERT INTO public.call_events (
    tenant_id,
    call_id,
    event_type,
    source,
    event_payload,
    occurred_at
  )
  SELECT
    demo_call.tenant_id,
    demo_call.id,
    'reservation_collected',
    'runtime',
    '{"room_type":"deluxe","nights":2}'::jsonb,
    now() - interval '1 day' + interval '2 minutes'
  FROM demo_call
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.call_events
    WHERE call_id = demo_call.id
      AND event_type = 'reservation_collected'
  )
  RETURNING id
),
demo_call_transcript AS (
  INSERT INTO public.call_transcripts (
    tenant_id,
    call_id,
    segment_index,
    speaker_type,
    content,
    language,
    started_at,
    ended_at,
    metadata
  )
  SELECT
    demo_call.tenant_id,
    demo_call.id,
    1,
    'customer',
    'Merhaba, iki gece icin oda ayirtmak istiyorum.',
    'tr',
    now() - interval '1 day',
    now() - interval '1 day' + interval '25 seconds',
    '{"source":"fixture"}'::jsonb
  FROM demo_call
  ON CONFLICT ON CONSTRAINT call_transcripts_call_segment_unique DO UPDATE SET
    content = EXCLUDED.content,
    ended_at = EXCLUDED.ended_at,
    metadata = EXCLUDED.metadata
  RETURNING id
),
demo_recording AS (
  INSERT INTO public.call_recordings (
    tenant_id,
    call_id,
    provider_recording_id,
    storage_ref,
    status,
    duration_seconds,
    started_at,
    ended_at,
    metadata
  )
  SELECT
    demo_call.tenant_id,
    demo_call.id,
    'rec_fixture_demo_call_001',
    'storage://demo/calls/rec_fixture_demo_call_001.wav',
    'available',
    240,
    now() - interval '1 day',
    now() - interval '1 day' + interval '4 minutes',
    '{"source":"fixture"}'::jsonb
  FROM demo_call
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.call_recordings
    WHERE tenant_id = demo_call.tenant_id
      AND provider_recording_id = 'rec_fixture_demo_call_001'
  )
  RETURNING id, tenant_id
),
demo_artifact AS (
  INSERT INTO public.artifacts (
    tenant_id,
    owner_entity_type,
    owner_entity_id,
    artifact_type,
    storage_provider,
    storage_ref,
    content_type,
    byte_size,
    checksum_sha256,
    retention_class,
    privacy_classification,
    status,
    metadata
  )
  SELECT
    demo_recording.tenant_id,
    'call_recording',
    demo_recording.id,
    'audio_recording',
    's3-compatible',
    'storage://demo/artifacts/rec_fixture_demo_call_001',
    'audio/wav',
    1572864,
    '8a0e8d4ee64191ecad624f28224716f9d0d41ef4e1e9a8406f0c57a4a88cc6d0',
    'call_recording_default',
    'restricted',
    'available',
    '{"source":"fixture"}'::jsonb
  FROM demo_recording
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.artifacts
    WHERE tenant_id = demo_recording.tenant_id
      AND storage_ref = 'storage://demo/artifacts/rec_fixture_demo_call_001'
  )
  RETURNING id, tenant_id
),
demo_artifact_access AS (
  INSERT INTO public.artifact_access_events (
    tenant_id,
    artifact_id,
    actor_user_id,
    actor_type,
    action,
    outcome,
    request_id,
    metadata
  )
  SELECT
    demo_artifact.tenant_id,
    demo_artifact.id,
    demo_owner.id,
    'tenant_user',
    'playback',
    'allowed',
    'fixture-artifact-access-001',
    '{"source":"fixture"}'::jsonb
  FROM demo_artifact
  CROSS JOIN demo_owner
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.artifact_access_events
    WHERE request_id = 'fixture-artifact-access-001'
  )
  RETURNING id
),
demo_consent_policy AS (
  INSERT INTO public.consent_policies (
    tenant_id,
    tenant_environment_id,
    policy_name,
    channel,
    language,
    version_no,
    disclosure_text,
    rules_config,
    status,
    effective_at,
    metadata,
    created_by_user_id
  )
  SELECT
    demo_tenant.id,
    demo_environment.id,
    'voice-recording-disclosure',
    'voice',
    'tr',
    1,
    'Bu gorusme kalite amacli kaydedilebilir.',
    '{"require_explicit_yes":true}'::jsonb,
    'active',
    now() - interval '10 days',
    '{"source":"fixture"}'::jsonb,
    demo_owner.id
  FROM demo_tenant
  CROSS JOIN demo_environment
  CROSS JOIN demo_owner
  ON CONFLICT ON CONSTRAINT consent_policies_tenant_env_name_version_unique DO UPDATE SET
    disclosure_text = EXCLUDED.disclosure_text,
    rules_config = EXCLUDED.rules_config,
    status = EXCLUDED.status,
    effective_at = EXCLUDED.effective_at,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id, tenant_environment_id
),
demo_consent_record AS (
  INSERT INTO public.consent_records (
    tenant_id,
    tenant_environment_id,
    consent_policy_id,
    call_id,
    channel,
    consent_result,
    reason,
    evidence_ref,
    metadata
  )
  SELECT
    demo_consent_policy.tenant_id,
    demo_consent_policy.tenant_environment_id,
    demo_consent_policy.id,
    demo_call.id,
    'voice',
    'granted',
    'Customer accepted recording disclosure',
    'consent://fixture/demo-call-001',
    '{"source":"fixture"}'::jsonb
  FROM demo_consent_policy
  CROSS JOIN demo_call
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.consent_records
    WHERE evidence_ref = 'consent://fixture/demo-call-001'
  )
  RETURNING id
),
demo_lead AS (
  INSERT INTO public.leads (
    tenant_id,
    lead_no,
    title,
    summary,
    status,
    source,
    score,
    owner_user_id,
    source_call_id,
    metadata
  )
  SELECT
    demo_tenant.id,
    'LD-2026-0001',
    'Corporate reservation request',
    'Potential group booking for next month.',
    'qualified',
    'voice_call',
    82,
    demo_owner.id,
    demo_call.id,
    '{"vertical":"hotel","source":"fixture"}'::jsonb
  FROM demo_tenant
  CROSS JOIN demo_owner
  CROSS JOIN demo_call
  ON CONFLICT ON CONSTRAINT leads_tenant_lead_no_unique DO UPDATE SET
    title = EXCLUDED.title,
    summary = EXCLUDED.summary,
    status = EXCLUDED.status,
    source = EXCLUDED.source,
    score = EXCLUDED.score,
    owner_user_id = EXCLUDED.owner_user_id,
    source_call_id = EXCLUDED.source_call_id,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_lead_event AS (
  INSERT INTO public.lead_events (
    tenant_id,
    lead_id,
    actor_user_id,
    event_type,
    event_payload,
    note
  )
  SELECT
    demo_lead.tenant_id,
    demo_lead.id,
    demo_owner.id,
    'follow_up_scheduled',
    '{"channel":"call","sla_hours":2}'::jsonb,
    'Qualified lead follow-up scheduled.'
  FROM demo_lead
  CROSS JOIN demo_owner
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.lead_events
    WHERE lead_id = demo_lead.id
      AND event_type = 'follow_up_scheduled'
  )
  RETURNING id
),
demo_follow_up_task AS (
  INSERT INTO public.follow_up_tasks (
    tenant_id,
    title,
    description,
    status,
    priority,
    due_at,
    assigned_user_id,
    lead_id,
    metadata
  )
  SELECT
    demo_lead.tenant_id,
    'Call back for room block quote',
    'Share room block pricing and cancellation policy.',
    'pending',
    'high',
    now() + interval '2 hours',
    demo_owner.id,
    demo_lead.id,
    '{"source":"fixture","channel":"voice"}'::jsonb
  FROM demo_lead
  CROSS JOIN demo_owner
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.follow_up_tasks
    WHERE tenant_id = demo_lead.tenant_id
      AND title = 'Call back for room block quote'
      AND lead_id = demo_lead.id
  )
  RETURNING id
),
demo_usage_event AS (
  INSERT INTO public.usage_events (
    tenant_id,
    source_event_id,
    metric_code,
    period_key,
    occurred_at,
    quantity,
    unit,
    is_billable,
    metadata
  )
  SELECT
    demo_tenant.id,
    'usage_fixture_demo_2026_05',
    'call.minutes',
    '2026-05',
    now() - interval '12 hours',
    4.000000,
    'minute',
    true,
    '{"source":"fixture"}'::jsonb
  FROM demo_tenant
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.usage_events
    WHERE tenant_id = demo_tenant.id
      AND source_event_id = 'usage_fixture_demo_2026_05'
  )
  RETURNING id
),
demo_invoice AS (
  INSERT INTO public.invoices (
    tenant_id,
    pricing_plan_id,
    invoice_no,
    status,
    period_start,
    period_end,
    currency_code,
    subtotal_amount,
    tax_amount,
    discount_amount,
    total_amount,
    finalized_at,
    paid_at,
    metadata
  )
  SELECT
    demo_tenant.id,
    pricing_plans.id,
    'INV-2026-0001',
    'draft',
    DATE '2026-05-01',
    DATE '2026-05-31',
    'USD',
    120.000000,
    0.000000,
    0.000000,
    120.000000,
    NULL,
    NULL,
    '{"source":"fixture"}'::jsonb
  FROM demo_tenant
  CROSS JOIN LATERAL (
    SELECT id
    FROM public.pricing_plans
    WHERE code = 'basic'
    LIMIT 1
  ) AS pricing_plans
  ON CONFLICT ON CONSTRAINT invoices_tenant_invoice_no_unique DO UPDATE SET
    status = EXCLUDED.status,
    subtotal_amount = EXCLUDED.subtotal_amount,
    total_amount = EXCLUDED.total_amount,
    finalized_at = EXCLUDED.finalized_at,
    paid_at = EXCLUDED.paid_at,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_invoice_item AS (
  INSERT INTO public.invoice_items (
    tenant_id,
    invoice_id,
    line_no,
    item_type,
    description,
    quantity,
    unit_price,
    line_total,
    currency_code,
    metadata
  )
  SELECT
    demo_invoice.tenant_id,
    demo_invoice.id,
    1,
    'call_minutes',
    'May call minutes',
    120.000000,
    1.000000,
    120.000000,
    'USD',
    '{"source":"fixture"}'::jsonb
  FROM demo_invoice
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.invoice_items
    WHERE invoice_id = demo_invoice.id
      AND line_no = 1
  )
  RETURNING id
),
demo_payment_transaction AS (
  INSERT INTO public.payment_transactions (
    tenant_id,
    invoice_id,
    attempt_no,
    status,
    provider,
    provider_transaction_ref,
    amount,
    currency_code,
    processed_at,
    metadata
  )
  SELECT
    demo_invoice.tenant_id,
    demo_invoice.id,
    1,
    'succeeded',
    'mock_billing',
    'ptx_fixture_demo_0001',
    120.000000,
    'USD',
    now() - interval '11 hours',
    '{"source":"fixture"}'::jsonb
  FROM demo_invoice
  ON CONFLICT ON CONSTRAINT payment_transactions_invoice_attempt_unique DO UPDATE SET
    status = EXCLUDED.status,
    processed_at = EXCLUDED.processed_at,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id
),
demo_session AS (
  INSERT INTO public.sessions (
    tenant_id,
    user_id,
    access_token_jti,
    status,
    ip_address,
    user_agent,
    expires_at,
    last_seen_at
  )
  SELECT
    demo_owner.tenant_id,
    demo_owner.id,
    'jti_fixture_demo_owner_session_001',
    'active',
    '203.0.113.10',
    'fixture-agent/1.0',
    now() + interval '7 days',
    now()
  FROM demo_owner
  ON CONFLICT ON CONSTRAINT sessions_access_token_jti_unique DO UPDATE SET
    status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at,
    last_seen_at = EXCLUDED.last_seen_at
  RETURNING id, tenant_id, user_id
),
demo_refresh_token AS (
  INSERT INTO public.refresh_tokens (
    tenant_id,
    user_id,
    session_id,
    token_hash,
    status,
    issued_at,
    expires_at
  )
  SELECT
    demo_session.tenant_id,
    demo_session.user_id,
    demo_session.id,
    'sha256:refresh_fixture_demo_owner_835e096cdf1f2c831d54a72997be',
    'active',
    now(),
    now() + interval '30 days'
  FROM demo_session
  ON CONFLICT ON CONSTRAINT refresh_tokens_token_hash_unique DO UPDATE SET
    status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at
  RETURNING id
),
demo_mfa_recovery_request AS (
  INSERT INTO public.mfa_recovery_requests (
    tenant_id,
    target_user_id,
    requested_by_user_id,
    recovery_scope,
    status,
    reason,
    evidence_ref,
    decision_by_user_id,
    decision_at,
    audit_correlation_id
  )
  SELECT
    demo_owner.tenant_id,
    demo_owner.id,
    demo_owner.id,
    'tenant_admin',
    'approved',
    'Fixture recovery flow approval for test verification.',
    'artifact://fixture/recovery/evidence-001',
    demo_owner.id,
    now() - interval '2 hours',
    'fixture-mfa-recovery-001'
  FROM demo_owner
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.mfa_recovery_requests
    WHERE audit_correlation_id = 'fixture-mfa-recovery-001'
  )
  RETURNING id
),
demo_integration AS (
  INSERT INTO public.integrations (
    tenant_id,
    provider,
    name,
    status,
    connection_mode,
    credentials_ref,
    configuration,
    metadata
  )
  SELECT
    demo_tenant.id,
    'hotel_pms',
    'Hotel PMS Demo',
    'active',
    'api_key',
    'secret_ref://demo/hotel-pms',
    '{"base_url":"https://pms.demo.local"}'::jsonb,
    '{"source":"fixture"}'::jsonb
  FROM demo_tenant
  ON CONFLICT ON CONSTRAINT integrations_tenant_provider_name_unique DO UPDATE SET
    status = EXCLUDED.status,
    configuration = EXCLUDED.configuration,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id, tenant_id
),
demo_integration_mapping AS (
  INSERT INTO public.integration_mappings (
    tenant_id,
    integration_id,
    entity_type,
    source_field,
    target_field,
    status,
    transform_config,
    metadata
  )
  SELECT
    demo_integration.tenant_id,
    demo_integration.id,
    'reservation',
    'room_type_code',
    'room_type',
    'active',
    '{"normalize":"uppercase"}'::jsonb,
    '{"source":"fixture"}'::jsonb
  FROM demo_integration
  ON CONFLICT ON CONSTRAINT integration_mappings_integration_entity_source_unique DO UPDATE SET
    target_field = EXCLUDED.target_field,
    status = EXCLUDED.status,
    transform_config = EXCLUDED.transform_config,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id
),
demo_automation_rule AS (
  INSERT INTO public.automation_rules (
    tenant_id,
    integration_id,
    run_as_user_id,
    name,
    status,
    trigger_type,
    trigger_config,
    action_type,
    action_config,
    metadata
  )
  SELECT
    demo_integration.tenant_id,
    demo_integration.id,
    demo_owner.id,
    'Hotel reservation follow-up rule',
    'active',
    'reservation_created',
    '{"source":"hotel_pms"}'::jsonb,
    'create_follow_up_task',
    '{"priority":"high"}'::jsonb,
    '{"source":"fixture"}'::jsonb
  FROM demo_integration
  CROSS JOIN demo_owner
  ON CONFLICT ON CONSTRAINT automation_rules_tenant_name_unique DO UPDATE SET
    status = EXCLUDED.status,
    trigger_config = EXCLUDED.trigger_config,
    action_config = EXCLUDED.action_config,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id
),
demo_external_reference AS (
  INSERT INTO public.external_object_references (
    tenant_id,
    tenant_environment_id,
    call_id,
    lead_id,
    source_system,
    entity_type,
    external_object_id,
    outcome_status,
    outcome_code,
    request_snapshot,
    response_snapshot,
    metadata
  )
  SELECT
    demo_tenant.id,
    demo_environment.id,
    demo_call.id,
    demo_lead.id,
    'hotel_pms_demo',
    'reservation',
    'HTL-RSV-2026-0001',
    'succeeded',
    '200',
    '{"reservation_no":"HTL-RSV-2026-0001","room_type":"deluxe"}'::jsonb,
    '{"status":"confirmed"}'::jsonb,
    '{"source":"fixture"}'::jsonb
  FROM demo_tenant
  CROSS JOIN demo_environment
  CROSS JOIN demo_call
  CROSS JOIN demo_lead
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.external_object_references
    WHERE tenant_id = demo_tenant.id
      AND source_system = 'hotel_pms_demo'
      AND external_object_id = 'HTL-RSV-2026-0001'
  )
  RETURNING id
)
SELECT
  (SELECT count(*) FROM pending_tenant) AS pending_tenant_count,
  (SELECT count(*) FROM pending_owner) AS pending_owner_count,
  (SELECT count(*) FROM pending_owner_invite) AS pending_invite_count,
  (SELECT count(*) FROM pending_owner_challenge) AS pending_challenge_count,
  (SELECT count(*) FROM demo_call) AS demo_call_count,
  (SELECT count(*) FROM demo_consent_record) AS demo_consent_count,
  (SELECT count(*) FROM demo_lead) AS demo_lead_count,
  (SELECT count(*) FROM demo_follow_up_task) AS follow_up_task_count,
  (SELECT count(*) FROM demo_invoice) AS demo_invoice_count,
  (SELECT count(*) FROM demo_session) AS demo_session_count,
  (SELECT count(*) FROM demo_mfa_recovery_request) AS mfa_recovery_count,
  (SELECT count(*) FROM demo_external_reference) AS external_reference_count;
