# Connection Conventions

## Local Database

Local development uses Docker Compose with PostgreSQL 17 by default. PostgreSQL 18 can be tested by overriding `POSTGRES_IMAGE` when a compatible image is available.

Required local settings are documented in `.env.example`:

```txt
POSTGRES_IMAGE=postgres:17-alpine
POSTGRES_DB=haisly_db
POSTGRES_USER=haisly
POSTGRES_PASSWORD=haisly_local_password
POSTGRES_PORT=5432
DATABASE_URL=postgresql://haisly:haisly_local_password@localhost:5432/haisly_db
```

These development credentials are not production credentials. Production database users, passwords, hostnames, TLS requirements, and privilege separation must be supplied by the deployment environment or secret management layer.

## Script Contract

Repository scripts should read `DATABASE_URL` first. If `DATABASE_URL` is not set, scripts may build a connection string from:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_HOST`
- `POSTGRES_PORT`

Scripts must fail fast when a required connection value is missing and must not echo passwords or full connection strings into logs.

## Privilege Model

The local Docker Compose database uses a single development role to keep Phase 0 simple. Production should use separate roles for migration ownership and application runtime access once deployment topology is defined.
