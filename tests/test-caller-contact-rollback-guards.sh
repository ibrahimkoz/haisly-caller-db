#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../scripts/common.sh"
: "${TEST_DATABASE_URL:?Explicit isolated TEST_DATABASE_URL is required}"
URL="$(database_url)"
ROOT="$(repo_root)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
for migration in 074_add_caller_contact_foundation 075_guard_canonical_contact_identity; do
  cat > "$work_dir/check.sql" <<'SQL'
INSERT INTO tenants (slug, name) VALUES ('rollback-contact-' || gen_random_uuid()::text, 'Synthetic rollback test') RETURNING id AS rollback_tenant_id \gset
INSERT INTO customers (tenant_id, customer_no, display_name, first_name, last_name, primary_phone, canonical_phone, contact_status_id, contact_state)
SELECT :rollback_tenant_id, 'rollback-example', 'Synthetic example', NULL, NULL, '+905321234567', '+905321234567', id, 'ready' FROM contact_statuses WHERE code = 'new';
SQL
  cat "$ROOT/rollbacks/$migration.down.sql" >> "$work_dir/check.sql"
  if psql_command "$URL" -X --single-transaction -f "$work_dir/check.sql" > "$work_dir/result.log" 2>&1; then
    echo "Rollback incorrectly accepted populated caller data: $migration" >&2
    exit 1
  fi
  case "$migration" in
    074*) expected='Caller contact data exists' ;;
    075*) expected='Canonical identities exist' ;;
  esac
  if ! grep -q "$expected" "$work_dir/result.log"; then
    echo "Rollback failed for an unexpected reason: $migration" >&2
    cat "$work_dir/result.log" >&2
    exit 1
  fi
  echo "Populated-data rollback guard passed: $migration"
done
