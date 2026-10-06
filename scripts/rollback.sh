#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
  echo "Usage: $0 --last" >&2
}

if [[ "${1:-}" != "--last" || "$#" -ne 1 ]]; then
  usage
  exit 2
fi

load_local_env
require_command psql

ROOT="$(repo_root)"
URL="$(database_url)"

ensure_migration_table "${URL}"

last_migration="$(psql_command "${URL}" -tA -c "SELECT version FROM public.schema_migrations ORDER BY applied_at DESC, version DESC LIMIT 1;")"

if [[ -z "${last_migration}" ]]; then
  echo "No applied migrations to roll back."
  exit 0
fi

rollback_file="${ROOT}/rollbacks/${last_migration%.sql}.down.sql"

if [[ ! -f "${rollback_file}" ]]; then
  echo "Rollback file is missing for migration: ${last_migration}" >&2
  echo "Expected: ${rollback_file}" >&2
  exit 3
fi

assert_safe_sql_filename "${rollback_file}"

echo "Rolling back migration: ${last_migration}"
psql_command "${URL}" --single-transaction \
  -f "${rollback_file}" \
  -c "DELETE FROM public.schema_migrations WHERE version = '${last_migration}';"
