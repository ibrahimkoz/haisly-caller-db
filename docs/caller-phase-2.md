# Phase 2 — contact and list checkpoint

Status (20 October 2026): F02-T01/T02/T03 backend are implemented. F02-T05 manual person/list and read-only history workflows are delivered; preference/identity editing UI is pending. F02-T04 runtime DNC/outbox and shared eligibility reads are implemented; dispatcher/tool consumers remain pending. Phase 2 is **not complete**. Customer dispatch remains disabled.

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

## Preference service checkpoint — 20 October 2026

F02-T03 is partially implemented through three authenticated endpoints:

- `PATCH /api/v1/caller-contacts/{public_id}/do-not-call`: set the tenant-wide block; removing it requires both contact/unblock permissions and the active `owner` role, rechecked on receipt replay. Removal requires a reason, evidence reference and renewed-request timestamp strictly after the latest refusal and no later than now. Repeated explicit refusals supersede older renewal evidence. No evidence URL is fetched; the reference is an operator-supplied record locator, not automatic evidence verification.
- `POST /api/v1/caller-contacts/{public_id}/consents`: grant or withdraw for the current identity revision, purpose (`marketing`/`survey`) and country. Records retain source, reason, evidence and event time. Replacement/withdrawal closes every active grant for the scope. Equal/older evidence is rejected; delayed grants cannot revive withdrawn consent. A grant requires a validated canonical identity and matching country, and never clears DNC.
- `GET /api/v1/caller-contacts/{public_id}/eligibility?purpose=marketing&country_code=TR`: a single-statement snapshot reports contact prerequisites and explicit blockers. DNC, archive, blocked legacy status, invalid/unverified identity, blocking number status, country mismatch and missing current-revision consent fail closed. `contact_eligible` is **not** permission to dispatch: schedule, campaign, country policy, limits, budget and provider gates remain pending.

Writes use the existing tenant lock, expected version and atomic mutation receipt/history/audit transaction. No new migration or local/hosted customer data change was needed. Existing migrations 074/076 supply the fields and tables. Real-DB tests run only on `haisly_caller_phase1_test` with synthetic tenants.

Verification: API full `verify:ci` passed (94 tests, zero skipped; typecheck/lint/build/OpenAPI). The subsequent consent-query extraction passed typecheck and the targeted preference integration test. npm audit: zero findings; no dependencies added. Tests cover wrong tenant, unauthenticated access, mass assignment, missing/old/future evidence, stale consent, owner-role enforcement even with an explicitly granted unblock permission, replay after owner loss, preserved DNC on consent grant, purpose isolation, old-identity consent rejection, archive and invalid-number blockers, and append-only history/replay counts.

Remaining F02-T03: status event/correction APIs, verified wrong-number/ownership change and history partitioning. F02-T04 runtime DNC/outbox/dispatch gates and F02-T05 preference/history UI remain unimplemented. This checkpoint changes API behavior only; client screens are unchanged. Outbound dispatch remains disabled and Phase 2 remains incomplete.

## Status and history checkpoint — 20 October 2026

`PATCH /api/v1/caller-contacts/{public_id}/status` records a reasoned, strictly newer status event with optimistic version and idempotency. Future/equal/older event timestamps are rejected. Restoring `invalid` to `reachable` requires a `correction.evidence_reference`, an already validated unchanged canonical number, and active owner or operations-manager role; role is checked before receipt replay. A general status update cannot clear `invalid`, and `owner_changed` cannot be cleared or laundered through another status. DNC, consent and identity revision remain unchanged. Evidence references represent an operator verification record, not an automated ownership verification service.

`GET /api/v1/caller-contacts/{public_id}/history` returns only current-identity events, with recording-order keyset pagination (`limit` 1–100, `before` public UUID). The cursor must belong to that tenant, contact and revision. A repeatable-read snapshot keeps identity and event selection consistent. Public actor/event UUIDs are mapped explicitly; internal IDs and unapproved before/after fields are excluded. An empty current revision does not fall back to another person's history.

Client list rows now open a bilingual preference-history panel: event/reason, status or consent scope, evidence reference as inert text, event/recording timestamps, older/newest pagination, loading/error/retry/empty states and keyboard focus return on close. It is read-only; status and preference editing screens remain pending.

