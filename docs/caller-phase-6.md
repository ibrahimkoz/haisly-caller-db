# Faz 6 — AI yapılandırması, bilgi kaynakları ve araçlar

Durum: Geliştirme sürüyor. Testler ve final kabul henüz yapılmadı.


### 2026-10-27 — Konuşma içeriği derleyicisi ve ön kontrol bağı

- Hedef dahil etme incelemesinde mevcut primitive'in yalnız gelecekteki doğrulanmış yayın transaction'ından çağrılması gerektiği doğrulandı. Taslaktan public hedef ekleme açılmadı; F04-T03/T06 için önce içerik/release/test bağı tamamlanmalı.
- F06-T01 için caller-content-v1 deterministik derleyici eklendi. Platform talimatı, tenant/agent temel talimatı, kampanya davranışı, konu ve amaç ayrı alanlarda tutulur. Türkçe/İngilizce AI kimliği, marka/amaç açıklaması, eksik kişisel alanda nötr hitap ve server-owned anket akışı tanımlıdır. Greeting yalnız ad/soyad/ünvan allowlist'ini alır; rastgele özellik/ifade çalıştırmaz, kontrol karakterini reddeder. Prompt metni araç/izin/tercih yetkisi yerine geçmez.
- Mevcut tenant.name ve seçilmiş agent.name ön kontrolde marka/asistan başlangıç değerleridir; temel talimat yayımlanmış, aktif, tenant kapsamındaki agent config_snapshot.instructions alanından alınır. Eksik/geçersiz içerik blocker üretir. Kampanya özel kimlik/ses override formu ve final immutable identity bağları hâlâ tamamlanmalı. Bu dilim gerçek greeting göndermez.
- GET campaign preflight repeatable-read içinde derler; yalnız durum, compiler sürümü, content/binding hash ve blocker döndürür. Prompt/agent içeriği/kişisel bilgi cevaba veya audit'e eklenmez. Binding hash agent snapshot'ı ve soru tanımını kapsar; kaynak listeler, hedefler, operasyon takvimi/sayıları ve bütçeyi kapsamaz. Mevcut definition_hash sözleşmesi korundu. Yeni hash sertifika veya nihai release hash'i değildir; ses kataloğu, bilgi/araç sürümleri ve gerçek test kanıtı ayrıca sabitlenmeli.
- Client içerik derlenmesinin yayın onayı olmadığını açıkça gösterir ve iki yeni içerik blocker'ını çevirir. Yayın, hedef dahil etme ve dispatch kapıları açılmadı; sağlayıcıya ağ isteği yapılmadı. DB migration/yazım yok.
- Derleyici için dil/AI açıklaması, eksik kişisel alan, izinli alan sınırı, kontrol karakteri, platform metninin tenant metninden ayrılması ve deterministik hash test kodları eklendi. Binding için takvim/liste değişiminde sabitlik, kimlik/voice/konu değişimi ve eksik içerik; API için prompt içermeyen metadata şekli; client için yayın onayı ayrımı test kodları eklendi. OpenAPI üretildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı.
- F06-T01 tamamlanmış sayılmadı: gerçek runtime tüketimi, immutable release, kimlik/ses override ve bilgi/araç sürüm bağları açık. Faz4–13 ve final kabul goal'u aktif.


### 2026-10-27 — Kampanyaya özel marka ve asistan kimliği

- DB125 kampanya taslak sürümüne nullable brand_name_override ve assistant_name_override alanları ekler. DB uzunluk/boşluk/kontrol karakteri sınırı uygular; API ayrıca Unicode kontrol/format karakterlerini reddeder ve metni trim eder. Kullanıcı değeri yazılmış veya saklanmış snapshot'ta bulunan alanlar varsa rollback veri kaybını önlemek için reddedilir.
- API settings alanı gönderilmezse mevcut override korunur; null varsayılana dönüş, metin açık özelleştirmedir. Eski client aynı settings içinde yeni alanları göndermese de korunur. Okuma iki alanı döndürür, içerik derleyicisi override→tenant/agent varsayılan sırasını uygular. İçerik/binding/authoring hash değişimi mevcut akıştan izlenir.
- Yeni authoring snapshot'ı açık override değerlerini saklar; clone bunları taşır. Null değer hâlâ miras tercihi anlamındadır; final release oluşturulurken çözülmüş kimlik ayrıca immutable sabitlenmelidir. Eski snapshot'lar değiştirilmedi. Kampanya override'ı tenant veya agent kaydını değiştirmez.
- Client konuşma kimliği alanları, varsayılan açıklaması ve yapay zekâ kimliğinin zorunlu kalması mesajını ekler. Boş input null gönderir; yalnız boşluk ve geçersiz karakter reddedilir. Formun mevcut düzenleme/iptal kilitleri korunur. Ses kataloğu/override, final release ve gerçek runtime bağı bu dilimde tamamlanmadı.
- Yerel haisly_caller özel izinli backups/haisly-caller-pre-identity-overrides-2026-10-27/haisly_caller.dump yedeği sonrası125 transaction içinde uygulandı. Gerçek kampanya içeriği değiştirilmedi. Restore/rollback provası yapılmadı; final izole test DB'lerine125 de uygulanmalı.
- Eski client koruması, explicit null, limit/kontrol karakteri reddi, snapshot'ın korunması, clone ve derleme hash'inin override/miras davranışı için API test kodu; form kaydetme/temizleme/boşluk reddi için client test kodu yazıldı. OpenAPI üretildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser/schema-validator çalıştırılmadı. Rollout DB125→API→client. F04/F06 ve kalan goal açık.


