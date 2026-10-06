# Platform Extension Contract

## Purpose

Platform extension tables support runtime orchestration, safety, operations, and provider abstraction without binding the product to a single vendor.

## Runtime configuration and execution

- Environments and service access:
  - `tenant_environments`
  - `service_accounts`, `service_account_scopes`, `service_account_keys`
  - `idempotency_keys`
- Agent config lifecycle:
  - `agent_config_versions`, `agent_config_publish_requests`, `agent_config_bindings`
- Tool lifecycle:
  - `tool_definitions`, `tool_versions`, `tenant_tool_bindings`, `tool_execution_runs`
- Workflow lifecycle:
  - `workflow_templates`, `workflow_template_versions`, `tenant_workflow_bindings`, `workflow_runs`, `workflow_step_runs`

## Runtime eventing and webhooks

- `outbox_events`, `inbox_events`
- `background_jobs`, `job_attempts`
- `webhook_subscriptions`, `webhook_deliveries`
- `secret_references`, `secret_rotation_events`

## Safety and policy

- Guardrails:
  - `guardrail_policies`, `guardrail_policy_versions`, `agent_guardrail_bindings`, `policy_evaluation_logs`
- Simulations:
  - `simulation_scenarios`, `simulation_assertions`, `simulation_runs`, `simulation_run_events`

## Telephony abstraction

- `telephony_provider_accounts`
- `phone_number_orders`
- `provider_webhook_events`
- `provider_event_mappings`

Contract rule: provider payload is captured as raw metadata + normalized mapping state, without hard-coding a single telephony vendor model.

## Handoff, SLA, and notifications

- `handoff_queues`, `human_agent_presence`, `handoff_requests`, `handoff_events`
- `business_hours_policies`, `holiday_calendars`, `sla_policies`, `escalation_policies`
- `notification_templates`, `notification_preferences`, `notification_deliveries`, `notifications`

## Knowledge and analytics

- Knowledge:
  - `knowledge_collections`, `knowledge_sources`, `knowledge_source_versions`, `knowledge_ingestion_jobs`, `knowledge_chunks`, `agent_knowledge_bindings`
- Analytics and reports:
  - `metric_snapshots`, `report_definitions`, `scheduled_reports`, `report_deliveries`

## Platform governance and reliability

- Platform security/governance:
  - `platform_admin_users`, `platform_admin_roles`, `platform_admin_user_roles`
  - `platform_admin_credentials`, `platform_admin_sessions`, `platform_admin_refresh_tokens`
  - `platform_admin_permissions`, `platform_admin_role_permissions`
  - `security_events`, `security_incidents`
  - `access_reviews`, `access_review_items`
  - `vulnerability_scan_runs`, `vulnerability_findings`
  - `sbom_snapshots`, `dependency_scan_runs`, `dependency_scan_findings`
- Operational reliability:
  - `feature_flags`
  - `migration_jobs`
  - `backup_restore_drills`
  - `search_index_jobs`
  - `import_jobs`, `export_jobs`
  - `slo_definitions`, `alert_rules`, `alert_events`, `operational_incidents`
  - `quota_policies`, `quota_usage_snapshots`