No migration is needed; existing status timestamp and event indexes are reused. Local working data and hosted inbound server are unchanged. Status-change tests cover stale/future observations, version conflicts, evidence validation, role loss on replay, operations-manager correction, preserved DNC, owner-changed bypass prevention, history pagination, tenant/permission isolation and prior-identity cursor rejection.

Ownership/phone correction remains closed until historical calls/cases/interactions are partitioned by identity revision; legacy readers currently join mutable customer rows. F02-T03 remains partial. F02-T04 runtime DNC/outbox and remaining F02-T05 preference editing/history details are pending. Phase 2 is not complete.

Status/history verification: API `verify:ci` passed 95 tests with zero skips, typecheck/lint/build/OpenAPI. Final client suite passed 294 tests across 73 files; typecheck, lint (zero errors, six pre-existing warnings), build and two 390px/1440px mocked-API browser workflows passed. History screenshots were reviewed; no horizontal overflow. Both npm audits reported zero findings. Existing client bundle-size warning remains.

## Historical identity snapshot checkpoint — 20 October 2026

Migrations 077/078 freeze the customer revision and display/first/last names on `customer_interactions`, and the customer revision on `cases`. Existing records are backfilled from the identity currently recorded on the customer; earlier ownership changes cannot be reconstructed from unavailable evidence. No customer/history IDs are replaced. Insert triggers derive snapshots from the tenant-owned customer under a shared row lock rather than accepting caller-supplied names. Updates cannot reassign the identity, snapshots, call/case relationship or historical timestamps. New interactions cannot attach a different identity to a call or an already identified case. Events older than a recorded prior-identity boundary require explicit reconciliation instead of silently joining the new owner.

Call readers use historical name snapshots. Their customer profile link becomes null when the interaction revision differs from the current customer revision. Case readers similarly omit the current-person link for an older revision. Customer-scoped interaction list/detail only return the current revision. Historical rows remain stored; historical calls/cases remain accessible through their own authorized endpoints. The existing nullable public contract is preserved, so no client runtime change is required.

Deploy DB 077/078 before this API checkpoint. Both migrations use existing PostgreSQL infrastructure; snapshot backfill has a five-second lock wait and sixty-second statement limit. Larger production datasets need a separately planned bounded backfill; this local migration is not a production deployment. 077 rollback refuses when any historical snapshot cannot be reconstructed from current identity. 078 rollback only removes relationship guards; never use it to bypass historical identity reconciliation.

Local rollout: custom-format backup `backups/haisly-caller-pre-identity-2026-10-20/haisly_caller.dump` was created and its contents list checked (not a full restore rehearsal). Local `haisly_caller` is at migration 078. Counts before/after match: 421 customers, 588 interactions, 588 calls, 0 cases. No records were deleted. The hosted inbound server is unchanged.

Verification: API `verify:ci` passed 96 tests, zero skipped, typecheck/lint/build/OpenAPI. New integration coverage verifies preserved call names after profile edits, null current-owner links after a test-only revision transition, old interaction exclusion/404, rejection of snapshot/relationship/revision rewrites, rejection of late or wrong-identity interactions, fresh current-identity writes and tenant isolation. Fresh `haisly_caller_identity_schema_test` passed all 78 migrations, empty rollback of 078 and 077, reapply, seeds/fixtures and standard schema verification. Populated 077 rollback refusal was tested inside a transaction that cannot commit changes. npm audit returned zero findings. No client runtime code or dependencies changed in this slice.

This is a history-foundation slice, not an enabled ownership-change workflow. Before exposing owner/phone correction, partition or reconcile remaining customer references (lead/follow-up, handoff, workflow/external references and compliance), related-call linking and late finalization. Guard active calls, preserve tenant DNC and isolate old consent/list/campaign identity as required. F02-T03 remains partial; F02-T04 and remaining preference editing UI are still open. No production calling is enabled.

## Related historical identities checkpoint — 20 October 2026