### 2026-10-27 — Authoring kopyasında çözülmüş kimlik sabitleme

- DB126 immutable caller_campaign_snapshots tablosuna nullable identity_snapshot ekler. Yapı yalnız marka ve nullable asistan adını taşır; tip/alan/uzunluk CHECK'i vardır. Eski kayıtlar null kalır; bugünkü tenant/agent adıyla geçmiş üretilmez. Kimlik kaydı varsa rollback reddedilir; mevcut immutable UPDATE/DELETE triggerı yeni alanı da korur.
- Yeni snapshot oluşturma override→tenant/agent varsayılanını okuyup çözülmüş kimliği saklar. Hash girdisi caller-authoring-snapshot-v2 oldu; kimlik değişimi aynı kampanya versionında bile yeni kopya üretir, aynı içerik yeniden kullanılır. Eski hash/definition_hash değerleri değiştirilmedi. Bu authoring hash'idir; release/test sertifikası değildir.
- Snapshot detayında resolved_identity ve comparison.identity_changed döner. Eski kayıtta ikisi null: karşılaştırma bilinmiyor. Client eski kimliği bugünkü isimle doldurmaz, yeni kopya gereksinimini açıklar; sabit kimlik varsa gösterir ve varsayılan isim farkını listeler. Ham agent snapshot'ı dışarı verilmez.
- Yerel DB yedeklenip126 transaction içinde uygulandı; geçmiş kimlik verisi backfill edilmedi. Yedek backups/haisly-caller-pre-snapshot-identity-2026-10-27/haisly_caller.dump. Restore/rollback/schema-validator çalıştırılmadı; final izole test DB'lerine126 da uygulanmalı.
- Varsayılan marka değişince eski snapshot değerinin korunması, yeni hash, aynı içerikte reuse ve immutable kimlik reddi API fixture'ı; clientta sabit kimlik/fark ve legacy unknown davranışı test kodları eklendi. OpenAPI üretildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı.
- Ses/bilgi/araç pinleri, final release kaydı ve test sertifikası, runtime'ın yalnız sabit sürümü tüketmesi ve tüm kalan fazlar açık. Clone yeni kampanya ayarıdır; null override tercihi yeni kampanyada güncel varsayılanı devralır. F04/F06 tamamlanmadı, goal aktif.


### 2026-10-27 — Saklanmış sürümden içerik derleme

- Ortak compileCallerBinding yalnız açık document, agent_snapshot ve identity_snapshot girdileriyle çalışır; DB/tenant/agent güncel varsayılanını kendi içinde okumaz. Taslak ön kontrolü mevcut varsayılanları açıkça çözerek bu servisi kullanır; snapshot detayı yalnız immutable satırdaki üç değeri kullanır. Duplicate derleme/hash mantığı kaldırıldı.
- Snapshot content_compilation durum/hash bilgisi döner. Eski identity_snapshot=null kaydı caller_snapshot_identity_missing ile blocked olur; bugünkü marka/asistan veya document override'ı geçmiş kimliğin yerine geçirilmez. Agent temel talimatı veya diğer zorunlu metinler eksikse içerik üretilmez. Derlenmiş özel içerik servis içinde kalır; public yanıt yalnız summary projeksiyonudur.
- Client kayıtlı sürümdeki derleme kaynağını ve bunun yayın/gerçek test onayı olmadığını belirtir; eksik kimlik/içerik blocker'larını gösterir. API OpenAPI ve client ortak ContentCompilation sözleşmesi eşitlendi. Gerçek provider/runtime çağrısı yapılmadı; yeni migration yok.
- Sabit içerik/hash'in güncel taslak/agent değişiminden etkilenmemesi, legacy kimlikte fallback reddi, eksik içerik, soru değişiminde binding değişimi, takvim değişiminde sabitlik ve summary'de prompt olmaması için test kodları eklendi. Snapshot API fixture ve client testi genişletildi. OpenAPI üretildi; kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı.
- Nihai release kaydı, compiler sürümüyle kalıcı derlenmiş çıktı sabitleme, ses/bilgi/araç pinleri ve test sertifikası bağları hâlâ açık. Bu okuma anında sürümlü authoring derlemesidir, canlı çağrı izni değildir. F04/F06 ve goal aktif.


