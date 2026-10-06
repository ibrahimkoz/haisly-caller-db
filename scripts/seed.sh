#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_local_env
require_command psql

ROOT="$(repo_root)"
URL="$(database_url)"

shopt -s nullglob
SEEDS=("${ROOT}"/seeds/*.sql)
shopt -u nullglob

if [[ "${#SEEDS[@]}" -eq 0 ]]; then
  echo "No seed files found."
  exit 0
fi

for seed_file in "${SEEDS[@]}"; do
  seed_name="$(basename "${seed_file}")"

  if [[ ! "${seed_name}" =~ ^[a-z0-9_]+\.sql$ ]]; then
    echo "Unsafe or non-standard seed filename: ${seed_name}" >&2
    exit 2
  fi

  echo "Applying seed: ${seed_name}"
  psql_command "${URL}" --single-transaction -f "${seed_file}"
done