079 adds `customer_identity_revision` to leads, follow-up tasks, handoff requests, workflow runs, external object references and legacy consent records. Handoff names are snapshotted. Existing data is backfilled from the currently recorded identity without merging or replacing records. Lead/task readers suppress the current-person link for older revisions; handoff readers retain historical names and suppress that link. Existing nullable response shapes remain unchanged. Workflow/external/compliance writers now retain the revision even where no public history reader exists yet.

Insert guards validate related calls/sessions/cases/leads/workflows against the same tenant/customer/revision and reject records dated before the current identity boundary. They also protect case/interaction inserts from attaching an unidentified old call to a new owner. Updates cannot change historical identity, source relationships or timestamps. Initial conversion of an unassigned lead remains supported; reassignment of an already identified lead returns 409. Named history constraint errors map to a sanitized conflict response without SQL details.

080 serializes association checks using call row locks and shared related-resource locks. Before an unassigned lead is converted, its tasks/handoffs/workflows/external references must agree with the target identity. Checks account for calls already associated through those resources, even before a customer interaction exists. A concurrent child write holds conversion until its identity is visible. 081 adds partial indexes for reverse call/session/lead lookups so these guards do not depend on broad history scans. Shared customer row locks serialize snapshots with identity changes; the final ownership-changing service still needs a consistent lock order and active-work reconciliation.

Deploy 079–081 before the API changes. 079 rollback refuses when historical revisions or handoff names differ from the current customer. 080 rollback restores 079 guards and requires association writers to be paused; 081 removes only indexes. Production-sized migration planning and zero-downtime rollout remain separate; this is local development.

Local `haisly_caller` is at migration 081, backed up before this slice to `backups/haisly-caller-pre-related-identity-2026-10-20/haisly_caller.dump` (contents list checked, not a restore rehearsal). Counts preserved: 421 customers, 18 leads, 176 follow-up tasks, 27 handoffs, 588 calls and 588 interactions; workflows, external references and legacy consent records each remain at zero. Hosted inbound data is untouched.

Verification: API full `verify:ci` passed 97 tests with zero skips, typecheck/lint/build/OpenAPI. Tests exercise all six revision tables, historical handoff names, old-profile link suppression, source/identity immutability, sanitized conflicts, old-call rejection, ordinary unassigned-lead conversion, conflicting dependent rejection, cross-tenant reads and concurrent child-insert/conversion locking. The fresh schema test covered 79 from scratch and 80/81 upgrades, seeds/fixtures, rollback/reapply and schema validation. A transaction-only test confirmed populated 079 rollback refusal. API npm audit: zero findings; no dependencies added. Client runtime code is unchanged.

The ownership/phone correction endpoint is still disabled. Next: preserve secondary contact channels and profile details, block/reconcile active work and late finalization, then implement an audited atomic revision transition with DNC preserved and old consent isolated. F02-T03 remains partial, with runtime DNC/outbox and preference editing UI also pending.

### İkincil iletişim kanalları ve profil arşivi — 20 Ekim 2026

082 migrationı ek telefon/e-posta kanallarını kimlik revizyonuna bağlar. Güncel kişi list/detail sorguları ve AI finalize eşleştirmesi yalnızca mevcut revizyonu kullanır. Eski kanalın kimliği ve içeriği UPDATE ile değiştirilemez; aynı değer yeni revizyonda ayrıca doğrulanarak kaydedilebilir. Tarihsel telefon iddiaları canonical tekillik korumasında bilinçli olarak tutulur; numara düzeltmesi eski numarayı otomatik olarak serbest bırakmaz.

083 migrationı kimlik arşivi oluşturulurken mevcut profilin ad, telefon, e-posta, ünvan, not, metadata, ülke/saat dilimi ve durum alanlarını DB tarafından snapshot olarak kaydeder. Arşiv UPDATE ile değiştirilemez; geçmişte oluşturulmuş arşivler için bilinmeyen profil NULL kalır, yeni sahibin verisiyle doldurulmaz. Bu alanlar yeni bir public API ile açılmadı.

Doğrulama: 97 API testi, typecheck/lint/build/OpenAPI; migration/fixture/rollback/reapply kontrolleri. Client runtime değişmedi. Yerel çalışma DB yedeklenerek 083'e geçirildi. DNC, izinler ve liste üyelikleri değişmedi.