### 2026-10-27 — Derlenmiş çıktının immutable snapshot'ta saklanması

- DB127 caller_campaign_snapshots.content_compilation_snapshot alanını ekler. Çıktı ve summary birlikte saklanır; compiler sürümü, release_certified=false, compiled/blocked ayrımı, hash biçimi, null/obje tutarlılığı, sabit kimlik eşleşmesi ve2MiB üst sınırı CHECK ile korunur. Mevcut immutable trigger çıktının değiştirilmesini/silinmesini engeller; veri varsa rollback reddedilir. Eski snapshot'lara yeni derleme backfill edilmedi.
- Snapshot oluşturma içerik derlemesini aynı mutation transaction'ında yapar. Authoring hash kapsamı v3 olup derleme çıktısı/summary dahil edilir; toplam payload sınırı da bu çıktıyı içerir. Eksik taslak saklanabilir, derleme sonucu blocked+null content olarak sabitlenir. Kimlik varsayılanları derleyiciyle aynı trim davranışıyla yakalanır.
- Detay okuması artık derleyiciyi tekrar çalıştırmaz: kaydedilmiş summary'nin yalnız izinli alanlarını döndürür. Eski compilation=null kayıt caller_snapshot_compilation_missing ile blocked olur; yeni snapshot oluşturulması gerekir. Servis/model katmanlarında derlenmiş çıktı/summary discriminated union ile ayrıldı. Ham prompt/agent talimatı public yanıta eklenmez.
- Client çıktı oluşturulurken saklandığını açıklar ve legacy eksik derleme uyarısını gösterir. Compiler değişimi eski artifact'ı yeniden yazmaz. Bu authoring çıktısıdır; ses/kaynak/araç doğrulaması ve gerçek test sertifikası olmadan release veya dispatch izni vermez.
- Yerel DB yedeklenip127 transaction içinde uygulandı. Yedek backups/haisly-caller-pre-compilation-snapshot-2026-10-27/haisly_caller.dump. Gerçek kampanya/derleme kaydı oluşturulmadı; restore/rollback/schema-validator çalıştırılmadı. Final izole test DB'lerine127 de uygulanmalı.
- Kalıcı blocked artifact varlığı, immutable çıktı silme reddi, public summary projeksiyonu, derleme olmadan legacy reddi test kodları eklendi; client metin testi güncellendi. OpenAPI üretildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Başarılı gerçek derleme persist/yayın/runtime kabulü final test kapsamına dahildir.
- Sonraki eksikler: ses ve bilgi/araç sürüm pinleri, release kaydı ve gerçek test/simülasyon sertifikaları, runtime bağlama; kalan Faz4–13 açık. Goal aktif.


### 2026-10-27 — Sunucu doğrulamalı metin ingest ve içerik mühürleme temeli

