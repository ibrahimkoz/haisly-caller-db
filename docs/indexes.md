# Haisly DB Index Contract

## Principles

1. Every tenant-scoped entity has tenant-first index coverage.
2. Status and timeline queries are supported with `(tenant_id, status, <time>)` patterns.
3. Idempotency and dedup flows use unique keys and/or partial unique indexes.
4. Runtime-heavy paths (calls, sessions, jobs, webhooks, tools) have append-friendly time indexes.

## Core Tenant and Identity

- `industries_status_sort_order_code_idx`
- `tenants_industry_status_created_at_idx`
- `users_tenant_status_created_at_idx`
- `user_invitations_tenant_status_expires_at_idx`
- `sessions_tenant_status_created_at_idx`, `sessions_user_status_expires_at_idx`
- `refresh_tokens_user_status_expires_at_idx`, `refresh_tokens_family_status_idx`
- `otp_challenges_user_purpose_status_expires_at_idx`
- `mfa_recovery_requests_tenant_status_created_at_idx`

## Billing and Usage

- `usage_events_tenant_period_occurred_at_idx`
- `usage_events_tenant_metric_occurred_at_idx`
- `invoices_tenant_status_created_at_idx`
- `invoice_items_tenant_invoice_idx`
- `payment_transactions_tenant_status_created_at_idx`

## Voice, Leads, and Follow-up

- `calls_tenant_status_started_at_idx`
- `call_events_tenant_event_type_occurred_at_idx`
- `call_recordings_call_status_created_at_idx`
- `leads_tenant_status_owner_created_at_idx`
- `follow_up_tasks_tenant_status_due_at_idx`

## Runtime, Tools, Workflow

- `tenant_environments_tenant_status_updated_at_idx`
- `service_accounts_tenant_environment_status_idx`
- `idempotency_keys_tenant_scope_expires_at_idx`
- `agent_config_versions_tenant_env_agent_status_updated_idx`
- `tool_execution_runs_tenant_status_requested_at_idx`
- `workflow_runs_tenant_env_status_created_at_idx`

## Async, Webhook, Notifications, and Ops

- `background_jobs_tenant_status_next_run_idx`
- `job_attempts_job_attempt_no_idx`
- `webhook_deliveries_tenant_status_next_attempt_idx`
- `notification_deliveries_tenant_status_queued_at_idx`
- `notifications_recipient_status_created_at_idx`
- `notifications_recipient_created_at_idx`
- `search_index_jobs_tenant_status_queued_at_idx`
- `import_jobs_tenant_status_created_at_idx`
- `export_jobs_tenant_status_created_at_idx`

## Safety, Telephony, Knowledge, and Analytics

- `policy_evaluation_logs_tenant_result_occurred_at_idx`
- `simulation_runs_tenant_env_status_created_at_idx`
- `provider_webhook_events_tenant_status_received_at_idx`
- `knowledge_chunks_collection_chunk_no_idx`
- `metric_snapshots_tenant_metric_window_start_idx`
- `report_deliveries_tenant_status_requested_at_idx`

## Platform Security and Governance

- `security_events_status_severity_occurred_at_idx`
- `security_incidents_status_severity_detected_at_idx`
- `access_reviews_scope_status_due_at_idx`
- `vulnerability_scan_runs_status_created_at_idx`
- `dependency_scan_runs_status_created_at_idx`
- `quota_usage_snapshots_tenant_status_window_start_idx`

## Notes

- Additional indexes should be introduced only with an explicit query/use-case.
- Partial indexes are used for pending/active queues and nullable foreign-key filters.
- Index naming stays stable for migration validation and operational troubleshooting.
