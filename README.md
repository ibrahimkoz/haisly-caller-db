# Haisly DB

Personal data administration was retired in migration 235: its navigation, public management APIs, retention policies, export/deletion requests and redaction jobs are removed. Runtime consent policies/records and contact DNC/preferences remain shared campaign infrastructure. Restore the pre-235 backup with the matching application to recover removed records.

## Caller module cleanup (migration 234)

This edition uses outbound campaign calls only. Assistant identity and behavior/topic/objective instructions belong to the campaign. Standalone AI agents/config versions, configurable guardrails, and the knowledge base have been removed from the UI, API and database. Campaign release simulations remain; DNC, consent, authorization and spending checks remain enforced. New campaigns automatically resolve a tenant environment without requiring an agent.

Migration `234_campaign_owned_instructions.sql` removes the retired tables. Restore the pre-migration database backup together with the matching application version to undo this destructive migration. Local `haisly_caller` was migrated; the live server was not modified.

PostgreSQL schema, migrations, rollbacks, seeds, fixtures, validation scripts, and data contract documentation for the Haisly App.

## Scope

This repository owns the database contract only. It does not implement API behavior, UI behavior, provider integrations, or runtime business logic.

The schema targets PostgreSQL 17/18 and follows the active Haisly product and repository specifications. Public API and UI contracts must use `public_id`; internal numeric identifiers stay inside the database and trusted backend internals.

## Repository Layout

```txt
migrations/   Ordered PostgreSQL migration files.
rollbacks/    Reviewed rollback scripts for migrations when rollback is safe.
seeds/        Idempotent reference and local development seed data.
fixtures/     Representative deterministic fixture data for validation and demos.
docs/         Data contract, index, ERD, platform extension, and security notes.
scripts/      Local migration, rollback, seed, and schema validation scripts.
```

## Local PostgreSQL

Local database settings live in `.env.example`; copy them to `.env` before running Docker Compose locally.

```bash
docker compose up -d
docker compose ps
```

Connection conventions are documented in `docs/connection-conventions.md`.

## Scripts

```bash
./scripts/migrate.sh
./scripts/validate-schema.sh
./scripts/seed.sh
./scripts/fixture.sh
./scripts/rollback.sh --last
./scripts/verify.sh
```

Scripts read `.env` when present and otherwise use the current shell environment. They require `psql` and fail fast when connection settings are missing.

## Implementation Order

Work is executed from `specs/haisly-db-implementation-plan.md` in small commit boundaries:

1. Repository scaffold and local database harness.
2. Tenant, identity, auth, RBAC, and audit foundations.
3. Billing, voice operations, customer operations, and platform extensions.
4. Fixtures, documentation, and full migration verification.

## Security Rules

- Do not store plaintext passwords, OTP codes, refresh tokens, service keys, provider secrets, or payment secrets.
- Store large/binary artifacts outside PostgreSQL; this repository stores metadata and provider-neutral storage references only.
- Preserve tenant isolation with explicit ownership columns, foreign keys, constraints, and indexes.
- Treat billing provider choice, production billing rules, telephony provider choice, and the tenant lifecycle enforcement matrix as open until accepted in specs.

## Outbound cleanup (migration 071)

Migration 071 retires hotel inventory and reservation tables and disables existing
HotelRunner integrations, mappings, automation rules, and provider credentials.
Shared customer, call, lead, task and industry data are retained.

Stop old booking/webhook writers and deploy the caller API/client without these
routes before applying the migration. Take a full backup first. The rollback
recreates empty booking tables; it does not recover deleted rows or reactivate
credentials/automations. Restore the pre-migration dump for full data recovery.
Do not deploy this caller-only migration to the running inbound Haisly product.

## HubSpot removal — 2026-11-05

HubSpot is removed from Caller scope. Historical phase notes describe retired
work, not pending delivery. OAuth, CRM synchronization and conflict review are
not supported. Native contact/list, lead and task management remain.

Database migration 230 removes HubSpot-specific tables/functions and credentials
and disables legacy integration mappings/automations. Back up before applying;
recovery requires the pre-migration backup. Keep earlier migrations as history.

### Genel simülasyon panelinin kaldırılması

233 numaralı migration, kaldırılan genel panelin `simulation_assertions` ve `simulation_run_events` tablolarını siler. Kampanya sürümü testlerinde kullanılan `simulation_scenarios` ve `simulation_runs` korunur; kampanya testine bağlı olmayan eski kayıtlar temizlenir. Rollback yalnız tablo yapısını geri kurar; silinen kayıtlar için migration öncesi yedek gerekir.
