#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../scripts/common.sh"
DATABASE_URL='postgresql:///must_never_be_used'
TEST_DATABASE_URL='postgresql:///caller_isolated_test'
[[ "$(database_url)" == "$TEST_DATABASE_URL" ]]
TEST_DATABASE_URL='postgresql:///haisly_caller'
if (database_url >/dev/null 2>&1); then
  echo 'Unsafe test database override was accepted' >&2
  exit 1
fi
echo 'Test database override guards passed.'
