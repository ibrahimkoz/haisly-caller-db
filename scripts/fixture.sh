#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_local_env
require_command psql

ROOT="$(repo_root)"
URL="$(database_url)"

shopt -s nullglob
FIXTURES=("${ROOT}"/fixtures/*.sql)
shopt -u nullglob

if [[ "${#FIXTURES[@]}" -eq 0 ]]; then
  echo "No fixture files found."
  exit 0
fi

for fixture_file in "${FIXTURES[@]}"; do
  fixture_name="$(basename "${fixture_file}")"

  if [[ ! "${fixture_name}" =~ ^[a-z0-9_]+\.sql$ ]]; then
    echo "Unsafe or non-standard fixture filename: ${fixture_name}" >&2
    exit 2
  fi

  echo "Applying fixture: ${fixture_name}"
  psql_command "${URL}" --single-transaction -f "${fixture_file}"
done
