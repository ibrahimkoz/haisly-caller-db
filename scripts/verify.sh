#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT}/scripts/migrate.sh"
"${ROOT}/scripts/validate-schema.sh"
"${ROOT}/scripts/seed.sh"
"${ROOT}/scripts/fixture.sh"
"${ROOT}/scripts/validate-schema.sh"
"${ROOT}/scripts/rollback.sh" --last
"${ROOT}/scripts/migrate.sh"
"${ROOT}/scripts/validate-schema.sh"
