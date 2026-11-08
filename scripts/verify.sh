#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${TEST_DATABASE_URL:-}" ]]; then
  echo "Set TEST_DATABASE_URL to an isolated database ending in _test." >&2
  exit 2
fi
# common.sh validates the isolated target before connecting. No demo data or
# rollback: migrations 234/235 require restoring a backup, not an empty undo.
"${ROOT}/scripts/migrate.sh"
"${ROOT}/scripts/seed.sh" --reference
"${ROOT}/scripts/validate-schema.sh"
