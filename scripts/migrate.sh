#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_local_env
require_command psql

ROOT="$(repo_root)"
URL="$(database_url)"

ensure_migration_table "${URL}"

shopt -s nullglob
MIGRATIONS=("${ROOT}"/migrations/*.sql)
shopt -u nullglob

if [[ "${#MIGRATIONS[@]}" -eq 0 ]]; then
  echo "No migration files found."
  exit 0
fi

for migration_file in "${MIGRATIONS[@]}"; do
  assert_safe_sql_filename "${migration_file}"

  migration_name="$(basename "${migration_file}")"
  is_applied="$(psql_command "${URL}" -tA -c "SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '${migration_name}');")"

  if [[ "${is_applied}" == "t" ]]; then
    echo "Skipping already applied migration: ${migration_name}"
    continue
  fi

  echo "Applying migration: ${migration_name}"
  psql_command "${URL}" --single-transaction \
    -v migration_name="${migration_name}" \
    -f "${migration_file}" \
    -c "INSERT INTO public.schema_migrations (version) VALUES ('${migration_name}');"
done
