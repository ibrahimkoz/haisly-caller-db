# Haisly DB Data Contract

## Scope

This document defines stable database contracts for `haisly-api` and future internal consumers.

All tenant-facing resources expose `public_id` (UUID) as the external identifier.
Internal numeric `id` values are database-only implementation details.

## Global Contract Rules

1. Every tenant-scoped table carries `tenant_id` and tenant ownership foreign keys.
2. API/public surfaces must reference `public_id`, never numeric `id`.
3. Plaintext secrets/tokens/OTP/passwords are never persisted.
4. Binary artifact payloads are not stored in PostgreSQL; metadata and storage refs only.
5. Mutable lifecycle columns use explicit state enums and timestamp constraints.

## Domain Table Map

### Tenant and identity

- `industries`, `tenants`, `company_profiles`, `billing_info`, `payment_info`
- `users`, `user_invitations`, `user_settings`, `user_verified_contacts`, `user_credentials`
- `sessions`, `refresh_tokens`, `password_resets`, `otp_challenges`, `mfa_factors`, `mfa_recovery_requests`
- `roles`, `permissions`, `role_permissions`, `user_roles`, `audit_logs`

### Billing and usage

- `pricing_plans`, `usage_events`, `invoices`, `invoice_items`, `payment_transactions`

### Voice and interaction read model

- `ai_agents`, `phone_numbers`, `routing_rules`
- `calls`, `call_events`, `call_transcripts`, `call_recordings`
- `customers`, `customer_contacts`, `customer_interactions`, `cases`, `case_events`
- `leads`, `lead_events`, `follow_up_tasks`

### Integrations and workflow

- `integrations`, `integration_mappings`, `automation_rules`
- `workflow_templates`, `workflow_template_versions`, `tenant_workflow_bindings`
- `workflow_runs`, `workflow_step_runs`, `external_object_references`

### Runtime and tooling

- `ai_call_sessions`
- `tenant_environments`, `service_accounts`, `service_account_scopes`, `service_account_keys`, `idempotency_keys`
- `industry_agent_templates`, `industry_agent_template_versions`, `industry_agent_template_sections`
- `agent_config_versions`, `agent_config_section_values`, `agent_config_publish_requests`, `agent_config_bindings`
- `tool_definitions`, `tool_versions`, `tenant_tool_bindings`, `tool_execution_runs`
- `call_sessions`, `call_session_events`, `call_tool_executions`

### Artifact and compliance

- `artifacts`, `artifact_access_events`, `artifact_redaction_jobs`, `artifact_deletion_jobs`
- `retention_policies`, `consent_policies`, `consent_records`
- `data_export_requests`, `data_deletion_requests`, `pii_redaction_jobs`

### Async, webhook, secrets, and operations

- `outbox_events`, `inbox_events`, `background_jobs`, `job_attempts`
- `webhook_subscriptions`, `webhook_deliveries`
- `secret_references`, `secret_rotation_events`
- `feature_flags`, `migration_jobs`, `backup_restore_drills`, `search_index_jobs`, `import_jobs`, `export_jobs`
- `slo_definitions`, `alert_rules`, `alert_events`, `operational_incidents`
- `quota_policies`, `quota_usage_snapshots`

### Knowledge, handoff, safety, telephony, analytics, platform

- `knowledge_collections`, `knowledge_sources`, `knowledge_source_versions`, `knowledge_ingestion_jobs`, `knowledge_chunks`, `agent_knowledge_bindings`
- `handoff_queues`, `human_agent_presence`, `handoff_requests`, `handoff_events`
- `guardrail_policies`, `guardrail_policy_versions`, `agent_guardrail_bindings`, `policy_evaluation_logs`
- `simulation_scenarios`, `simulation_assertions`, `simulation_runs`, `simulation_run_events`
- `telephony_provider_accounts`, `phone_number_orders`, `provider_webhook_events`, `provider_event_mappings`
- `notification_templates`, `notification_preferences`, `notification_deliveries`, `notifications`
- `metric_snapshots`, `report_definitions`, `scheduled_reports`, `report_deliveries`
- `platform_admin_users`, `platform_admin_roles`, `platform_admin_user_roles`
- `security_events`, `security_incidents`, `access_reviews`, `access_review_items`
- `vulnerability_scan_runs`, `vulnerability_findings`, `sbom_snapshots`, `dependency_scan_runs`, `dependency_scan_findings`

## External ID Contract

- API contracts should accept and return `public_id`.
- Foreign-key writes in service/repository layers must resolve `public_id -> id` within tenant scope.
- Cross-tenant `public_id` resolution must fail closed.

## Industry Catalog Contract

- `industries` is a global reference catalog and is not tenant-scoped.
- `code` is the stable machine-readable identifier used by configuration and integration logic.
- `public_id` is the identifier exposed by future public API contracts; numeric `id` remains internal.
- Registration and configuration selection surfaces must list only `active` records ordered by `sort_order`, then `code`.
- Initial catalog entries are `hospitality_accommodation` and `food_beverage_restaurant`.
- `tenants.industry_id` references the selected catalog row through an internal numeric foreign key.
- New registration flows must resolve an active `industry_public_id` and persist its internal ID in the same tenant-creation transaction.
- `tenants.industry_id` remains nullable only for tenants created before industry selection became mandatory; no historical tenant is silently assigned to an inferred sector.

## AI Call Session Contract

- `ai_call_sessions.public_id` uniquely identifies one phone call and is used by get/update API operations.
- `ai_call_sessions.tenant_id` is a required foreign key resolved from the API's `tenant_public_id`; numeric tenant IDs are not exposed by the API.
- `data` is a JSON object containing the current session state.
- `session_status = 1` means active and `session_status = 2` means closed.
- Every create operation inserts a new session with status `1`; updates target one `public_id` and never create records.
- This initial integration table is intentionally not tenant-scoped and must not be treated as a long-term multi-tenant authorization boundary.

## AI Tenant Context Contract

- `phone_numbers.phone_number` is the inbound AI integration's tenant-resolution key and is expected to identify exactly one active tenant.
- Resolution fails closed when historical or test data maps the same active number to more than one tenant; it never selects an arbitrary tenant.
- Tenant resolution only returns active phone numbers that belong to active, non-deleted tenants.
- The highest-priority active default routing rule selects an active AI agent for the inbound phone number.
- The selected agent's default-environment binding must reference a published `agent_config_versions` row.
- Greeting and instructions come only from the immutable published `config_snapshot`; missing routing or configuration fails closed.

## Industry Agent Builder Contract

- Industry agent templates are global definitions and are selected through the tenant's `industry_id`.
- Each template has versioned, ordered section definitions. Exactly one template version may be `active` at a time.
- `agent_config_versions.industry_agent_template_version_id` pins a tenant configuration to the exact template schema used to author it. Historical rows remain nullable for backward compatibility.
- Structured user input is stored in `agent_config_section_values` and is isolated by the configuration version's tenant ownership.
- Section values may be inserted, updated, or deleted only while their owning agent configuration version is `draft`.
- A section value must reference a section from the configuration version's pinned template version.
- Published configuration snapshots are immutable and contain the deterministic compilation output used by runtime consumers.
- Room catalog entries describe stable product characteristics only. Live availability, pricing, reservations, and payments remain tool/integration data and must not be persisted as instruction fields.
