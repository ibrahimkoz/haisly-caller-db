# Phase 2 — contact and list checkpoint

Status (20 October 2026): F02-T01 and F02-T02 are implemented. F02-T05 manual person/list workflows are delivered; preferences/history UI is pending. Phase 2 is **not complete**. Customer dispatch remains disabled.

## Identity and compatibility

`customers` remains the canonical record; calls, cases and interactions keep their original foreign keys. Migration 074 adds nullable names, title, canonical phone, status FK, country/timezone, identity revision, version, archive and independent DNC fields. It also establishes list/member, preference history, purpose/country consent and prior-identity tables for subsequent slices. Migration 075 guards canonical numbers against legacy customer/contact writes. `(tenant_id, canonical_phone)` is unique; legacy unresolved records have no canonical phone and remain quarantined. The existing customer read contract returns empty name strings for nullable names, without inventing names.

`ready` means identity validation only, **not permission to call**. Consent, DNC, archive, status, schedule and campaign checks must still run in later services. No default consent or timezone verification is fabricated. Previously blocked/inactive legacy statuses remain unchanged.

## Backfill

Use an explicit database URL and tenant public UUID. Default is dry-run:

```sh
DATABASE_URL=... node --import tsx scripts/backfill-caller-contacts.ts --tenant=<uuid>
DATABASE_URL=... node --import tsx scripts/backfill-caller-contacts.ts --tenant=<uuid> --apply
```

At most 200 records per transaction; locks wait at most 3 seconds and statements at most 30 seconds. Apply takes short table locks to exclude concurrent legacy writers; schedule during low traffic. On failure the current batch rolls back; earlier batches remain and rerunning skips promoted identities. Logging contains counts/checkpoints, no raw phone or name. The SQL issue view provides unresolved record public IDs/reasons; the service dry-run additionally performs full phone validation and formatting-aware claim comparison.

Missing/invalid numbers, duplicate primary/secondary claims and multiple phone identities are not merged. Unscoped local/free-text secondary claims conservatively prevent promotion of other candidates in that tenant until corrected. Names and historical records are preserved. Country is validated from international metadata; timezone is never inferred from a city/area code. Local input requires an explicitly selected country. The library confirms number structure, not ownership or live reachability.

## API and client workflows

Session-authenticated `/api/v1/caller-contacts` supports tenant-scoped search, phone-only creation, detail and versioned name/title corrections with a required reason. `/api/v1/contact-lists` supports search, creation, rename, archive/unarchive, deletion and membership. Cursor pages are bounded to 100 items. Existing canonical numbers reuse the person without overwriting details. Unresolved legacy claims return 409. Phone/ownership changes are not exposed through profile edits.

Contact reads/edits require `caller.contacts.manage`; lists require `caller.lists.manage`; membership and the combined client screen require both. Legacy raw customer reads now require contact permission; the old update endpoint rejects canonical identities so it cannot bypass version/history checks. Tenant scoping and current authorization apply before replay.

All mutations require `Idempotency-Key`; resource mutations additionally require quoted numeric `If-Match`. Migration 076 stores tenant/actor/scope receipts atomically with writes and audit records. These session workflows are tenant-wide, whereas existing runtime receipts are environment-scoped. Payload/version mismatches and expired receipts return 409. Receipts expire after seven days but remain stored until the Phase 13 retention worker is implemented; their response bodies contain personal data and must be included in retention/deletion policies. Tenant advisory locking follows migration 075's lock order, bounded by a five-second lock timeout.

Unused lists can be deleted; previously used lists are archived. People and campaign targets are not deleted or appended by membership changes. Future campaign snapshot integration must set `first_used_at` in its transaction. Name/title changes append actor/reason/before/after history. List audit records identify the resource and relevant before/after state.

The bilingual client screen provides manual creation/profile editing, duplicate notice, list CRUD/archive impact confirmation, membership, search/pagination and loading/error/empty states. Failed mutations keep their idempotency key for retry; stale versions return a conflict requiring refresh. Excel/CSV import remains Phase 3.

## Local rollout

The local `haisly_caller` database is now at migration 076. Before migration, a custom-format dump was saved to `backups/haisly-caller-pre-phase2-2026-10-20/haisly_caller.dump`; its table of contents was checked (not a full restore rehearsal). Backfill preserved all 421 customers: 25 promoted to validated canonical identities; 396 without phones remain quarantined. No records were merged or deleted, no consent was fabricated. The hosted inbound server was unchanged. Do not run seed/fixture resets on this working database.

## Verification

`libphonenumber-js` 1.13.15 uses full `max` validation metadata. Fresh API and client npm audits reported zero findings on 20 October 2026.

API `verify:ci`: 93 tests passed, zero skipped; typecheck/lint/build/OpenAPI passed. The contact/list integration test additionally rechecked member removal, cross-list preservation and list audit before/after state. DB `verify.sh` passed on a fresh isolated `haisly_caller_phase2_schema_test`: 76 migrations, seeds/fixtures, final empty-table rollback/reapply and schema validation. Populated receipt rollback is intentionally guarded.

## Remaining Phase 2 work

F02-T03: status/consent/eligibility services, owner-only DNC removal and verified number/ownership correction. F02-T04: runtime DNC tool, preference outbox and failure handling. F02-T05: status/preference history and correction UI. Existing history must be partitioned by identity revision before ownership correction is exposed. Identity readiness alone never authorizes a call.

Phase-end commit/push policy remains in force. This is a vertical slice checkpoint, not Phase 2 acceptance or a production release.

Client verification: typecheck, lint (zero errors; six existing warnings), 292 tests across 73 files and production build passed. Two mocked-API Playwright workflows passed at 390px/1440px, including profile correction and list membership/archive; screenshots were visually reviewed with no horizontal overflow. Existing bundle-size warning remains. These browser tests complement real-DB API integration tests; they are not live end-to-end telephony tests.
