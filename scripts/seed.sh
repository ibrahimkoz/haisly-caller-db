#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

mode="${1:---reference}"
if [[ "$#" -gt 1 || ( "$mode" != "--reference" && "$mode" != "--with-demo" ) ]]; then
  echo "Usage: $0 [--reference|--with-demo]" >&2
  exit 2
fi

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

  if [[ "$mode" == "--reference" && "$seed_name" == "002_demo_owner.sql" ]]; then
    continue
  fi
  echo "Applying seed: ${seed_name}"
  psql_command "${URL}" --single-transaction -f "${seed_file}"
done