F02-T03 hâlâ kısmi: aktif iş/geç finalize koruması, atomik sahip/numara düzeltme endpoint'i ve tercih düzenleme UI'si sırada. Bu dilim düzeltme endpoint'ini açmaz. F02-T04 runtime DNC/outbox işi ayrıca bekliyor.

### Atomik sahip/numara düzeltme API’si — 20 Ekim 2026

`POST /api/v1/caller-contacts/:public_id/identity` eklendi. `kind` owner_change veya phone_correction, phone, reason ve evidence_reference zorunlu; Idempotency-Key ve If-Match gerekir. Owner/operations_manager rolü ile contacts.manage ve lists.manage izinleri birlikte kontrol edilir; rol kontrolü replay öncesinde yapılır. Tenant kapsamı, sürüm ve numara/legacy claim çakışmaları korunur.

Sahip değişimi aynı canonical numarada yeni kimlik revizyonu açar; opsiyonel ad/soyad/ünvan yeni kişiye aittir. Eski profil arşivlenir; not/metadata ve liste üyelikleri temizlenir, etkilenen liste sürümleri artar. Telefon düzeltmesi farklı doğrulanmış numara ister; ad/ünvan/not/metadata ve liste üyelikleri korunur. Her iki işlem ek kanalları eski revizyonda bırakır, primary email ve doğrulanmış saat dilimini temizler, aktif izinleri kapatır, durumu new yapar; DNC ve legacy blocked durumu korunur. Eski canonical numara tarihsel kanal olarak rezerv tutulur, yeniden kişi oluşturup DNC aşma yolu açılmaz. İzin yeniden kaydedilmeden yeni kimlik aramaya uygun olmaz.

Aktif vaka, lead, görev, handoff, workflow/dış işlem ve bağlı görüşme varken 409 alınır; otomatik sonlandırma yapılmaz. Legacy AI oturumlarında caller numarasının son 10 hanesiyle aktif oturum kontrolü muhafazakârdır (ülke kodu farklı ama son 10 hanesi aynı numarayı da engelleyebilir). Caller bilgisi olmayan eski oturumlar kişiye bağlanamaz; geç finalize işleminde oturum tarihi ve revizyon sınırı kontrol edilir, eski numara rezervinden yeni kişi oluşturulmaz. Tam outbound hedef/deneme bağlantısı ilgili sonraki fazda kurulacaktır.

084–086 migrationları eski revizyona ait işleri/görüşmeleri yeniden aktifleştirmeyi engeller; AI oturumları ve finalize aynı tenant kilidiyle düzeltmeye karşı sıralanır. Tarihsel işi terminal duruma alma mümkündür. API yeni migrationlardan sonra dağıtılmalıdır; guard rollback öncesinde kimlik düzeltme endpoint’i kapatılmalı/yazıcılar durdurulmalıdır.

Doğrulama: tam API 98 test, typecheck/lint/build/OpenAPI ve npm audit 0 bulgu. Ek hedefli test: aktif iş/oturum reddi, eski finalize rollback’i, DNC ve izin izolasyonu, liste ayrımı, telefon rezervi/çakışması, tenant/rol/replay kontrolleri, operasyon rolüyle eşzamanlı iki düzeltmeden yalnızca birinin uygulanması. Test DB migration/fixture/rollback/reapply geçti. Client runtime değişmedi; tercih ve düzeltme formu hâlâ bekliyor. F02-T03 backend uygulandı; Faz 2 tamamlanmadı. F02-T04 runtime DNC/outbox ve F02-T05 kalan UI işleri sürüyor.

Yerel `haisly_caller` 086 seviyesine geçirildi; 421 kişi, 588 çağrı, 25 ek kanal ve 176 görev sayıları korundu. Öncesinde `backups/haisly-caller-pre-identity-correction-2026-10-20/haisly_caller.dump` alındı ve arşiv listesi okundu; tam restore provası yapılmadı.

### Runtime DNC ve tercih outbox altyapısı — 20 Ekim 2026

