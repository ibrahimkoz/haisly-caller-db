# Haisly DB

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
