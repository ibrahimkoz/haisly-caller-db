# Caller phase 1 — database foundation

Decision (20 October 2026): each phase ends with repo-local commits, pushes and
sync checks across API, client and DB. Unchanged repos do not need empty commits.

072 adds job lease expiry, active attempt number and explicit retry safety.
An index supports tenant-scoped expired lease recovery. Stop legacy workers
before migration. 073 adds fine-grained caller permissions and editor/analyst
roles. Existing system operations/support/sales grants are synchronized; custom
roles are retained. New-tenant role bootstrap is kept in sync in the API repo.

Run schema verification only with an isolated database:

```sh
TEST_DATABASE_URL=postgresql:///haisly_caller_phase1_test ./scripts/verify.sh
```

The explicit test URL overrides the development .env and must name a database
ending in `_test`. Verification performs seeds, fixtures and rollback/reapply;
never target the imported `haisly_caller` data with this command. A dedicated
sentinel test validates the override without opening a database connection.

072 rollback refuses while running jobs exist. 073 rollback deliberately retains
the permission catalog and narrowed grants; automatically restoring broader old
permissions would weaken access control. Real-environment rollback uses forward
fixes and compatible application versions rather than dropping data.

## Verification record — 20 October 2026

API full verification: 88 passed, 0 skipped, typecheck/lint/build/OpenAPI passed.
Client: 288 tests passed, typecheck/lint/build passed; 6 existing lint warnings
and the existing bundle-size warning remain. Desktop/mobile browser regression:
4 passed. Database migrations 072/073 verified on the isolated test DB; local
haisly_caller upgraded to 73 after a pre-phase backup (no seeds/fixtures on it).

Dependency remediation completed on 20 October 2026 (F01-T07). Fresh npm audits
report zero vulnerabilities for both API and client. Fastify/fast-uri/Nodemailer
and the affected client test/build dependencies were upgraded; the API/client
security-audit-2026-10-20.md reports preserve the initial findings and record
resolved versions and verification. Nodemailer major compatibility is covered
by an authenticated local SMTP regression for auth codes and invitations.
API: 88 passed, 0 skipped, typecheck/lint/build/OpenAPI passed. Client: 288 passed,
typecheck/lint/build passed; targeted desktop/mobile Playwright: 4 passed.
The existing six client lint warnings and bundle-size warning remain.
Phase 1 security closure is complete. No new schema migration was needed;
Phase 2 has not started and customer-call dispatch remains disabled.
