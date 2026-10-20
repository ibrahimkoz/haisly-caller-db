# Phase 2 — contact foundation checkpoint

Status (20 October 2026): F02-T01 foundation implemented and verified; Phase 2 is **not complete**. No new public API or client workflow is delivered by this checkpoint. Customer dispatch remains disabled.

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

## Dependency and verification

`libphonenumber-js` 1.13.15 (MIT) uses full `max` validation metadata; there were no runtime dependencies or install lifecycle hooks in registry metadata. It replaces unsafe handwritten international numbering rules. Installed with scripts disabled. Fresh npm audit: zero findings.

API `verify:ci`: 92 tests passed, zero skipped; typecheck/lint/build/OpenAPI passed. New tests cover normalization, invalid/local/extension rejection, dry-run, idempotent promotion, preserved duplicates, cross-tenant uniqueness, formatting-aware legacy guards, list/member uniqueness and cross-tenant FK rejection. Final bounded-lock change was retested with the four affected tests.

DB 074/075 upgrade, empty-data rollback/reapply and populated-data rollback refusal passed on `haisly_caller_phase1_test`. The local working `haisly_caller` and hosted inbound server were not migrated by this checkpoint.

## Remaining Phase 2 work

F02-T02–T05: authorized/idempotent/versioned person/list APIs and membership workflows; audited corrections and owner-only DNC removal; consent/history/eligibility services; runtime DNC tool with outbox and failure handling; client screens and negative/UI tests. Legacy write paths must route through those services before enabling caller contact editing. Existing history must be partitioned by identity revision before an ownership correction is exposed.

Phase-end commit/push policy remains in force. This is a foundation slice checkpoint, not Phase 2 acceptance or a release.
