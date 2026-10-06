# Security Contract

## Non-negotiable storage rules

1. No plaintext secrets/tokens/passwords/OTP/service keys/provider secrets.
2. Auth and recovery flows store hashes or secret references only.
3. Public APIs must use `public_id`; internal numeric IDs remain internal.
4. Tenant ownership must be enforced with foreign keys and scoped unique constraints.

## Sensitive data handling

- Auth-related hashed fields:
  - `user_credentials.secret_hash`
  - `refresh_tokens.token_hash`
  - `password_resets.reset_token_hash`
  - `otp_challenges.code_hash`
  - `otp_challenges.destination_hash`
  - `platform_admin_credentials.secret_hash`
  - `platform_admin_sessions.csrf_token_hash`
  - `platform_admin_refresh_tokens.token_hash`
  - `service_account_keys.key_hash`
- Secret/reference model:
  - `service_account_keys.key_prefix`
  - `integrations.credentials_ref`
  - `secret_references.secret_ref`
  - `telephony_provider_accounts.auth_secret_ref`

## Artifact and privacy controls

- `artifacts` store metadata + storage refs only.
- Access is auditable via `artifact_access_events`.
- Redaction/deletion lifecycle uses explicit job tables:
  - `artifact_redaction_jobs`
  - `artifact_deletion_jobs`
  - `pii_redaction_jobs`
- Consent and retention are explicit:
  - `retention_policies`
  - `consent_policies`
  - `consent_records`

## Tenant isolation controls

- Tenant-scoped entities include `tenant_id` + tenant-linked FKs.
- Composite foreign keys are used for scoped ownership (for example `(child_id, tenant_id)` to `(parent_id, tenant_id)`).
- Cross-tenant access through incorrect `public_id` resolution must fail closed in API/repository layers.

## Audit and traceability

- Security/audit events:
  - `audit_logs`
  - `security_events`
  - `security_incidents`
  - `access_reviews`
- Operational traces:
  - `outbox_events`, `inbox_events`, `background_jobs`, `job_attempts`
  - `webhook_deliveries`
  - `provider_webhook_events`, `provider_event_mappings`

## Runtime safeguards

- Idempotency and replay safety:
  - `idempotency_keys`
  - webhook/event unique keys and status transitions
- Policy and safety:
  - guardrail policy/version/binding model
  - simulation scenario/run/assertion model

## Verification expectations

- Run migration + schema validation before every phase completion.
- Run seed + fixture load with idempotency checks.
- Keep rollback scripts for each migration when safe.