- Mevcut knowledge_source_versions/knowledge_chunks/knowledge_ingestion_jobs tabloları kullanıldı; paralel kütüphane kurulmadı. Legacy API'nin published/completed ve checksum alanlarını istemciden kabul ettiği saptandı. Bunlar doğrulanmış ingest kanıtı değildir; yeni sealed_at sinyali mevcut public payload'larda yazılamaz ve gelecekteki kaynak seçimi bu kanıtı aramalıdır.
- DB128 sealed_at/ingest_format/normalized_bytes alanlarını ve korumaları ekler. Seal INSERT ile verilemez; parçalar hazırken UPDATE ile DB'nin hesapladığı zaman/checksum/boyuta dönüşür. Tenant kapsamlı parçaların0'dan başlayan ardışıklığı, SHA-256 hash'leri,1–4096 parça ve toplam10MiB sınırı doğrulanır. Parent satır kilidi chunk yazımıyla seal yarışını sıralar. Mühürlü içerik/metadata/bağlar ve parçalar immutable'dır; arşivleme mümkündür, draft'a veya arşivden yayına geri dönüş reddedilir. Kontrollü retention/purge yolu ayrıca tasarlanmalıdır.
- normalizeKnowledgeText CRLF/CR→LF ve dış boşluk/BOM normalizasyonu yapar; içeriği/parça birleştirmesini korur, surrogate pair bölmez. Desteklenmeyen kontrol karakteri, bozuk Unicode, boş metin ve10MiB üstü reddedilir. Boşluk ağırlıklı büyük girdide parça ilerlemesi doğrusal taranır. Token sayısı/embedding uydurulmaz; null kalır.
- ingestTextVersion tenant kilidi ve kaynak satır kilidi altında yalnız aktif text kaynak/aktif koleksiyon için yeni sürüm+parçalar+DB seal+completed job kaydını aynı transaction'da üretir. Son checksum/boyut Node ve DB arasında karşılaştırılır; hata tüm yazıyı geri alır. Source ref URL'si indirilmez, ağ isteği yapılmaz. Bu internal primitive'dir; yetkili/idempotent/audit public komutu ve client sonraki dilimdir. PDF/DOCX/katalog/HTTPS parserları henüz bağlı değildir.
- Yerel DB özel izinli backups/haisly-caller-pre-knowledge-seal-2026-10-27/haisly_caller.dump yedeği sonrası128 transaction içinde uygulandı. Gerçek kaynak ingest edilmedi. Final izole DB'lere128 de uygulanmalı. Restore/rollback/schema-validator çalıştırılmadı.
- Normalizasyon/checksum/parça sürekliliği, emoji/boşluk sınırları, geçersiz ve büyük girdi; gerçek DB fixture'ında seal, immutable parça/sürüm, arşivleme ve legacy published kaydın sealsiz kalması test kodları eklendi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. DB triggerlarının davranış kanıtı final testte alınmalı.
- Kampanya kaynak seçimi/önceliği/sürüm pinleri, public ingest/UI, diğer dosya tipleri ve retrieval hâlâ açık. F06-T02 ve goal tamamlanmadı.


### 2026-10-27 — Yetkili metin ingest ve sürüm listeleme API'si

- POST /api/v1/knowledge-sources/:public_id/ingest-text agents.manage, tenant kapsamı, Idempotency-Key ve expected_version_no zorunluluğuyla mevcut ingest primitive'ine bağlandı. Beklenen sürüm source lock altında kontrol edilir; aynı key/body replay ikinci sürüm/job/audit oluşturmaz, farklı içerik veya eski sürüm409 verir. Yetki replay'den önce tekrar kontrol edilir.
- Başarı makbuzu UUID/sürüm/hash/boyut/parça sayısı/zaman içerir. Metin audit/receipt'e yazılmaz; audit knowledge kategorisi ve knowledge_source public kimliğiyle kaydolur. 10MiB UTF-8 metin,14MiB JSON body ve hassas endpoint rate limit uygulanır. Kontrol/bozuk Unicode/boş metin doğrulaması ortak validation katmanına taşındı. Normalize/ingest/seal işlemi dış ağ isteği yapmaz.
- GET aynı kaynağın /versions endpoint'i repeatable-read keyset sayfalama sunar. latest_version_no geçmiş sayfada da kaynağın güncel en büyük sürümüdür. sealed=false legacy kaydın istemci checksum'ı doğrulanmış checksum olarak gösterilmez; content_ref/metadata/metin döndürülmez. Her iki yanıt no-store'dur.
- OpenAPI eklendi/üretildi. İncelemede ortak OpenApiSchema TS tipinin mevcut OpenAPI3.1/JSON Schema2020-12 null/çoklu type ve number enum kullanımlarını temsil etmediği görüldü; tip tanımı gerçek sözleşmeyle uyumlu genişletildi. Bu değişiklik yayın veya test onayı değildir.
- API test kodu unauth/başka tenant, geçersiz metin, eşzamanlı replay, body/sürüm conflict, tek audit ve içerik sızmaması, sealed/legacy liste ayrımı, sayfalama ve yetki iptali sonrası replay reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Yeni DB migration/yazım yok; gerçek kaynak ingest edilmedi.
- Client metin giriş/sürüm yönetimi, kampanya kaynak pinleri, diğer formatlar ve retrieval açık. Faz6 ve tüm kalan goal aktif.
