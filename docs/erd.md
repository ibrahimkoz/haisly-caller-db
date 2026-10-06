# Haisly DB ERD Summary

This is a textual ERD summary for repository-level design reviews.

## Core graph

- `industries` is a global reference catalog; each newly registered `tenant` selects one industry through `tenants.industry_id`.
- `tenants` is the root for tenant-scoped entities.
- `users` belongs to one `tenant`.
- `roles`/`permissions`/`user_roles` model tenant RBAC.
- `sessions` and `refresh_tokens` bind auth lifecycle to `users` and `tenants`.

## Voice and customer operations graph

- `ai_agents` and `phone_numbers` are linked via `routing_rules`.
- `calls` may link to `ai_agents` and `phone_numbers`.
- `call_events`, `call_transcripts`, and `call_recordings` depend on `calls`.
- `customers`/`cases`/`interactions` and `leads`/`follow_up_tasks` model post-call workflows.

## Runtime and execution graph

- `tenant_environments` scopes runtime configurations.
- `agent_config_versions` and `agent_config_bindings` attach to environment + agent.
- `tool_definitions` -> `tool_versions` -> `tenant_tool_bindings` -> `tool_execution_runs`.
- `call_sessions` and `call_tool_executions` connect runtime sessions to tool execution.
- `workflow_templates` -> versions -> tenant bindings -> `workflow_runs` -> `workflow_step_runs`.

## Integration and external reference graph

- `integrations` own `integration_mappings` and optional `automation_rules`.
- `external_object_references` links internal records (`call`, `case`, `lead`, `customer`) to external IDs.

## Artifact and compliance graph

- `artifacts` are linked to tenant-owned entities by owner metadata.
- `artifact_access_events`, `artifact_redaction_jobs`, `artifact_deletion_jobs` depend on `artifacts`.
- `consent_policies` and `consent_records` capture channel consent outcomes.
- `data_export_requests`, `data_deletion_requests`, `pii_redaction_jobs` model privacy workflows.

## Operations and observability graph

- `outbox_events`/`inbox_events` + `background_jobs`/`job_attempts` model async processing.
- `webhook_subscriptions` + `webhook_deliveries` model outbound webhooks.
- `notification_templates`/`preferences`/`deliveries` model channel delivery; `notifications` stores each user's private in-app inbox.
- `metric_snapshots` + report tables model analytics and scheduled reporting.

## Platform extension graph

- Safety: guardrails + simulations.
- Telephony abstraction: provider accounts, number orders, provider webhook mapping.
- Governance/security: platform admin, incidents, reviews, vulnerability and dependency scans.
- Reliability: feature flags, migration jobs, backup/restore drills, SLO/alerts, quota policies.
