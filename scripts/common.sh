#!/usr/bin/env bash

set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

load_local_env() {
  local root
  root="$(repo_root)"

  if [[ -f "${root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${root}/.env"
    set +a
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command is not available: ${command_name}" >&2
    exit 127
  fi
}

database_url() {
  # Explicit isolated-test override takes precedence over the local development .env.
  if [[ -n "${TEST_DATABASE_URL:-}" ]]; then
    if [[ ! "${TEST_DATABASE_URL%%\?*}" =~ /[a-zA-Z0-9_]*_test$ ]]; then
      echo "TEST_DATABASE_URL must point to a database ending in _test." >&2
      exit 2
    fi
    printf '%s\n' "${TEST_DATABASE_URL}"
    return 0
  fi

  if [[ -n "${DATABASE_URL:-}" ]]; then
    printf '%s\n' "${DATABASE_URL}"
    return 0
  fi

  local host="${POSTGRES_HOST:-localhost}"
  local port="${POSTGRES_PORT:-5432}"
  local database="${POSTGRES_DB:-}"
  local user="${POSTGRES_USER:-}"
  local password="${POSTGRES_PASSWORD:-}"

  if [[ -z "${database}" || -z "${user}" || -z "${password}" ]]; then
    echo "DATABASE_URL or POSTGRES_DB, POSTGRES_USER, and POSTGRES_PASSWORD must be set." >&2
    exit 2
  fi

  printf 'postgresql://%s:%s@%s:%s/%s\n' "${user}" "${password}" "${host}" "${port}" "${database}"
}

psql_command() {
  local url="$1"
  shift

  PGPASSWORD= psql "${url}" -v ON_ERROR_STOP=1 "$@"
}

ensure_migration_table() {
  local url="$1"

  psql_command "${url}" <<'SQL'
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL
}

assert_safe_sql_filename() {
  local path="$1"
  local name
  name="$(basename "${path}")"

  if [[ ! "${name}" =~ ^[0-9]{3}_[a-z0-9_]+(\.down)?\.sql$ ]]; then
    echo "Unsafe or non-standard SQL filename: ${name}" >&2
    exit 2
  fi
}