İmzalı `POST /api/internal/v1/call-sessions/:call_session_public_id/do-not-call` eklendi. `runtime.preferences.write` scope’u, servis anahtarı/imzası ve tenant/environment doğrulanır. Payload contact_public_id, identity_revision, idempotency_key, reason ve evidence_reference ister; block kaldırma alanı yoktur. Görüşme ile kişi/revizyon ilişkisi DB’de etkileşim veya oturuma bağlı handoff/consent kaydından doğrulanır. Henüz ilişkisi kurulmamış oturum 409 alır; gelecek outbound hedef/deneme akışı ilişkiyi çağrı öncesinde kurmalıdır. Tenant kilidi altında DNC, kişi sürümü, geçmiş, servis hesabı audit’i, idempotency cevabı ve outbox tek transaction’dır. Replay scope yetkisini tekrar kontrol eder; aynı anahtar/farklı içerik reddedilir. Başarılı cevap `stop_further_actions: true` içerir; bu bir runtime sözleşmesidir, provider kapatma işlemi yapılmış sayılmaz.

`POST /api/internal/v1/caller-contacts/:public_id/eligibility`, `runtime.preferences.read` scope’u ile tenant ekranıyla aynı authoritative DB sorgusunu kullanır. Amaç ve ülke, DNC, durum, revizyon/izin ve arşiv kontrol edilir. Bu cevap yalnız kişi önkoşuludur; dispatcher kararı, kota/saat aralığı ve çağrı başlatma yetkisi değildir. Karar anında tekrar okunmalıdır.

087 migrationı tercih/durum/kimlik/arşiv geçmiş olaylarından `caller.contact_preference.changed` outbox olayını atomik üretir. Anahtar geçmiş olayının public ID’sidir. Payload schema_version, event_public_id, contact_public_id, identity_revision, contact_version, event_type ve occurred_at içerir; telefon, gerekçe ve kanıt içermez. DNC ve izinlerin manuel API yolları da kapsamdadır. Eski olaylar geriye dönük yayınlanmaz. Consumer henüz yoktur; olaylar pending kalır, teslim edilmiş sayılmaz. Sonraki dispatcher/araç entegrasyonu güncel tercihi tekrar okuyacak; eski veya sırasız olayı yeni izin gibi uygulamayacak. Bu bağlantı tamamlanmadan F02-T04 bütünüyle kapatılmaz.

Beklenmeyen persistence hatası 503 döndürür ve runtime’a sonraki aksiyonları durdurup aynı anahtarla tekrar denemesini bildirir. Ayrı işlemde yalnız aktif owner/operations_manager kullanıcılarına kritik sistem bildirimi denenir; DB tamamen erişilemezse bildirim kalıcılaştırılamayabilir, yapılandırılmış hata logu ve 503 korunur. Beklenen auth/kaynak/ilişki çakışmaları 401/403/404/409 olarak kalır. Raw hata veya kanıt loglanmaz. Runtime idempotency kayıtları için mevcut altyapı kullanılır; cleanup politikası Faz 13’te replay güvenliğini korumalıdır.

Doğrulama: tam API 99 test, tip/lint/build/OpenAPI ve npm audit 0 bulgu. Outbox hatası enjekte edilen entegrasyon testinde kişi/geçmiş/receipt rollback’i, operasyon bildirimi ve aynı anahtarla başarılı retry doğrulandı. Eşzamanlı replay, scope iptali, environment/ilişki reddi, güncel uygunluk ve manuel tercih outbox eşleşmesi test edildi. Migration/fixture/rollback/reapply geçti. Yerel DB 087’ye yedekle geçirildi; 421 kişi ve 588 çağrı korundu, mevcut geçmiş/outbox sayısı 0 olarak kaldı. Yedek: `backups/haisly-caller-pre-runtime-preference-2026-10-20/haisly_caller.dump`; arşiv listesi okundu, tam restore provası yapılmadı.

Client runtime değişmedi; tercih/kimlik düzenleme UI’si sırada. F02-T04 yazma/outbox/ortak okuma kısmı hazır, dispatcher ve araç uygulama bağlantıları sonraki ilgili fazlarda tamamlanacak. Faz 2 tamamlanmadı.
