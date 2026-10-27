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


### 2026-10-27 — Kalıcı bilgi kaynağı envanteri

- GET /api/v1/knowledge-collections ve /knowledge-sources tenant kapsamında agents.manage yetkisiyle sayfalı envanter döndürür. UUID artan sıralı after cursor ve 1–100 limit kullanılır; tarih sırası vaat edilmez. Kaynak/koleksiyon pasif durumları görünür kalır. Kaynak referansı, metadata, içerik ve internal ID döndürülmez; yanıtlar no-store'dur.
- Client için envanter, sürüm okuma ve idempotent metin işleme RTK Query sözleşmeleri eklendi. Eski sayfa yalnız yerel state kullandığı için ekran entegrasyonu ayrıca devam ediyor; bu dilim UI tamamlandı anlamına gelmez.
- Tenant izolasyonu, kimlik/yetki reddi, geçersiz sayfalama, iki sayfada kayıtların tekrarsız okunması, arşivli kaynak görünürlüğü ve hassas alanların dışarı çıkmaması test koduna eklendi. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı. OpenAPI üretildi; yeni migration veya DB veri yazımı yok.
- Sonraki iş: kalıcı envanteri sayfaya bağlamak, metin ingest ve doğrulanmış sürüm akışını göstermek. Kampanya kaynak pinleri, diğer dosya türleri ve retrieval açık; Faz6 ve goal aktif.


### 2026-10-27 — Kaynak ekranı ve metin sürümü akışı

- Sources route ailesi artık tenant/yetki kontrollü gerçek envanteri kullanır. UUID cursor sayfalama, yenileme, yükleme/hata/boş durumları ve kalıcı kaynak detay bağlantıları eklendi. Metin kaynağı oluşturma ve aktif koleksiyon seçimi/oluşturma aynı akıştadır; koleksiyon seçimi de sayfalıdır. Tenant değişince form state yeniden oluşturulur.
- Kaynak detayında sürüm geçmişi, sealed doğrulama durumu, arşiv işareti, normalize boyut/format gösterilir. Legacy published kayıt doğrulanmış sayılmaz. Metin yeni sürüm olarak gönderilir; expected_version_no güncel liste yanıtından alınır. Belirsiz ağ/5xx sonucunda istek anahtarı+gövde bellekte korunur, metin ve ekran içi kaynak değiştirme kilitlenir; tekrar aynı komutu gönderir. Kesin hata sonrası metin korunur ve sürümler yenilenir. Başarı kampanya bağlama/yayın onayı değildir.
- UI test kodu doğrulanmamış legacy ayrımı, belirsiz sonuçta aynı key/body replay ve conflict sonrası metin korunmasını kapsar; kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Görsel/tarayıcı kabulü finalde yapılmalı.
- Kalanlar: eski collections/sourceVersions/jobs/bindings sayfalarının kalıcı akışa taşınması ve eski kullanılmayan kaynak formunun temizlenmesi; create komutlarının idempotency ile güçlendirilmesi; tam sayfa reload/router navigasyonunda pending recovery; diğer formatlar, kaynak pinleri ve retrieval. Yeni create komutlarına otomatik retry eklenmedi. Bu dilim yalnız sources route ailesini değiştirir; tüm bilgi bankası veya Faz6 tamamlanmış değildir. API/DB sözleşmesi veya şema değişmedi.


### 2026-10-27 — Kaynak/koleksiyon oluşturma replay koruması

- Mevcut POST koleksiyon/kaynak uçları isteğe bağlı Idempotency-Key kabul eder. Anahtarlı çağrı tenant+actor+scope receipt, oluşturma ve audit kaydını ortak transaction/tenant kilidinde birleştirir. Aynı gövde aynı sonucu döndürür; farklı gövde 409; replay öncesi güncel yetki doğrulanır. Eski anahtarsız çağrıların uyumluluğu korundu, bunlara replay garantisi verilmez. Yanıtlar no-store. Audit doğru kaynak/koleksiyon public ID'sini içerir, source_ref/metadata audit'e kopyalanmaz.
- Yeni kaynak ekranı oluşturma başına anahtar ve tam payload (üretilen code/source_ref dahil) saklar. Belirsiz sonuçta alanları/diğer oluşturma işlemini kilitler ve aynı düğmeyle aynı isteği tekrar gönderir. Başarı/kesin ret sonrası pending temizlenir; bilinmeyen sonuçta yeni kimlik üretilmez. Bellekteki pending tam sayfa reload/router geçişinden sonra henüz kurtarılmaz.
- Eşzamanlı aynı-key oluşturma, body conflict, tenant ayrımı, audit kimliği/hassas veri yokluğu ve yetki iptali sonrası replay reddi API test koduna eklendi. Client test kodu iki oluşturma türünde de aynı key/body tekrarını ve alan kilitlerini kapsar. Test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Yeni DB migration/yazımı yok.
- Sonraki işler: eski bilgi bankası sayfalarının kalıcı akışa taşınması, pending recovery, diğer formatlar, pinler ve retrieval. Faz6 ve goal aktif.


### 2026-10-27 — Kalıcı koleksiyon ekranı ve kaynak filtresi

- Collections route ailesi tenant/yetki kontrollü gerçek envanter ekranına taşındı; sayfalama, yenileme, yükleme/hata/boş durumları ve gerçek aktif/pasif/arşiv durumu gösterilir. Uydurma tarih/sayı ve sunucuya yazmadan başarı mesajı veren eski koleksiyon düzenlemesi bu route'tan erişilmez. Detay/eski edit bağlantısı koleksiyon kaynaklarını açar; gerçek metadata düzenleme/arşivleme komutu hâlâ eklenmelidir. Oluşturma mevcut güvenli koleksiyon+metin kaynağı akışına yönlendirilir.
- GET knowledge-sources collection_public_id UUID filtresini destekler; tenant koşulu korunur. Bilinmeyen/başka tenant koleksiyon filtresi kaynak sızdırmadan boş sayfa döndürür. Client koleksiyon kapsamını kaynak detayı/geri dönüşte korur; koleksiyon değişince cursor/form state sıfırlanır ve yeni kaynak formu seçilen koleksiyonla başlar.
- Filtreyle yalnız doğru kaynağın dönmesi, boş koleksiyon, geçersiz UUID ve başka tenant filtresi API test koduna eklendi. Test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Yeni şema veya veri yazımı yok.
- Legacy sourceVersions/jobs/bindings sayfaları, kullanılmayan legacy form kodlarının kaldırılması, metadata düzenleme/arşivleme, tam pending recovery, diğer formatlar, pinler ve retrieval açık. Faz6 ve goal tamamlanmadı.


### 2026-10-27 — Bilgi kaynağı/koleksiyon ad ve durum düzenleme

- PATCH /knowledge-collections/:public_id ve /knowledge-sources/:public_id eklendi. agents.manage, zorunlu Idempotency-Key, tenant kapsamı, ortak transaction kilidi ve satır kilidi kullanılır. name/status ile exact expected{name,status} alınır; yalnız düzenlenebilir bu iki alan karşılaştırılır, arada değişiklik varsa 409 döner. İlgisiz metadata/ref/bağlar overwrite edilmez. Aynı komutun replay'i ilk sonucu döndürür, yetki replay öncesi kontrol edilir. Kontrol karakterli/boş/160 üzeri yeni ad reddedilir.
- Durum active/paused/archived olarak değiştirilebilir; arşivleme silme değildir ve içerik sürümlerini/bağları değiştirmez. Mevcut ingest aktif kaynak+koleksiyon gerektirdiği için pasif kapsamda yeni metin reddedilir. Kampanya final yayın/runtime kaynak uygunluğu henüz bağlanmadı; bu komut bir çağrı durdurma işlemi değildir.
- Gerçek koleksiyon ve kaynak listelerine ad/durum düzenleme formu eklendi. Kullanıcının açtığı snapshot korunur; background refetch expected değerlerini sessizce değiştirmez. Belirsiz sonuç aynı key/body ile tekrar denenir, alanlar ve form iptali kilitlenir. Tam router/reload pending recovery hâlâ açık.
- API test kodu eşzamanlı replay, eski expected conflict, yabancı tenant, eksik anahtar, doğru audit kimliği, yetki iptali ve arşiv sonrası sealed içeriklerin korunması/ingest reddini kapsar. UI test kodu background veri değişiminde snapshot korunması ve belirsiz isteğin aynı anahtarla tekrarı içindir. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. DB migration/veri yazımı yok.
- Eski sourceVersions/jobs/bindings ekranları ve dead legacy kodları, pending recovery, diğer formatlar, kampanya pinleri/retrieval açık. Faz6 ve goal aktif.


### 2026-10-27 — Kalıcı sürüm ve işleme geçmişi

- GET knowledge-source-versions ve knowledge-ingestion-jobs tenant kapsamlı, agents.manage kontrollü geçmiş sunar. UUID artan cursor sayfalama ve public_id exact filtre vardır; tarih sıralaması iddia edilmez. Join'ler tenant eşitliğini de zorunlu tutar. Yanıtlar no-store; ham error_message, metadata, content/ref ve internal ID dışarı çıkmaz.
- content_verified yalnız ilgili sürümün DB seal durumudur; legacy completed job'ın gerçekten içerik işlediğine ilişkin kanıt olarak kullanılmaz. Legacy sealsiz yayınlar false kalır. Sürüm geçmişinde doğrulanmış format/boyut; job yanıtında gerçek başlangıç/bitiş zamanları bulunur.
- İki ekran artık gerçek geçmişi, durum/verification ayrımını, oluşturulma zamanını, sayfalamayı ve kaynak bağlantısını gösterir. Eski create/edit yolları salt okunur geçmişe açılır; elle published/completed kaydı yazan form kullanıcıya gösterilmez. API'deki eski POST uyumluluğu henüz kaldırılmadı; bunlar verified içerik üretmez. Eski view/edit public ID'si exact filtreyle korunur.
- Test kodu iki geçmiş endpoint'i için unauth/yetki iptali, tenant/foreign ID ayrımı, iki sayfalı tekrarsız okuma, legacy completed+unsealed ayrımı ve hassas alanların dışarı çıkmamasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Şema/data değişikliği yok.
- Sonraki iş: agent binding ekranının kalıcı akışa taşınması ve artık ulaşılamayan legacy sayfa/form kodlarının kaldırılması. Pending recovery, diğer formatlar, kampanya pinleri/retrieval ve sonraki fazlar açık. Faz6/goal aktif.


### 2026-10-27 — Kalıcı agent bilgi bağlantıları ve legacy ekran temizliği

- GET agent-knowledge-bindings tenant/yetki kontrollü, UUID cursor sayfalı ve public_id exact filtreli liste sunar. Agent, koleksiyon ve ortam join'lerinin tümünde tenant eşitliği vardır. Gerçek isim/durum/öncelik ve bağlı kayıtların aktifliği görünür; metadata/internal ID döndürülmez, no-store kullanılır. Bağlantı kampanya sürüm pini veya yayın sertifikası olarak sunulmaz.
- Client binding ekranı kalıcı liste, durum, pasif referans göstergesi ve koleksiyon kaynak bağlantısını kullanır. Eski create/edit yolları salt okunur envantere açılır; boş agent/environment seçenekli işlevsiz form ve kaydetmeden başarı gösteren yerel akış kaldırıldı. Gerçek binding oluşturma/düzenleme için seçim API'si ve idempotent komut hâlâ gereklidir; bu feature tamamlandı sayılmaz.
- KnowledgeBasePage yaklaşık 1400 satırlık eski bileşenden küçük route seçicisine dönüştürüldü. Artık kullanılmayan yerel collection/source/version/job/binding state, elle published/completed formları, sahte tarihler, yerel düzenleme/selection/drawer kodu kaldırıldı. Mevcut kalıcı ekranlar korunur; eski backend POST uyumluluğu ayrıca değerlendirilecektir.
- API test kodu binding sayfalama/exact lookup/tenant ayrımı/yetki reddi/pasif agent gösterimi/hassas alan yokluğu içindir. Client route test kodu eski create ve koleksiyon deep link yollarının gerçek ekranlara gitmesini kapsar. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı; OpenAPI üretildi. Şema/data değişikliği yok.
- Binding yazma akışı, pending recovery, diğer dosya formatları, kampanya kaynak pinleri/retrieval ve sonraki fazlar açık. Faz6 ve goal aktif.


### 2026-10-27 — Binding oluşturma replay ve öncelik/durum düzenleme

- Mevcut binding POST isteğe bağlı Idempotency-Key ile ortak tenant/actor receipt+audit transaction'ına bağlandı; aynı key/body aynı sonucu döndürür, değişen payload 409. Keyless legacy uyumluluk korunur. Audit binding public ID ve doğru agent_knowledge_binding entity türünü kullanır; metadata kopyalanmaz. Öncelik PostgreSQL int sınırı olan 0–2147483647 aralığında doğrulanır.
- PATCH agent-knowledge-bindings/:public_id zorunlu anahtar ve expected{priority,status} ile tenant/satır kilidi altında yalnız öncelik/durum alanlarını değiştirir. Eski snapshot 409; agent/ortam/koleksiyon referansları değişmez. Aktif binding bağlı kayıtların uygun veya kampanyanın yayımlanabilir olduğunun kanıtı değildir.
- Client binding listesine snapshot koruyan öncelik/durum formu eklendi. Belirsiz sonuçta aynı key/body korunur; alanlar ve form iptali kilitlenir. API client create hook'u isteğe bağlı anahtarı header'a taşır. Yeni binding formu henüz açılmadı: mevcut environment listeleme API'si var, agent-builder ve ortam seçim sözleşmeleri sonraki dilimde kullanılacak/değerlendirilecek. Tam router/reload pending recovery açık.
- API test kodu eşzamanlı create/update replay, değişen create payload, stale update, yabancı tenant, int sınırı ve doğru audit kimliğini kapsar. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı; OpenAPI üretildi. DB migration/veri yazımı yok.
- Binding oluşturma UI'si, diğer formatlar, kampanya kaynak pinleri/retrieval, pending recovery ve sonraki fazlar açık. Faz6 ve goal aktif.


### 2026-10-27 — Gerçek seçimlerle binding oluşturma formu

- Yeni binding formu agent/ortam/koleksiyon public ID seçimlerini ve önceliği kullanarak mevcut idempotent POST'a bağlandı. Seçimler ayrı ayrı sayfalıdır; sayfa değişse bile seçilen ad/ID korunur. Aktif seçenekler gösterilir, eksik/boş seçimle gönderilmez. Başarı formu temizler ve Knowledge cache invalidation listeyi yeniler. Belirsiz sonuçta alanlar kilitlenir, aynı tam payload/key tekrar kullanılır.
- Mevcut tenant-environments listesi tenant.read ve geniş metadata projection; agent-builder workspace ise template/workspace içeriği taşıdığı için binding yönetiminde kullanılmadı. GET agent-knowledge-bindings/options?kind=agents|environments yalnız agents.manage ile aktif tenant kayıtlarının public_id/name alanlarını ve cursor döndürür. Koleksiyon seçiminde mevcut knowledge-collections envanteri kullanılır. Bu seçim API'si ek tenant ayarı veya agent instruction erişimi açmaz. Yanıt no-store.
- API test kodu options auth/yetki/tenant ayrımı, geçersiz kind, dar projection ve pasif agent'ın görünmeyip aktif olunca görünmesini kapsar. Client test kodu gerçek seçim ID'leriyle gönderim, unknown outcome kilidi ve aynı key/body replay içindir. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Yeni şema/veri yazımı yok.
- Formun aktif seçenekleri yalnız seçim anındaki uygunluğu gösterir; binding tek başına campaign release/pin sertifikası değildir. Runtime uygunluk/pin kontrolü sonraki entegrasyon işidir. Pending reload/router recovery, diğer dosya türleri ve kampanya pinleri/retrieval açık. Faz6 ve goal aktif.


### 2026-10-27 — Açık kampanya kaynak sürümü bağlantısının temeli

- DB129 caller_campaign_knowledge_pins tablosunu ekler: draft version + source tekilliği, tenant dahil campaign FK ve knowledge-version/source/tenant üçlü FK, pozitif olmayan öncelik reddi. Knowledge version üçlü unique constraint ile yanlış kaynağa/tenant'a sürüm bağlanamaz. Trigger shared tenant kilidi altında sealed+published sürüm gerektirir; relation ownership update edilemez. Yeni içerik üretmez, agent binding'leri otomatik kampanyaya taşımaz.
- Internal replaceCampaignKnowledge/readCampaignKnowledge transaction primitive'leri eklendi. 100 kaynaklık bounded seçim, her kaynak için tek sürüm, aktif kaynak/koleksiyon, doğrulanmış yayın ve tenant sahipliği kontrol edilir. Tüm seçimler doğrulanmadan eski seçim silinmez; boş dizi açık temizleme anlamındadır. Read public manifest/checksum/format/boyut/öncelik ve güncel available durumunu döndürür; kaynak içeriğini döndürmez. Bu fonksiyonlar public endpoint değildir; çağıran komut kampanya edit+agents.manage yetkisi, optimistic version ve audit/receipt'i bağlamalıdır.
- Yerel DB önce private backups/haisly-caller-pre-knowledge-pins-2026-10-27/haisly_caller.dump yedeği alındı;129 tek transaction içinde uygulandı. Gerçek kampanya kaynak seçimi yapılmadı. Rollback herhangi bir seçim varsa veri kaybını önlemek için reddeder. Final izole test DB'lere129 da uygulanmalı; rollback/restore/schema-validator denenmedi.
- Test kodu sealed sürüm seçimi, bilinmeyen sürümde önceki seçimin korunması, tekrar seçim reddi, doğrudan unsealed sürüme geçişin DB tarafından reddi, pasif kaynak availability ve açık temizlemeyi kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı.
- Sonraki dilim public campaign command/read, snapshot immutable manifest/hash, clone/preflight ve client seçimi olmalıdır. Şimdiki snapshotlar bu tabloyu henüz kullanmaz; public yayın kapalı kalır. Diğer formatlar/retrieval/pending recovery ve tüm sonraki fazlar açık. Faz6/goal aktif.


### 2026-10-27 — Kampanya kaynak seçiminin draft/snapshot/hash entegrasyonu

- Mevcut campaign create/replace komutları optional knowledge_versions[{version_public_id,priority}] kabul eder. Gönderildiğinde agents.manage yetkisi replay öncesinde de gerekir; mevcut edit/optimistic-version/receipt/audit transaction'ı içinde seçim değiştirilir. Omission eski istemciler için seçimi korur; explicit [] temizler. Draft yanıtı knowledge_sources manifest/checksum/available döndürür. Campaign read kapsamındaki yetkili kullanıcı manifesti görebilir; kaynak içeriği dönmez.
- Snapshot document seçilen kaynak public ID/sürüm/checksum/öncelik ve yakalama anındaki manifesti dondurur. Yeni snapshot hash scope v4, draft definition v2 ve content binding v2 seçimleri hash'e dahil eder. Fingerprint kaynak adı/güncel available yerine statik source/version/checksum/priority kullanır. Snapshot karşılaştırması iki belgenin anahtar birleşimini kullanır; legacy eksik manifest yeni alana karşı değişiklik olarak görülür, eski snapshotlar backfill/recompile edilmez.
- Preflight pasif/arşivlenmiş seçimi knowledge_source_unavailable olarak engeller. Clone API include_knowledge (default false) seçeneğiyle snapshot'taki version+priority'yi yeni draft'a açıkça kopyalayabilir; güncel uygunluk/yetki yeniden kontrol edilir. Publication/runtime/retrieval sertifikası değildir; mevcut release gate'leri kapalıdır.
- Client read modeli ve snapshot detayında frozen kaynak sürüm/öncelik gösterimi eklendi; eski snapshotta eksik manifest boş seçim gibi sunulmaz. Yeni preflight blocker çevirisi ve hash scope desteği eklendi. Kaynak seçme formu ve clone checkbox UI sonraki dilimdir; eski campaign formu alanı göndermez ve seçim kaybolmaz.
- Public komut test kodu yabancı tenant sürümü, create replay, öncelik değişiminde definition hash, omission preserve, explicit clear ve snapshot manifestinin değişmezliğini kapsar. Test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Yeni DB migration/veri yazımı yok,129 kullanılır. Faz6 ve goal aktif.


### 2026-10-27 — Kampanya editöründe kaynak sürümü seçimi

- Kampanya editörüne agents.manage kontrollü kaynak/sürüm seçimi, öncelik düzenleme ve seçimden kaldırma eklendi. Kaynak ve sürüm listeleri sayfalıdır; yalnız sealed+published sürüm seçilir, pasif kaynak/koleksiyon seçimleri devre dışıdır. Aynı kaynağın başka sürümü açık “bu sürümle değiştir” aksiyonuyla tek seçim olarak değiştirilir; mevcut öncelik korunur. En fazla100 kaynak ve int öncelik doğrulaması vardır.
- İlk render/normal kampanya düzenlemesi knowledge_versions göndermeden mevcut server seçimlerini korur. Yalnız açık seçim/değişiklik form alanını set eder; son kaynağı kaldırmak [] olarak kaydedilir. Form mevcut optimistic-version/idempotency/dirty/navigation korumasına katılır. agents.manage olmayan kullanıcı mevcut manifesti okuyabilir ama değiştiremez. Sayfa kaynak güncellendi diye yeni sürümü otomatik seçmez.
- Snapshot kopyalama paneline yetkiye bağlı, varsayılan kapalı include_knowledge checkbox eklendi. API kayıtlı snapshot'tan seçimi kopyalar; mevcut taslaktaki son değişiklikleri yanlışlıkla taşımaz.
- Client test kodu ilk renderda seçim mutasyonu olmaması, sadece verified/published seçenek, aynı kaynak sürümünün değiştirilmesi, öncelik korunması/düzenlenmesi ve explicit clear içindir. API test koduna kaynaklı/kaynaksız clone ve frozen önceliğin kopyalanması eklendi. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı. Şema veya yerel veri değişikliği yok.
- Kaynak içeriğinin runtime retrieval ve release certificate bağları, PDF/DOCX/CSV/XLSX/HTTPS ingest, pending recovery ve sonraki fazlar açık. Bu UI yayın/arama yetkisi vermez; Faz6 ve goal aktif.


### 2026-10-27 — Snapshot'a bağlı sınırlı içerik okuma

- API internal KnowledgeContentService.readFragment tenant + server-resolved snapshot kapsamında yalnız snapshot manifestindeki kaynak/sürüm içeriğini okur. Güncel draft/agent binding veya son kaynak sürümüne geçmez; draft seçimleri temizlense bile frozen pin kullanılır. Snapshot manifesti olmayan legacy kayıt, seçilmemiş sürüm, checksum uyuşmazlığı, unsealed/arşivlenmiş sürüm ve pasif kaynak/koleksiyon reddedilir.
- Snapshot, sürüm uygunluğu ve chunk okuması repeatable-read transaction kullanır. Her fragment PostgreSQL'de en fazla4000 Unicode karaktere kesilir (en fazla16000 UTF-8 byte); API sürecine bütün büyük chunk taşınmaz. Offset Unicode karakter cinsindedir; next_offset yalnız aynı chunk'ın devamıdır. Dönen checksum tüm chunk'a aittir, fragment checksum'u değildir. Öncelik snapshot'tan gelir; metadata/ref/internal ID dönmez.
- Bu yalnız internal primitive'dir: çağıran use-case actor/runtime-session yetkisini, tenant ve snapshot bağını sunucuda çözmelidir. Public/runtime endpoint açılmadı. Snapshot tek başına yayın/arama sertifikası değildir. Arama/ranking, chunk discovery, runtime release/session entegrasyonu ve cevap kaynak kanıtı hâlâ açıktır; bu parça tamamlanmış RAG olarak sunulmaz.
- Test kodu frozen öncelik ve draft clear sonrası içerik, tenant ayrımı, seçilmemiş sürüm, sınır dışı offset/negatif chunk ve kaynak duraklatılınca okumanın reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Şema/veri değişikliği ve dış servis çağrısı yok. Faz6/goal aktif; provider staging/SIP/test hattı kullanıcı bildirimine göre hazır değil, bağımsız geliştirmeye devam edilir.


### 2026-10-27 — Sabit kaynaklarda lexical parça keşfi

- Internal KnowledgeContentService.search snapshot manifestindeki sürümler üzerinde PostgreSQL simple/plainto_tsquery ile tüm sorgu terimlerini eşleştiren lexical aday keşfi sunar. Sorgu400 karakter, sonuç varsayılan8/maksimum16, statement timeout2s. Parametreli sorgu kullanılır; timeout boş sonuç olarak yutulmaz. Kaynak önceliği sayısal artan, ardından lexical rank ve kararlı chunk sırası uygulanır. Snapshot dışındaki kaynak/sürüm seçilmez.
- Sonuç kaynak/sürüm/checksum/chunk/öncelik referansları ve has_more döndürür; içerik mevcut bounded fragment reader ile alınır. Sorgu/açık içerik audit/log'a yazılmaz. Bu semantik arama, cevap doğruluğu veya çelişki çözümü değildir; eşit öncelik ayrı korunur ve has_more tam kanıt kümesi iddiasını engeller. Üretim retrieval/index/performans değerlendirmesi, runtime session/release yetkisi ve cevapta kaynak kanıtı entegrasyonu açıktır. Public/runtime endpoint açılmadı.
- Snapshot çözümlemesi read/search arasında ortaklaştırıldı. Tüm pinler tenant+source+version+checksum ve güncel aktif/sealed/published durumuyla doğrulanmadan herhangi bir içerik/aday dönmez. Tekrarlı kaynak/sürüm veya100'den fazla pin reddedilir. Bu bilinçli fail-closed davranış, başka bir seçili kaynak uygunsuzsa tek parça okumasını da reddeder.
- Test kodu frozen manifestte eşleşme, bulunamama, SQL benzeri girdinin kaynak kapsamını genişletememesi, foreign tenant reddi, boş sorgu/limit doğrulaması ve pasif kaynak reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Şema/yerel veri/dış bağlantı değişmedi. Faz6/goal aktif.


### 2026-10-27 — Yetkili kampanya bilgi önizlemesi

- POST campaigns/:public_id/snapshots/:snapshot_public_id/knowledge-search ve knowledge-fragment salt okunur hazırlık önizlemesi açıldı. Servis caller.campaigns.read + agents.manage yetkilerini ve tenant dahil snapshot→kampanya ilişkisini kontrol eder. Body'den snapshot/tenant override kabul edilmez. POST sorgu metnini URL'den uzak tutar; no-store,4096/1024 byte body limit ve ortak sensitive rate limit uygulanır. Mutasyon/idempotency receipt veya yayın/test sertifikası oluşturmaz. OpenAPI üretildi.
- Client sürüm detayında yetkili ve kaynaklı snapshot için önizleme paneli var: kelime arama, kaynak/sürüm/öncelik/parça gösterimi, has_more uyarısı, güvenli düz metin içerik ve aynı chunk'ın devamı. Snapshot değişiminde panel yeniden oluşturulur; arama metni değişince eski sonuç/içerik temizlenir. Enter ana kampanya formunu submit etmez. Sorgu sırasında kontrollere kilit, hata/boş/loading durumları eklendi. Kaynak adayları doğrulanmış cevap veya eşit öncelikte çelişki çözümü olarak gösterilmez.
- API test kodu search/fragment başarı, no-store, unauth, foreign tenant, yanlış kampanya, body snapshot override ve yetki iptalini kapsar. Client test kodu açık snapshot kimliğiyle çağrı, Enter ile form submit engeli, kaynak metninin HTML olarak çalışmaması ve fragment devam offset'i içindir. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı; OpenAPI generation doğrulama sonucu değildir.
- Runtime session/release bağı, semantik retrieval/çelişki ve cevap kanıtı, üretim arama indeksi/performans doğrulaması, diğer ingest formatları ve sonraki fazlar açık. Şema/veri/dış sağlayıcı çağrısı değişmedi. Faz6/goal aktif.


### 2026-10-27 — CSV ürün kataloğu ingest API'si

- POST knowledge-sources/:public_id/ingest-csv agents.manage + zorunlu Idempotency-Key + expected_version_no ile aktif document kaynağına CSV işler. UTF-8 CSV JSON string olarak taşınır; dosya seçme UI sonraki dilimdir. Kaynak10 MiB, HTTP body14 MiB; virgül/noktalı virgül/tab ayırıcı, zorunlu benzersiz dolu başlıklar,64 sütun,10000 veri satırı,200000 hücre,4000 karakter/hücre ve256 KiB record sınırları uygulanır. Bozuk quoting/farklı sütun sayısı reddedilir.
- Mevcut csv-parse bağımlılığı streaming kullanılır;16 KiB bloklar arasında event-loop'a bırakılır. Parse agents.manage kontrolünden sonra, DB write transaction dışında yapılır. Normalize içerik satır/sütun adlarını literal JSON-lines ile tutar; formül değerlendirme/sayıya çevirme/URL fetch yapılmaz. Normalize çıktı da10 MiB sınırındadır. Parser hatası kaynak hücresini dışarı sızdırmadan400'e dönüşür.
- Text ingest storage ortak format kontrollü primitive'e taşındı; mevcut text wrapper korunur. CSV document kaynağı, text text kaynağı gerektirir. Sürüm/chunk/DB seal/completed job/idempotency receipt/audit aynı transaction'dadır; formatcsv ve pipelinecaller-catalog-csv-v1 kaydedilir. Yeni kaynak otomatik kampanyaya bağlanmaz. Replay checksum/row/column sayılarını döndürür; kaynak içeriği audit/receipt'e girmez. Rate limit ve OpenAPI eklendi/üretildi.
- Test kodu literal/formül/quoted newline korunması, başlık/kolon/hücre/bozuk dosya reddi, hatada içerik sızıntısının önlenmesi, public ingest seal, replay/stale/changed payload, foreign tenant/unauth/yetki iptalini kapsar. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı. Şema/yerel veri/dış bağlantı değişmedi.
- CSV dosya seçme ve document kaynak oluşturma UI'si, XLSX/PDF/DOCX/HTTPS, runtime release ve diğer fazlar açık. Uzun normalize satırlar genel chunk algoritmasıyla bölünebilir; retrieval bağlamının tamamlanması sonraki entegrasyonda ele alınmalıdır. Faz6/goal aktif.


### 2026-10-27 — CSV katalog kaynağı oluşturma ve yükleme UI'si

- Bilgi kaynağı oluşturma formuna Metin / CSV ürün kataloğu seçimi eklendi. CSV seçimi mevcut create API'sine document source_type gönderir; isim/koleksiyon ve aynı-key replay davranışı korunur. Katalog kaynağı sürüm ekranında .csv dosyası ve virgül/noktalı virgül/tab ayırıcı seçilir. Dosya yerelde nonempty/10 MiB/strict UTF-8 kontrolünden geçer; sunucu içerik yapısını ayrıca doğrular.
- POST ingest-csv hook'u key'i header'a taşır ve yalnız başarıda Knowledge cache'i invalidate eder. Ekran API'den doğrulanmış version_no/row_count/column_count sonucunu gösterir. Kaynak fiyat/stok bilgisinin statik kopya olduğu açıklanır; canlı veri iddiası yok. Metin kaynağının mevcut ingest akışı korunur.
- Dosya okuma/gönderme sırasında alanlar ve kaynak içi gezinme kilitlenir. Belirsiz ağ/5xx sonucunda tam CSV+delimiter+expected_version_no+key bellekte korunur, aynı istek tekrar edilir; alanlar değiştirilmez. Kesin4xx hata dosyayı korur, sürümleri yeniler; başarı dosya seçimini temizler. Tam reload/router pending recovery önceki ortak açık iş olarak sürer.
- Client test kodu document kaynak oluşturma, unknown outcome'da aynı payload/key retry, verified receipt gösterimi ve bozuk UTF-8 dosyada API çağrısı yapılmamasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. API/DB şema veya yerel veri değişikliği yok.
- XLSX/PDF/DOCX/HTTPS, retrieval/runtime release bağları, pending recovery ve diğer fazlar açık. Faz6/goal aktif.


### 2026-10-27 — İzole XLSX katalog ingest API'si

- POST knowledge-sources/:public_id/ingest-xlsx canonical base64 (decoded10 MiB/body14 MiB), agents.manage, Idempotency-Key ve expected_version_no ile document kaynağına XLSX sürümü işler. CSV ile ortak kayıt/audit/receipt/seal transaction'ı kullanılır; formatxlsx ve caller-catalog-xlsx-v1 pipeline kaydedilir. Parser işlemi yetki kontrolünden sonra ve DB transaction dışında gerçekleşir. OpenAPI/rate limit eklendi.
- Mevcut ayrı süreçli parser'a internal catalog profili eklendi; yeni worker veya ayrı concurrency havuzu oluşturulmadı. Ortak en fazla2 process,256 MiB heap,15s timeout,100 MiB ZIP açılımı/2048 entry/aktif içerik ve external-reference korumaları korunur. Contact HTTP mapper profile alanı taşımadığı için kişi import kuralları değişmez. Catalog XLSX-only,10000 satır,64 sütun,200000 hücre,4000 karakter/hücre sınırındadır.
- Tek worksheet ve literal scalar hücreler kabul edilir. Gerçek formüller/cached sonuçlar, hyperlink ve unsupported hücreler tüm katalog için reddedilir. Negatif sayılar ve text hücrelerindeki ifade benzeri içerik literal kalır. Excel display formatting/currency/date yorumu yapılmaz; baştaki sıfırlar için hücre text olmalıdır. CSV ortak header/row/JSON-lines normalizasyonu yeniden kullanılır; normalize katalog10 MiB sınırındadır. Parser busy/timeout/unavailable503 ile aynı key retry ister, içerik hataları400'dür.
- Test kodu catalog negatif değer/leading-zero korunması, contact expression politikasının korunması, gerçek formula cached değerinin kullanılmaması, multi-sheet/base64 reddi, gerçek isolated parser üzerinden API seal/replay ve formula/yetki iptali içindir. Kullanıcı talimatıyla hiçbir test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Yeni bağımlılık/şema/yerel veri/dış bağlantı yok.
- XLSX dosya seçme UI'si sonraki dilim. PDF/DOCX/HTTPS, runtime release/retrieval ve diğer fazlar açık. Faz6/goal aktif.


### 2026-10-27 — XLSX katalog yükleme arayüzü

- Kaynak türü seçimi CSV / XLSX ürün kataloğu olarak genişletildi; her ikisi mevcut document kaynağına gider. Ortak yükleme ekranı .csv ve.xlsx kabul eder. XLSX dosyası mevcut bounded readImportFile/FileReader yardımcısıyla base64'e çevrilip ingest-xlsx'e gönderilir; CSV strict UTF-8/ayırıcı yolu korunur. Legacy.xls kabul edilmez.
- XLSX seçiliyken ayırıcı gizlenir; tek worksheet, formül/link/makro reddi ve display formatting yerine stored value okunması anlatılır. Baştaki sıfırların korunması için hücreyi text kaydetme yönlendirmesi vardır. Başarı yalnız verified server receipt'e dayanır.
- Pending kayıt format+tam request içerir; unknown outcome retry aynı endpoint, base64/body ve key'i kullanır. Dosya/değişiklik kilidi ve source page busy durumu korunur. Başarı Knowledge cache'ini invalidate eder; parser503 sonucu başarı gibi gösterilmez. Tam reload/router recovery ayrı açık iştir.
- Client test kodu XLSX transport/base64, CSV endpoint'inin çağrılmaması, ayırıcı gizleme, kullanım açıklaması ve unknown outcome'da aynı workbook request retry için genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Şema/yerel veri/dış servis çağrısı yok.
- PDF/DOCX/HTTPS, retrieval/runtime release bağları ve diğer fazlar açık. Faz6/goal aktif.


### 2026-10-27 — DOCX ayrıştırma temeli ve Zod güvenlik güncellemesi

- API mammoth1.13.0 exact bağımlılığı eklendi (install --ignore-scripts). Resmî [Mammoth dokümanı](https://github.com/mwilliamson/mammoth.js/blob/master/README.md) incelendi: yalnız extractRawText({buffer}) kullanılır, HTML dönüşümü/filesystem path/externalFileAccess açılmaz. Internal docx-core ZIP incelemesinden sonra ham paragraf metnini ortak10 MiB normalizasyonuna bağlar; metinsiz belge ve converter uyarıları reddedilir. Henüz production call-site/worker/API/UI yok; yalnız isolated child içinde çağrılacak temel olarak eklendi.
- XLSX ZIP guard mevcut wrapper korunarak DOCX profilini destekler. DOCX content-types + word/document.xml gerektirir; ortak zip entry/expansion/active content/external reference korumaları vardır. DOCX XML parçaları strict UTF-8, NUL'suz ve parça başına10 MiB olmalıdır; DTD/entity yasaktır. Relationship numeric entity kodlaması regex guard'ını aşmaması için reddedilir. Dosyalar diske açılmaz. Mevcut XLSX davranışı bu profil varsayılanı dışında değişmez.
- Yeni bağımlılık kontrolünde npm audit mevcut Zod için GHSA-mrhx-c7xc-m3w5 yüksek önem dereceli bellek tüketimi açığını bildirdi (<4.6.6). API ve client exact Zod4.6.7'ye güncellendi; lockfile'lar kaydedildi. Kullanıcının önceki açık npm audit izniyle iki repoda npm audit --omit=dev --ignore-scripts --json tekrarlandı: ikisi de0 vulnerability bildirdi. Bu sonuç yalnız audit veritabanının üretim bağımlılığı kapsamıdır; uygulama güvenliği/uyumluluk kanıtı değildir.
- Test fixture'ları plain/external relationship/DOCTYPE/metinsiz DOCX ve bunlara ait metin çıkarım/ret test kodu eklendi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Zod uyumluluk doğrulaması final pakette yapılmalı. Şema/yerel veri/dış çağrı değişmedi.
- DOCX isolated worker→ingest API→UI bağlantısı sonraki iş; PDF/HTTPS ve kalan fazlar açık. Faz6/goal aktif.


### 2026-10-27 — İzole DOCX ingest API bağlantısı

- DOCX extractDocxText artık mevcut parser-process worker'ından çağrılır. Parent parseDocxFile dosya imzası/10 MiB kontrolünden sonra aynı admission sayacını kullanır: DOCX/XLSX/contact parsing toplam en fazla2 process,256 MiB child heap,15s timeout; DB/env sırları aktarılmaz. Build'deki mevcut parser-process çıktısı kullanılır; ayrı limitsiz worker havuzu eklenmez.
- POST knowledge-sources/:public_id/ingest-docx agents.manage, canonical base64, zorunlu key ve expected_version_no ile aktif document kaynağına yazar. Parse transaction dışında; ardından ortak knowledge version store formatdocx/caller-document-docx-v1 ile sürüm/chunk/seal/completed job/receipt/audit'i atomik kaydeder. Yanıt text seal receipt biçimindedir, katalog row/column iddiası yoktur. No-store, body14 MiB, sensitive rate limit ve OpenAPI eklendi.
- Parser busy/timeout/crash503 aynı key retry ister; geçersiz/boş/unsupported/aktif içerikli belge400 olarak döner. Ham metin veya belge parser hatası client/audit'e aktarılmaz. Kaynak tenant/yetki ve optimistic version işlemleri mevcut mutate/write transaction'ında yeniden kontrol edilir. Yeni kaynak otomatik kampanyaya bağlanmaz.
- Test kodu gerçek child parser kullanan API success/seal/stored text/replay, unauth/foreign tenant/yetki iptali, external relationship/DOCTYPE/metinsiz belge reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Şema/yerel veri/gerçek sağlayıcı çağrısı yok.
- DOCX yükleme UI'si sonraki dilim. PDF/HTTPS, runtime/release ve diğer fazlar açık; Faz6/goal aktif.


### 2026-10-27 — DOCX dosya yükleme arayüzü

- Bilgi kaynağı oluşturma türü Dosya(CSV/XLSX/DOCX) olarak genişletildi. Ortak dosya ekranı.docx kabul eder, ayırıcıyı gizler ve ingest-docx'e gönderir. DOCX koşulları/metinsiz belge ve dış bağlantı retleri açıklanır. Başarıda katalog satır/sütun sayıları yerine API'nin verified version/normalized_bytes sonucu gösterilir.
- Pending format+request ayrımı DOCX için de korunur; unknown outcome aynı DOCX endpoint/base64/key/expected_version_no ile tekrar edilir. Yeni hook yalnız başarıda Knowledge invalidation yapar. Eski.doc veya PDF desteği varmış gibi gösterilmez.
- FileReader/10 MiB kontrolü ortak readBase64File yardımcısına çıkarıldı. Kişi importu kendi CSV/XLS/XLSX allowlist'ini korur; DOCX kişi importuna açılmaz. Dosya tipi kontrolü knowledge UI'da açık CSV/XLSX/DOCX allowlist ile yapılır, içerik imzası/parse doğrulaması sunucuya aittir.
- Client test kodu DOCX endpoint seçimi, diğer parser endpoint'lerinin çağrılmaması, aynı key/body retry ve row_count olmayan receipt'in metin boyutuyla sunulmasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Şema/yerel veri/dış servis çağrısı değişmedi.
- PDF/HTTPS, pending router/reload recovery, retrieval/runtime release ve sonraki fazlar açık. Faz6/goal aktif.


### 2026-10-27 — İzole PDF metin katmanı ayrıştırması

- pdfjs-dist6.4.299 exact bağımlılığı --ignore-scripts ile eklendi. [Resmî PDF.js Node örneği](https://github.com/mozilla/pdf.js/blob/master/examples/node/getinfo.mjs) ve kurulu sürüm API tipleri incelendi. PDF data Uint8Array ile yüklenir; HTML/canvas rendering/OCR yok. Metin sayfa sırasıyla çıkarılır, ortak normalizasyonla10 MiB sınırına bağlanır. En fazla200 sayfa/200000 text item; her sayfada metin gereklidir (boş sayfalar da reddedilir). Bu v1 işleme sınırı UI/API açıklamasına taşınmalıdır.
- Yalnız paket içindeki CMap/standard font dosyalarına sabit dizin + basename allowlist ile erişen BinaryDataFactory vardır; belge URL/path'i readFile/fetch'e aktarılmaz. Worker fetch/WASM/XFA/system fonts/image decode kapalıdır. JavaScript actions, attachments, form fields, textless pages ve parser hataları reddedilir; hatalarda belge ayrıntıları paylaşılmaz. Harici link annotation'ları çalıştırılmaz veya takip edilmez; link varlığı tek başına metin içeriğini değiştirmez.
- parsePdfFile mevcut ortak parser süreci/pool'una bağlandı (2 process/256 MiB/15s). PDF modülü yalnız PDF isteğinde dynamic import edilir; diğer dosya türlerinde gereksiz yüklenmez. Production API henüz çağırmaz; ingest-pdf endpoint/UI sonraki dilimdir. Yeni şema/yerel veri/gerçek müşteri veya sağlayıcı çağrısı yok.
- Minimal gerçek PDF fixture'ları text/empty/JavaScript ve doğrudan+isolated parser test kodu eklendi. Kullanıcının talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Önceki açık npm audit izniyle API production dependency audit çalıştı:0 vulnerability. Bu yalnız advisory veritabanı kapsamı, parser uyumluluk/güvenlik kabulü değildir.
- PDF ingest/UI, HTTPS, pending recovery, runtime release/retrieval ve kalan fazlar açık. Faz6/goal aktif.


### 2026-10-27 — PDF ingest API ve yükleme arayüzü

- POST knowledge-sources/:public_id/ingest-pdf canonical base64, agents.manage, active document source/collection, Idempotency-Key ve expected_version_no ile ayrı süreçte PDF text extraction'a bağlandı. DOCX/PDF ortak document command kullanır; formatpdf/caller-document-pdf-v1 ile mevcut atomic version/chunks/seal/job/audit/receipt akışı tamamlanır. No-store/body14 MiB/rate limit ve OpenAPI eklendi. İstemci public ingest formatını başka formata çeviremez.
- API açıklaması/hata ve UI,200 sayfa/10 MiB sınırını ve her sayfada metin gerekliliğini açıklar; boş sayfalar da bu uygulamada reddedilir. OCR yok; form/attachment/JavaScript/invalid/password-required belgeler reddedilir. Parse availability503 ve içerik400 ayrımı korunur. Yeni sürüm otomatik kampanyaya bağlanmaz.
- Dosya oluşturma/yükleme ekranı PDF'i kabul eder, ayırıcıyı gizler, PDF endpoint'ini çağırır ve verified text byte sonucunu gösterir. Pending PDF format/body/key/expected_version_no aynı endpoint'e tekrar gönderilir; alan kilidi ve yalnız başarıda Knowledge invalidation korunur.
- API test kodu isolated parser üzerinden success/seal/text/replay/stale, unauth/foreign tenant/yetki iptali, textless ve JavaScript PDF reddini kapsar. Client test kodu PDF endpoint seçimi, diğer format endpoint'lerinin çağrılmaması ve aynı request retry için genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi. Şema/yerel veri/sağlayıcı çağrısı değişmedi.
- HTTPS kaynak alma, pending recovery, retrieval/runtime release ve kalan fazlar açık. Faz6/goal aktif.


### 2026-10-27 — HTTPS kaynakları için kesin origin politikası

- Internal authorizeKnowledgeUrl yalnız HTTPS/443, DNS hostname ve server tarafından yüklenen en fazla100 kesin origin ile çalışır. Wildcard/subdomain örtük yetkisi yoktur; URL credentials, fragment, whitespace/control/backslash, encoded authority, IP literal/alternatif IP yazımı, tek label ve özel yerel suffixler reddedilir. URL query/path korunur; hata mesajları URL veya credential içermez. Hatalı allowlistin herhangi bir girdisi tüm kararı reddeder.
- Bu yalnız URL/origin ön kontrolüdür, SSRF korumasının tamamı değildir. DNS cevaplarının özel adres kontrolü ve TLS bağlantısına pinlenmesi, redirect başına yeniden yetki kontrolü, timeout/body sınırları, HTML text extraction, tenant allowlist persistence ve ingest/UI bağlantısı henüz yoktur. Production call-site/network fetch açılmadı; bu çıktıyı doğrudan fetch'e vermemek kod sözleşmesinde açıkça belirtilir.
- Test kodu exact origin, subdomain/lookalike/redirect hedefi ayrımı, credentials/alternatif IP/yerel hostname reddi, bozuk allowlist ve sanitized hata davranışlarını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Yeni bağımlılık, şema, yerel veri veya dış ağ isteği yok; önceki PDF commitleri üç repoda origin/main ile eşit doğrulandı. Faz6 ve goal aktif.


### 2026-10-27 — DNS kontrolü ve IP'ye sabit HTTPS taşıması

- Internal KnowledgeHttpsService.fetchPage, önce exact-origin politikasını uygular; A/AAAA cevaplarının tamamını kontrol ederek özel/yerel/link-local/metadata/multicast/documentation/transition ve özel amaçlı adresleri reddeder. IPv6 yalnız2000::/3 içindeki özel olmayan adreslerle sınırlıdır. Bazı globally reachable special-purpose anycast adresleri de bilinçli konservatif ret kapsamındadır. [IANA IPv4](https://www.iana.org/assignments/iana-ipv4-special-registry/) ve [IPv6](https://www.iana.org/assignments/iana-ipv6-special-registry/) kayıtları incelendi; bu tablo operasyonel olarak güncel tutulmalıdır.
- Bağlantı hostname'i seçilmiş public IP'dir; Host/SNI/sertifika kimlik kontrolü özgün DNS hostname'ine bağlıdır. Böylece bağlantı sırasında ikinci DNS çözümlemesi yoktur. TLS doğrulama açık, minimumTLS1.2, agentfalse, credential/cookie/proxy taşıması yok. Resolver3s/1try, tüm DNS+redirect+body süreci15s, process başına en fazla2 iş; IPv4 ve IPv6 cevaplarından herhangi biri uygunsuzsa tüm fetch reddedilir. Resolver abort/cancel ile kapatılır. [Node DNS](https://nodejs.org/docs/latest-v24.x/api/dns.html) dokümanı ve kurulu Node tipleri referans alındı.
- En fazla3 redirect, her hedefte yeniden origin+DNS doğrulaması; yalnız200 text/html veya text/plain,16KiB header/10MiB body, identity encoding kabul edilir. Redirect body indirilmez; compressed response reddedilir. Hata kodları URL/query/response içeriği sızdırmaz. Retry/fallback gizlice yapılmaz. Bu içerik ham Buffer'dır; HTML execution/rendering yapılmaz.
- Unit test kodu address policy, mixed DNS answer reddi ve IP/Host/SNI/TLS options bağını kapsar. Gerçek TLS fixture/redirect/timeout/body limit davranış testleri henüz eklenmedi; gerçek network kabulü yok. Kullanıcı talimatıyla hiçbir test/typecheck/lint/build çalıştırılmadı; yeni bağımlılık veya şema değişikliği yok.
- Production route açılmadı. Tenant allowlist kalıcılığı/yetki, HTML metin ayrıştırma, ingest receipt/sürüm bağlama ve UI sonraki işler. Dağıtım/gerçek sağlayıcı veya kaynak sayfasına çağrı yapılmadı; araçlarla yalnız resmî geliştirme referansları okundu. Mevcut public ingest akışları değişmez. Faz6/goal aktif.


### 2026-10-27 — İzole HTML ve düz metin kaynak ayrıştırması

- htmlparser2 12.0.0 exact bağımlılığı --ignore-scripts ile eklendi. [Resmî callback API](https://github.com/fb55/htmlparser2) kullanılır; DOM renderer/browser/JS/CSS çalıştırma veya nested resource fetch yoktur. Header charset ve meta charset yalnız UTF-8 kabul eder; byte decode strict UTF-8'dir. HTML entities çözülür, paragraf/tablo ayrımları metne taşınır. text/plain içeriği HTML olarak yorumlanmaz.
- head/script/style/template/noscript/iframe/object/embed/svg/math/canvas/form ve hidden/aria-hidden=true alt ağaçları çıkarılır. CSS ile gizlenmiş içerik hesaplanmaz; bu tarayıcıdaki görünür sayfanın birebir kopyası değildir. JS ile yüklenen içerik çekilmez; geriye metin kalmazsa açık ret oluşur. HTML ayrıştırıcı toleranslıdır; içerik kaynak gerçekliği veya prompt-injection güvenilirliği sertifikası değildir.
- Kaynak10MiB, çıktı10MiB,200000 callback ve256 nesting limiti vardır. Ortak parser-process üzerinden toplam2 process/256MiB heap/15s sınırları korunur; HTML modülü yalnız web-page profilinde yüklenir. KnowledgeHttpsService.readPageText bounded HTTPS fetch sonucunu bu worker'a bağlar. Henüz public endpoint yoktur; server-owned tenant allowlist/yetki/ingest receipt/UI sonraki iştir.
- Test kodu literal text/entities/paragraph, hidden/active subtree çıkarma, plain-text korunması, unsupported charset/invalid UTF8/metinsiz sayfa/deep nesting ve gerçek worker çağrısını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Önceki açık izinle npm audit --omit=dev --ignore-scripts --json çalıştı:0 vulnerability; bu yalnız registry advisory kapsamıdır.
- DB/schema/yerel veri değişmedi. Kaynak indirme veya gerçek sağlayıcı çağrısı yapılmadı. Faz6 ve goal aktif; kalıcı izin listesi/API/UI ve kalan fazlar açık.


### 2026-10-27 — Tenant HTTPS izin listesi kalıcılık temeli

- Migration130 caller_knowledge_https_policies tablosunu ekler: tenant PK/FK, public UUID, version, en fazla100 unique canonical origin, timestamps. Kayıt yoksa sürüm0/boş izin listesi döner. Boş liste deny-all'dır. Trigger identity değişimini engeller, tenant mutation lock kullanır ve sürümü artırır. Migration yeni izin vermeyen additive şemadır. Rollback herhangi bir policy kaydı varsa veri kaybını önlemek için durur.
- API internal KnowledgeHttpsPolicyService.read/update agents.manage ister; update zorunlu expected_version ve mevcut idempotency receipt/audit transaction'ını kullanır. Originler exact HTTPS politika kontrolünden sonra normalize/dedupe/sort edilir. Path/query/credential/wildcard/IP reddedilir; invalid origin Zod400'a çevrilir. Audit yalnız sürüm ve origin sayısını taşır, entity_type knowledge_https_policy olarak ayrılır. Yetki istemciye bırakılmaz; tenant auth üzerinden çözülür.
- Bu servis henüz public route'a bağlanmadı. Fetch use-case'in bu server-owned listeyi okuması ve write aşamasında policy revizyonunu yeniden kontrol etmesi sonraki ingest adımıdır; şu an kullanıcı kaynak indirmesi açılmaz. Policy değişimi mevcut sealed içerikleri silmez; ileri fetch/ingest yetkisi olarak kullanılması planlanır.
- Unit test kodu empty deny-all, canonical/deduped origins ve path/wildcard reddi için genişletildi. SQL test dosyası policy shape/duplicate/null/multidimensional/limit koşullarını kapsar. Transaction/tenant/replay/trigger ve public endpoint testleri sonraki bağlantıda eklenmelidir. Kullanıcı talimatıyla test/typecheck/lint/build/schema-validator/rollback çalıştırılmadı.
- Migration130 henüz local DB'ye uygulanmadı; mevcut DB129 olarak kalır. API türleri yeni tablo için hazır; servis production call-site olmadığından mevcut yollar bu tabloyu sorgulamaz. Endpoint bağlantısından önce yedek + yalnız local haisly_caller migration uygulanmalıdır. Faz6/goal ve sonraki fazlar aktif.


### 2026-10-27 — HTTPS policy API ve yerel migration

- GET/PUT /api/v1/knowledge-https-policy agents.manage ile yalnız authenticated tenant politikasını okur/günceller. PUT strict body, expected_version ve Idempotency-Key gerektirir;32KiB body ve sensitive rate limit vardır. Yanıtlar no-store. Source/campaign/network işlemi tetiklemez. OpenAPI sözleşmesi eklendi ve JSON üretildi.
- API test kodu initial deny-all, canonical/deduped origin, same-key replay, changed payload/stale version409, foreign tenant default policy, invalid origin/ownership injection400, clear→version2, summary-only audit ve yetki kaldırılınca read/replay403 senaryolarını kapsar. Mevcut knowledge integration support zincirine bağlandı; kullanıcı talimatıyla çalıştırılmadı. Typecheck/lint/build/browser da çalıştırılmadı.
- Yerel DB hedefi127.0.0.1/haisly_caller olarak kontrol edildi; backups/haisly-caller-pre-https-policy-2026-10-27/haisly_caller.dump private yedeği alındı. Migration130 ve schema_migrations kaydı tek transaction'da başarıyla uygulandı. Production/test DB'lere dokunulmadı; rollback/restore/schema-validator çalıştırılmadı. Migration başarısı davranış testlerinin yerine geçmez.
- Tenant policy UI ve bu policy üzerinden URL-source ingest halen açık. Faz6/goal aktif; diğer fazların kapsamı korunur.


### 2026-10-27 — Tenant HTTPS izin listesi arayüzü

- Bilgi koleksiyonları sayfasının mevcut agents.manage/tenant-key sınırı içinde HTTPS izin listesi paneli eklendi. RTK Query GET/PUT hookları server state'i kullanır; başarılı mutation Knowledge cache'ini invalid eder. Başlangıç/loading/error/retry/empty/success durumları vardır; alan adları link veya HTML olarak değil düz metin gösterilir.
- Editör React Hook Form + merkezi Zod metin şeması kullanır. Satır başına origin, max100/261 karakter, temel HTTPS/no-path/query/credentials kontrolü vardır; kesin hostname/IP/allowlist otoritesi sunucudadır. Boş liste yeni alımları kapatır ve mevcut sealed içeriği silmez açıklaması gösterilir. Sürüm edit başında sabitlenir; güncel cache değişimi taslağı ezmez.
- Pending ref tam body/key/expected_version taşır. Unknown network/5xx outcome alanları/iptali kilitler; aynı istek retry yapılır. Kesin4xx pending'i bırakır ve409 için iptal edip güncel kaydı açmayı ister. Double submit ref guard bulunur. İptal/başarı policy'yi refetch eder. Full-router/reload pending recovery halen ortak açık iş; kullanıcıya ekranı açık tutması söylenir.
- Client test kodu unknown outcome same-key replay/alan kilidi, explicit empty list ve path validation'da API çağrılmamasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Yeni bağımlılık/DB değişikliği yok. API/DB repolarına ilerleme notları yazıldı; URL-source ingest bağlantısı sonraki iş. Faz6/goal aktif.


### 2026-10-27 — HTTPS kaynak ingest API bağlantısı

- POST knowledge-sources/:public_id/ingest-https agents.manage, Idempotency-Key, expected_version_no ve expected_policy_version ile kayıtlı aktif URL source_ref'i işler. Body URL/tenant/allowlist override kabul etmez;1024byte limit/no-store/rate limit/OpenAPI vardır. Kaynak/collection/tenant ve önceki sürüm indirmeden önce kontrol edilir; tenant policy server'dan yüklenir. DB transaction açıkken network/parse yapılmaz.
- Başarılı receipt replay ön kontrolü actor+tenant+scope+key+payload hash+expiry ile yapılır; sayfa yeniden indirilmez. Yeni iş bounded HTTPS→isolated text parser akışını kullanır. Shared tenant lock altında policy version ve source_ref yeniden kontrol edilir; aktif source/type/collection/expected version ortak store'da tekrar denetlenir. formathttps/caller-https-text-v1 ile chunks/seal/job/receipt/audit atomik yazılır. Audit URL/query/içerik taşımaz.
- Source/policy değişimi409; ağ/DNS/parser availability503 same-key retry; desteklenmeyen URL/HTML/charset/limit400 sanitized hata verir. Başarısız iş mevcut sealed içeriği değiştirmez. Concurrent aynı-key ilk denemeler dış GET'i birden fazla yapabilir; commit receipt tekilleştirilir. Bu okuma-only HTTP işlemi için kabul edilen davranıştır; dış yazma işlemi değildir.
- Test kodu mocked readPageText üzerinden public auth/foreign tenant/body override, sealformat, replay'de no-refetch, stale version, fetch sırasında policy revocation→409/no second version ve yetki iptalinde replay403 senaryolarını kapsar. Bu mock command/transaction kanıtı içindir, gerçek HTTPS/TLS acceptance değildir. Kullanıcı talimatıyla hiçbir test/typecheck/lint/build/browser çalıştırılmadı; OpenAPI üretildi.
- Yeni şema/DB mutation geliştirme sırasında yapılmadı, gerçek kaynak/provider çağrısı yok. URL source oluşturma ve ingest UI henüz bağlanmadı; network transport tam davranış testleri/final doğrulama ve kalan fazlar açık. Faz6/goal aktif.


### 2026-10-27 — URL kaynak oluşturma ve HTTPS ingest arayüzü

- Kaynak oluşturma ekranına HTTPS web sayfası türü eklendi. Mevcut source create endpoint'ine source_type=url ve girilen source_ref gönderilir; oluşturmak network/ingest tetiklemez. URL şeması mevcut API300 karakter limitini korur; temel HTTPS/no-credentials/no-fragment kontrolü yapılır, server SSRF/allowlist yetkisi ingest sırasında ayrıca zorunludur. Aynı oluşturma request/key recovery mevcut mekanizmayı kullanır.
- URL kaynak sürümlerinde HttpsIngest paneli tenant policy'yi server'dan okur, nonempty policy ve aktif/ready kaynak gerektirir. İstek yalnız source public ID, expected_version_no, expected_policy_version ve key taşır; URL/allowlist client override yoktur.10MiB/JS-loaded içerik sınırı ve policy yönetim konumu açıklanır. Doğrulanmış receipt'ten sürüm başarısı gösterilir.
- Unknown outcome aynı body/key ile retry olur; source içi gezinme busy olarak kilitlenir. Kesin4xx source versions ve policy refetch eder, success Knowledge cache'ini invalid eder. Policy load/error/empty ve retry durumları vardır. Full router/reload recovery halen ortak açık iş olarak korunur.
- Client test kodu URL source oluşturma body/onCreated ve HTTPS ingest unknown outcome'da aynı kaynak/policy sürümleriyle replay, request'te URL bulunmaması ve verified receipt içindir. Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. API/DB kontratı veya şema değişmedi; gerçek URL/provider çağrısı yok.
- HTTPS ingest uçtan uca kaynak kodu bağlandı fakat gerçek transport/TLS/timeout/body-limit testleri ve final kabul doğrulaması henüz tamamlanmadı. Faz6 retrieval/runtime release ve kalan fazlar açık; goal aktif.


### 2026-10-27 — HTTPS yanıt bütünlüğü ve bounded stream davranışı

- Production transport response reader ayrı modüle ayrıldı. Yalnız HTTP complete=true ve varsa Content-Length ile birebir byte eşleşmesi sonrası içerik döner. Premature close/aborted/error başarısızdır; kısmi belge ingest'e geçmez. Fail/settled guard tekrar eventlerle buffer büyümesini veya ikinci sonuç üretimini engeller; hatada chunk referansları temizlenir ve stream/socket kapatılır.
-10MiB sınırı chunk eklenmeden uygulanır; content type/encoding/status/header-limit davranışı korunur. Redirect response body tüketilmeden kapatılır. Geç gelen stream error eventleri için sanitized listener korunur. Yeni bağımlılık veya public kontrat değişimi yok.
- PassThrough fixture kullanan test kodu parçalı başarılı yanıt, premature close, declared-length mismatch, incomplete message, streamed/declared overflow, compressed/non-page/error status, redirect no-body ve aborted/late error durumlarını production reader üzerinden kapsar. Network açmaz; TLS/DNS/redirect orchestrator acceptance kanıtı değildir. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı.
- HTTPS gerçek transport kabul doğrulamaları ve final testler hâlâ açık. Faz6 retrieval/runtime release ve kalan fazlar aktif; goal tamamlanmadı.


### 2026-10-27 — Runtime araç isteklerinde payload uyuşmazlığı

- F06 runtime incelemesinde mevcut request_ref replay yolunun farklı input/binding ile aynı anahtarı eski işlem gibi döndürdüğü bulundu. Yeni araçlar bağlanmadan önce bu temel düzeltildi: duplicate lookup tenant+call session+request_ref scope'unu korur; orijinal run binding/definition/version/environment ve canonical input+request metadata eşitliği zorunludur. Farklı payload/binding veya eksik run409 döner; private payload hata mesajına yazılmaz.
- Completion call_tool_executions.metadata'yı result metadata ile güncellediği için replay karşılaştırması original tool_execution_runs.metadata üzerinden yapılır. Başarılı aynı-request replay mevcut public receipt/status mapper'ını korur; internal ID veya input response'a eklenmez. Yeni şema/network/provider işlemi yok.
- Mevcut runtime integration testine changed input/metadata409 ve completion metadata değiştikten sonra aynı request replay başarı senaryoları eklendi. OpenAPI409 ve replay sözleşmesi güncellendi/üretildi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı.
- Bu düzeltme araç execution/confirmation/release altyapısını tamamlamaz. Terminal result transition/replay koruması, yeni tool JSON contracts/teyit tokenı, runtime snapshot/release bağlantısı, bilgi kaynaklı cevap kanıtı ve kalan fazlar halen açık. Faz6/goal aktif.


### 2026-10-27 — Runtime araç sonuçlarında terminal durum ve tekrar koruması

- completeRuntimeToolExecution tenant/environment çözümlemesini transaction içine aldı; call_tool_executions ve bağlı run FOR UPDATE ile sıralı kilitlenir. Kayıp veya uyumsuz run fail-closed409 reconciliation ister. Aynı status+output+error+metadata tekrarında yazma yapılmaz, original completed_at döner. Terminal succeeded/failed/cancelled değiştirilemez veya in_progress'e geriletilemez; aynı status farklı payload409'dur.
- Requested→in_progress veya terminal, in_progress→terminal geçişleri korunur. started_at yalnız in_progress sinyali geldiğinde ilk kez yazılır ve tekrarlarla kaydırılmaz; doğrudan terminal sonuçtan geçmiş başlangıç zamanı uydurulmaz. İşlem/run çıktıları aynı transaction'da güncellenir. Lock timeout5s; genel DB lock error mapping mevcut hata katmanına kalır.
- Integration test kodu concurrent identical in_progress, terminal identical replay/original timestamp, terminal→in_progress/failed ve changed output/metadata409 senaryolarıyla genişletildi. OpenAPI409/result replay sözleşmesi üretildi. Test/typecheck/lint/build kullanıcı talimatıyla çalıştırılmadı. Yeni şema veya gerçek provider çağrısı yok.
- Yeni araç JSON contracts/teyit tokenı/tenant adapter, runtime release bağı ve bilgi kaynaklı cevap kanıtı halen açık. Bu mevcut internal runtime primitive'inin güvenli durum ilerlemesidir; gerçek araç yürütmesi veya provider kabulü iddiası yoktur. Faz6/goal aktif.


### 2026-10-27 — V1 caller araç veri sözleşmeleri

- Platform-owned version1 katalog product_lookup, appointment_availability/create/cancel, crm_lookup/upsert için strict Zod input/output ve inferred TS modelleri tanımlar. Arbitrary URL/code/SQL/tenant override alanları kabul edilmez. External refs yalnız opaque referanstır; endpoint seçimi veya fetch hedefi olarak kullanılmamalıdır. CRM sorgusu runtime'ın yetkilendireceği contact public UUID ile yapılır; keyfi eposta/telefon sorgusu yoktur.
- Fiyatlar nonnegative decimal string (18 integer/6 fractional digit) +3 uppercase currency code taşır; unavailable fiyat ayrı varianttır, sıfır diye uydurulmaz. Canlı cevaplar source_ref/observed_at/expires_at taşır; expiry>observation kontrolü vardır. Milisaniyeli UTC ISO zamanlar, availability window max31 gün, slot max24saat/50 unique slots tanımlandı. Currency gerçek ISO listesi ve sonucun request'e/şimdiki zamana uygunluğu adapter/use-case aşamasında ayrıca doğrulanmalıdır.
- Yazma inputlarında confirmation_token ve UUID idempotency_key zorunludur. Bu yalnız transport shape kontrolüdür, teyit yetkisi değildir. Token issue/binding/expiry/atomic consumption ve tenant/session/contact bağları henüz implement edilmedi. Sonuç succeeded/rejected/unknown olarak ayrıdır; unknown→kör retry izni verilmez. Secret/token log veya audit'e yazılmamalıdır.
- Unit test kodu decimalprecision/zero-vs-unavailable, time range/duplicate slot, provenance ordering, teyitsiz write ve unknown-result ayrımı, extra-field/ownership override reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Şema/DB/sağlayıcı çağrısı ve public endpoint değişmedi.
- Bu katalog mevcut legacy runtime tool route'una henüz uygulanmadı; dış adapter, result/request correlation, confirmation lifecycle ve campaign release binding sonraki işlerdir. Katalog eklemek gerçek araç bağlantısı/yayın veya doğrulama iddiası değildir. Faz6/goal aktif.


### 2026-10-27 — Caller tool sonuç uygunluğu temeli

- Internal CallerToolResultService.validate mevcut version1 input/output şemalarını kullanır; provider hatası private payload içermeyen BAD_GATEWAY502'ye döner. Trusted adapter context sourceRef/now/operationRef sağlar; bu değerler provider cevabından kopyalanmamalıdır.
- Provenance source eşleşmesi, future observation reddi, expiry>now ve en fazla5 dakika yaş/TTL denetlenir. product_ref istekle eşleşir; availability slotları aynı service ve requested window içinde/gelecekte olmalıdır. Appointment create sonucu exact slot hash'ine, cancel sonucu appointment_ref'e bağlıdır. Succeeded/unknown write operation_ref server context ile eşleşir; future completed_at reddedilir.
- Bu katman yürütme yetkisi veya teyit tokenı tüketimi sağlamaz. Yazma sonrasında validation hatası dış işlemin yapılmadığı anlamına gelmez; belirsiz sonuç/mutabakat olarak ele alınmalı ve yeni key ile kör retry edilmemelidir. CRM contact→external record ownership tenant-scoped adapter'da ayrıca doğrulanmalıdır; mevcut wire schema bunu tek başına kanıtlamaz.
- Unit test kodu matching evidence/no invented price, wrong product/source, expired/future/overlong TTL, yanlış service/window ve unknown write operation correlation için eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Production runtime/adapter call-site henüz bağlanmadı; yeni bağımlılık/şema/dış çağrı yok.
- Teyit token lifecycle, gerçek adapter, request/contact/session ownership, runtime release ve bilgi cevap kanıtları sonraki işler. Faz6/goal aktif.


### 2026-10-27 — Araç teyidi için işlem içeriği ve kapsam bağı

- Randevu oluşturma/iptal ve CRM güncelleme şemaları artık token gerektirmeyen strict intent ve authorization zorunlu execution input olarak ayrıdır. Mevcut execution sözleşmesi değişmedi; hazırlanan intent tek başına yürütülemez.
- Internal CallerToolConfirmationService.prepare normalize edilmiş içeriği tenant, session, release, binding, binding version ve contact public UUID bağları ile domain-separated SHA256 digest'e bağlar. Kişi uyumsuzluğu, token/confirmed gibi ek alanlar ve geçersiz kapsam reddedilir; hata cevabına payload/secret yazılmaz. Onayda kullanıcıya sunulacak içerik, dönen normalize intent olmalıdır.
- Bu primitive ownership veya gerçek sözlü onay kanıtı değildir. Scope server tarafından yetkili DB kayıtlarından çözülmelidir; digest yalnız bütünlük bağıdır, yetki veya secret değildir. Kalıcı challenge/token hash, doğrulanmış teyit olayı, süre sonu, atomik execution reservation/tüketim ve runtime entegrasyonu halen yapılacak. Public endpoint veya canlı provider bağlantısı açılmadı.
- Unit test kodu scope alanı/kişi/randevu saati/CRM içerik değişiklikleri, secret ve model-confirmed alanı reddi, normalize içerik ve token olmadan execution reddi için eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Bağımlılık/DB şeması değişmedi; Faz6/goal aktif.


### 2026-10-27 — Kalıcı araç teyit kaydı temeli (migration131)

- caller_tool_confirmations tablosu tenant/session composite FK, versioned tool code, intent digest, yalnız SHA256 token hash ve opaque doğrulanmış teyit olay referansı taşır; ham token/konuşma/payload saklanmaz. Aynı oturum teyit olayı yeniden issue edilemez, aynı execution iki teyide bağlanamaz. Execution tenant FK ile korunur.
- DB zamanıyla issued/consumed/revoked timestamp, en fazla5 dakika geçerlilik, değişmez identity/intent/expiry ve terminal durumdan geri dönüş yasağı tanımlandı. Aynı terminal yazım zamanını değiştirmez. Tokenı tüketmek bağlı execution gerektirir; execution silme RESTRICT, oturum/tenant silme CASCADE ile retention zincirine dahildir. Silme yetkisi/purge protokolü ayrıca uygulanmalıdır.
- Bu tablo consent kanıtının gerçekliğini, active release/session/contact/binding uygunluğunu veya execution'ın ilgili oturuma ait olduğunu tek başına kanıtlamaz. Bunlar trusted service tarafından doğrulanıp execution reservation ile aynı transaction içinde tüketilmelidir. Henüz public endpoint/issue/consume servisi/runtime çağrısı açılmadı; canlı araç işlemi yok.
- Migration131 yerel haisly_caller/127.0.0.1 üzerinde pg_dump yedeği sonrası tek transaction ile uygulandı. Test DB'lerine henüz uygulanmadı. Rollback dolu tabloda evidence silmeyi reddeder. API Kysely tipi eklendi; client sadece ilerleme notu aldı.
- İzole *_test DB için SQL regression senaryoları tenant/session ayrımı, intent/expiry immutability, tekrar teyit olayı, TTL, executionsız tüketim, revoke/reset ve terminal consumption replay için yazıldı; kullanıcı talimatıyla test/typecheck/lint/build/rollback çalıştırılmadı. Migrationın uygulanması bu kabul testlerinin geçtiği anlamına gelmez. Faz6 ve goal aktif.


### 2026-10-27 — Teyit tokenı issue/consume transaction primitive'leri

- CallerToolConfirmationStore yalnız internal Transaction<Database> üzerinde issue/consume sağlar. Tenant/public scope, aktif tenant/environment, oturum, aktif binding + published tool version/definition ve agent scope eşleşmesi kontrol edilir. Kişi tenant/current identity revision/active/archive kontrolleri tenant identity lock altında yapılır. Digest kapsamına contact_identity_revision eklendi; eski kimlik teyidi geçmez.
- Issue aktif oturumda 256-bit rastgele base64url token üretir, yalnız SHA256 hash ve verified event reference kaydeder,5 dakika DB zamanlı expiry döndürür. Aynı olay yeniden token üretmez. Hash-only storage nedeniyle kayıp issue yanıtından token kurtarılamaz; mutabakat sonrası yeni teyit gerekir. Sözlü teyit kanıtının doğrulanması bu primitive'in işi değildir.
- Consume aynı transactionda ayrılmış execution/call_tool_execution kayıtlarını tenant/session/environment/binding/version/input ve session:UUID idempotency key ile eşleştirir. İki execution payload'ında authorization/token bulunmamalıdır; yalnız normalized intent saklanır. Kilitli teyit kaydında digest/hash/expiry/revoke kontrolü ve tek execution'a tüketim uygulanır. Aynı tüketimin tekrarında replayed=true döner; bu yeniden dış işlem yapma yetkisi değildir. İlk tüketim yalnız active session + pending/requested execution durumunda olur.
- Orchestrator tenant caller-contact lock'unu execution reservationdan önce almalı; runtime kimlik doğrulaması, permission, release/session/contact sahiplik bağlantısı, verified consent evidence ve minimum audit aynı transactionın önkoşullarıdır. Dış yazım commit sonrası yapılır; belirsizlikte yeni execution ile tekrar yapılmaz. Bu katman henüz route/legacy runtime'a bağlanmadı; eksik release/consent kanıtına dayanarak yetki açılmadı.
- İzole PostgreSQL integration test kodu hash-only storage, duplicate event, yanlış tenant/identity/input/token/release ve same-execution replay için eklendi; unit identity revision testi genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Migration131 dışında şema değişikliği veya canlı provider çağrısı yok. Eşzamanlı transaction/rollback/expiry ve runtime bağlantı kabulü final geliştirme/doğrulamada halen açık; Faz6/goal aktif.


### 2026-10-27 — Yayın adayı içerik/araç manifesti

- CallerReleaseService.prepare internal transaction primitive'i immutable authoring snapshot, kayıtlı compilation, agent ve kimlikten adayı oluşturur. Derlemeyi yeniden hesaplayıp kayıtlı artifact ile eşleştirir; eski/eksik/bozuk artifact sessizce yeniden yayınlanamaz. Tenant/environment aktifliği, agent published/aktif/archive, tenant outbound phone ve seçili araç binding/version/definition/agent scope kontrolleri shared lock altında yapılır.
- Strict caller-release-v1 manifesti tenant/environment/outbound phone, mevcut content_binding_hash ve en fazla6 tekil platform tool pin'i taşır. Pin exact binding/version public ID, contract version1 ve input/output schema + execution config hash içerir. Ham araç config/secret manifestte yer almaz. Rastgele SQL/HTTP tool code kabul edilmez; bu kontrol endpoint güvenliği veya adapter aktivasyonu değildir.
- Release fingerprint tool code sırasına normalize edilir. İçerik/agent(ses/model)/bilgi/anket mevcut content binding aracılığıyla, araç sürümü/config ve arayan kimlik manifest aracılığıyla test kimliğini değiştirir. Hedefler/listeler/takvim/bütçe/snapshot public ID manifestte yoktur; bunların ayrıca dispatch/publication kapıları vardır. Kaynak snapshot public ID aday zarfında taşınır, release_hash'e katılmaz.
- publication_available=false korunur. Kalıcı release artifact, test çağrısı/simülasyon kanıtı, sağlayıcı/privacy/araç adapter uygunluğu ve runtime release/session/contact ilişkisi henüz bağlanmadı. Bu primitive route'a açık değildir; permission/auth orchestrator önkoşuludur. Manifesti kaydedecek servis aynı transactionı kullanmalıdır.
- Unit test kodu determinism/sıra, içerik/scope/araç değişimi, duplicate/unsupported contract ve operational-field reddi için eklendi. Test/typecheck/lint/build kullanıcı talimatıyla çalıştırılmadı. DB şema veya canlı sağlayıcı değişikliği yok; Faz6/goal aktif.


### 2026-10-27 — Kalıcı immutable yayın adayları (migration132)

- caller_release_artifacts tenant/snapshot/environment/outbound phone composite FK'leriyle eklendi. Aynı tenant+snapshot+release hash tekildir; değişen operation-only snapshot aynı release hash ile ayrı artifact saklayabilir, test kanıtı hash üzerinden yeniden kullanılabilir. Manifest16KiB sınırındadır; DB trigger manifestin tenant/environment/phone/content binding ile eşleşmesini ve update immutability'yi korur. Dolu tabloda rollback reddedilir; DELETE retention yetkisi ayrı servisin sorumluluğudur.
- CallerReleaseService.capture aday hazırlığını ve insert/reuse'u aynı transactionda gerçekleştirir; dış manifest/hash kabul etmez. Çakışan kayıt yalnız hash'e güvenilmeden manifest ile karşılaştırılır. read tenant kapsamıyla saklanan manifesti strict parse edip canonical hash'i yeniden doğrular. Her iki çıktı publication_available=false taşır; mevcut durum uygunluğu veya test başarısı iddiası yoktur.
- Agent version/environment eşleşmesi hazırlık kapısına eklendi; aynı tenantın farklı environment agent sürümü kullanılamaz. Yeni artifact tipi API DB/model katmanlarına kaydedildi. Runtime release/session/contact ilişkisi, test kanıtı/certification, yayın endpoint/UI/audit ve dispatch gate halen açık; internal primitive'lerin permission/auth/audit çağıran orchestrator önkoşuludur.
- Migration132 yalnız yerel haisly_caller/127.0.0.1 üzerinde pg_dump yedeği sonrası transaction ile uygulandı. Test DB'lerine henüz uygulanmadı. PostgreSQL integration test kodu capture/read/reuse, farklı ortam reddi, operational snapshot için hash korunması ve immutable update reddi için eklendi. Kullanıcı talimatıyla test/typecheck/lint/build/rollback çalıştırılmadı. Migration uygulaması kabul testinin yerine geçmez; Faz6/goal aktif.


### 2026-10-27 — Yayına sabitlenen araç çözümleme ve yetki kapsamı fingerprint'i

- caller-tool-configuration-v2 hash'i input/output schema ve execution config yanında binding_scope ve bağlı agent kimliğini kapsar. Tenant↔agent scope değişimi ve agent reassignment eski test/release kimliğini geçersiz kılar. Internal agent ID yalnız hash girdisidir; public manifestte açığa çıkarılmaz. Driver bigint string/number biçimi aynı kimliğe normalize edilir.
- Ortak loadReleaseToolBinding current active tenant/environment binding, published version, definition ve agent scope eşleşmesini shared lock altında çözer. Hazırlama servisi aynı yordamı kullanır; iki farklı araç çözümleme kuralı oluşmaz.
- CallerReleaseService.resolveTool yalnız server-selected stored release içinde pinlenmiş tool code'u döndürür. Stored manifest/hash doğrulaması sonrası tüm pinleri/current agent/phone/environment ile yeniden hazırlayıp hash eşleşmesi ister; missing/disabled/reconfigured/reassigned/unpinned araç reddedilir. Dönen değer public pin'dir, adapter secret/config/internal ID değildir. Session ownership/consent/test certification/runtime route bağlantısı halen ayrıca gerekli; bu primitive tek başına execution yetkisi değildir.
- Eski configuration-v1 pinleri sessizce upgrade edilmez; historical read mümkün olsa da resolveTool yeni fingerprint ile eşleşmediğinde reddeder ve yeniden capture/test gerektirir. Veritabanı migrationı veya eski artifact update'i yoktur.
- Unit test kodu scope/reassignment/config değişimi, PostgreSQL integration kodu pinned/unpinned/disabled araç ve scope değişiminden sonra eski release reddi/yeni release kabulü için genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Bounded6 pin revalidation performans kabulü finalde ölçülecek. Faz6/goal aktif.


### 2026-10-27 — Üretim outbound runtime yayın/dispatch bağı (migration133)

- caller_runtime_release_bindings tenant-scoped session/release/dispatch composite FK ve session/dispatch tekillikleriyle eklendi; bağ update ile değiştirilemez. Insert trigger tenant identity lock ve kaynak row share lock altında accepted dispatch/provider call reference, outbound call/session live durumları, phone/snapshot/environment/agent-version ve current contact identity eşleşmesini ister. Salt tenant eşleşmesi yeterli değildir. DELETE/retention ayrı yetkili protokolün sorumluluğudur; dolu tabloda rollback reddedilir.
- CallerRuntimeService.attach authenticated orchestrator'dan türetilmiş tenant/environment/provider account ile kimlikleri çözer; farklı bağa replay reddedilir. Eşleşen mevcut bağ receipt olarak döner, tekrar yürütme hakkı vermez. Mevcut calls provider identity tenant+provider_call_id modelindedir; çoklu hesap çakışmaları provider/call materialization aşamasında ayrıca ele alınmalıdır.
- resolve aktif görüşme/call/dispatch ve current identity ilişkilerini her kullanımda yeniden sorgular; release manifest/hash kontrolünü yapar. resolveTool kayıtlı release'te pinlenmiş ve halen eşleşen aracı çözüp confirmation_scope'u server kayıtlarından üretir. issueToolConfirmation/consumeToolConfirmation bu scope ile mevcut token store'a bağlandı; kullanıcı/model sağladığı release/contact/binding seçimine güvenilmez.
- Bu internal katman gerçek sözlü teyit doğrulaması, runtime authentication route'u, yayın/test certification ve dispatch izinlerinin yerine geçmez. Provider/call/session materialization henüz attach'i çağırmıyor. Test ve inbound görüşmeler bu production-dispatch yoluna taklit bağlanamaz; kendi doğrulanmış akışları gereklidir. Canlı sağlayıcı çağrısı veya yayın açılmadı.
- Migration133 yerel haisly_caller/127.0.0.1 üzerinde pg_dump yedeği sonrası atomik uygulandı. Generic/unbound sessionın runtime teyit tokenı üretememesine dair integration test kodu eklendi. Accepted dispatch tam fixture'ıyla positive attach/resolve, parent mutation, tenant/environment/provider mismatch, parallel attach ve identity correction senaryoları final doğrulamadan önce tamamlanacak. Kullanıcı talimatıyla test/typecheck/lint/build/rollback çalıştırılmadı. Faz6/goal aktif.


### 2026-10-27 — Runtime'a sabitlenen bilgi kaynağı erişimi

- CallerRuntimeService.searchKnowledge/readKnowledgeFragment kayıtlı ve aktif outbound görüşme bağını resolve ederek snapshot'ı server-side türetir. Runtime input strict query/limit veya version/chunk/offset taşır; snapshot/tenant/release/contact/session override kabul etmez. Yanıt release ve session public ID ile mevcut kaynak/version/chunk checksum ve priority kanıtını birlikte taşır.
- KnowledgeContentService'in search/read mantığı shared transaction primitive'lerine çıkarıldı; authoring preview wrapper'ları aynı davranışı korur. Runtime identity kontrolü ile içerik erişimi aynı transactionda yapılır, nested transaction açılmaz. Version/source/collection satırları share lock ile tutulur; deactivation kontroller arası yarışamaz. Query ve fragment okumaları2s transaction-local statement timeout uygular; çağıran işlem bu timeoutun transaction sonuna dek sürdüğünü dikkate almalıdır.
- İçerik SQL'de4000 Unicode karakter/16KiB bounded fragment olarak kalır; lexical search en fazla16 aday,100 pinned source sınırı ve no-match/timeout ayrımını korur. Bu bir semantic conflict detector veya cevap doğrulaması değildir. Query/içerik ayrıca DB/log'a yazılmadı; no-recording akışının provider tarafı halen doğrulanmalı.
- Unit test kodu scope override reddi ve limit/default davranışlarını kapsar. Integration kodunda unbound session bilgi erişimi reddi ve existing authoring primitive'lerinin açık transaction içinde aynı sonucu üretmesi eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Positive accepted-dispatch runtime fixture, cevap provenance/çelişki yönlendirmesi, runtime endpoint/auth/rate/audit ve yayın certification halen açık. Şema/dış çağrı değişikliği yok; Faz6/goal aktif.


### 2026-10-27 — İmzalı runtime bilgi endpoint'leri

- POST /api/internal/v1/call-sessions/:call_session_public_id/knowledge-search ve /knowledge-fragment route/controller/service katmanları bağlandı. Service mevcut runtime service-account authentication/signature doğrulamasını ve ayrı runtime.knowledge.read allow/deny scope kontrolünü kullanır; hiçbir mevcut hesaba otomatik scope verilmedi. Tenant/environment auth sonucundan, snapshot/contact/release aktif runtime bağından çözülür.
- Strict session params/body validation;4KiB search/1KiB fragment limit; shared sensitive rate limit; onSend Cache-Control:no-store; mevcut logger req.body/signature/authorization redaction davranışı kullanılır. Query metni URL'ye konmaz, read-only sorgular idempotency receipt veya content audit kaydı oluşturmaz. Content/PII yanıtı yalnız scoped runtime'a döner.
- OpenAPI iki endpoint/request/result/error sözleşmesiyle güncellendi ve generate-openapi çalıştırıldı. Bu doküman üretimidir, test/build sonucu değildir. Client management arayüzüne runtime token veya bu endpointler açılmadı.
- Integration test kodu signed runtime'da scope403, scope verilse de unbound session409, snapshot/release/tenant override400, body413, no-store ve scope revoke403 senaryolarını kapsar. Test rate limit kapalı fixture kullanır; gerçek rate limiter/positive accepted-dispatch retrieval ve kapsamlar arası izolasyonun tam uçtan uca kabulü henüz doğrulanmadı. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı.
- Provider/session materialization, verified release certification ve positive dispatch fixture bağlantısı halen açık. Bağlanmamış session bu endpointleri kullanamaz. Şema/sağlayıcı çağrısı değişmedi; Faz6/goal aktif.


### 2026-10-27 — Accepted-dispatch runtime bütünleşik test senaryosu

- Mevcut dispatch fixture'ına published agent config ve derlenebilir kampanya talimatları eklendi. Provider accepted event mevcut production transition/receipt yolu ile kaydedildikten sonra verifyBoundRuntime çağrılır; doğrudan dispatch state zorlanmaz. Bu fixture gerçek provider kanıtı değildir.
- Yeni test kodu aynı snapshot/agent/phone/provider correlation ile release capture, outbound call/session, attach/replay, server-derived contact/release scope, boş sabit bilgi manifestinde arama, pinlenmiş appointment_cancel için issue/consume ve exact consumption replay akışını kapsar. Runtime satırları sentinel rollback ile geri alınarak mevcut billing/history/stop testlerinin verisi korunur.
- Yanlış provider hesabı/tenant/environment/contact, aynı session için başka release, aynı dispatch için ikinci session, immutable binding rewrite, parent call provider reference değişimi ve completed call sonrasında runtime erişimi reddi eklendi. Bu senaryolar yalnızca yazıldı; kullanıcı talimatıyla hiçbir test/typecheck/lint/build çalıştırılmadı.
- Positive HTTP knowledge response/fragment, gerçek paralel attach/consume yarışları, provider session materialization ve sözlü consent/certification kabulü halen açık. Faz6/goal aktif; bu kayıt testlerin geçtiği veya canlı entegrasyonun tamamlandığı anlamına gelmez.


### 2026-10-27 — Görüşmeye bağlı anket başlangıcı ve sıradaki soru

- Runtime resolve artık dispatch hedefini tenant/snapshot/contact/identity/campaign eşleşmesiyle kilit altında çözer. Anket başlangıcı ve okuması hedefi ve sabit anket sürümünü bu kayıttan türetir; istemcinin hedef seçimine güvenmez.
- Internal startSurvey mevcut cevapları korur ve partial anketi otomatik devam ettirmez. readSurvey yalnız aktif ankette sıradaki sorunun gerekli alanlarını döndürür; cevap geçmişi ve koşul ifadeleri runtime çıktısına eklenmez. Partial durumda resume_required, tamamlanan/reddedilen/duraklatılan ankette null soru döner.
- Yanlış snapshot, pause sonrası soru gizleme/cevap koruma, tamamlanmış anket ve marketing görüşmesinde anket reddi için test kodu eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Şema veya canlı sağlayıcı değişikliği yok.
- Bunlar internal transaction primitive'leridir. Başlatma/yeniden devam onayı, cevap komutlarının idempotency receipt ve audit bağlantısı, dış runtime endpointleri ve gerçek provider kabulü halen açık; Faz6/goal aktif. Kullanıcı ElevenLabs/SIP/test hattının henüz hazır olmadığını teyit etti; bağımsız geliştirme sürüyor.


### 2026-10-27 — Anket komutlarında atomik işlem kaydı ve audit

- CallerRuntimeSurveyCommandService server-authenticated runtime kimliği ve runtime.survey.write scope ister; tenant/environment/session bağını çözerek hedef/snapshot/release/current identity kapsamını server kayıtlarından türetir. Ayrı scope hiçbir hesaba otomatik verilmez.
- Strict UUID idempotency key + pozitif expected_version + mevcut answer/skip/revise/clarify/pause/decline sözleşmesi eklendi. Resume/start bu yoldan kabul edilmez; ayrı doğrulanmış onay akışına aittir. Mevcut anketin tam snapshot eşleşmesi yazımdan önce kontrol edilir.
- Mevcut idempotency_keys altyapısı kullanılır; payload hash görüşme kapsamıyla bağlanır. Receipt kontrolü sürüm geçişinden önce yapılır, farklı payload aynı key ile reddedilir. Cevap revizyonu, minimal audit ve completed receipt çağıranın aynı transactionında yazılır. Rollback hepsini geri alır. Receipt yalnız public kimlikler/sürüm/durum/geçersizleşen sıra numaraları içerir; cevap değeri ve soru metni audit/receipt'e kopyalanmaz. Replay strict receipt şeması ve release/session eşleşmesini doğrular.
- Canlı bağ resolve kontrolü replay için de gereklidir; sona ermiş veya kimliği değişmiş görüşmede bu komut yolu kullanılmaz. Bu durumlar için salt tarihsel receipt/mutabakat endpointi henüz yoktur. Receipt expiry mevcut24saat altyapısını kullanır; expected_version eski işlemin yeniden uygulanmasına karşı ek korumadır.
- Unit test kodu komutlar/limitler/ownership override/consent bypass/receipt privacy; integration test kodu unbound session ve açık scope deny reddi, receipt oluşmaması için eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Pozitif bound-survey replay/rollback/concurrency kabulü, correction outbox ve post-call aksiyonlar, authenticated HTTP endpoint, başlangıç/devam onayı ve no-recording uçtan uca kabulü halen açık. Yeni migration/dış çağrı yok; Faz6/goal aktif.


### 2026-10-27 — İmzalı runtime anket komut endpointi

- POST /api/internal/v1/call-sessions/:call_session_public_id/survey-command route/controller/authenticated request service olarak bağlandı. Mevcut imzalı service-account ve runtime surface doğrulaması ile ayrı runtime.survey.write scope zorunlu; tenant/environment server auth sonucundan gelir. Scope otomatik atanmaz.
- 64KiB body sınırı, strict payload/path validation, ayrı sensitive rate-limit kuralı ve başarı/hata yanıtlarında Cache-Control:no-store eklendi. Mevcut logger body redaction kullanılır. Request service tüm komut/audit/receipt işlemini tek transaction içinde yürütür.
- Başlatma/devam ettirme bu endpointte kabul edilmez. Mevcut anket, aktif accepted-dispatch/release bağı ve current identity zorunludur. Yanıt yalnız minimal komut receipt'idir; sonraki soru ayrıca okunur. İmzalı endpointin varlığı provider/session materialization, başlangıç onayı veya publication certification tamamlandı anlamına gelmez.
- OpenAPI tüm alt komutlar, limitler, receipt ve hata durumlarıyla güncellendi; generate-openapi doküman üretimi yapıldı. Integration test kodu scope deny/revoke, unbound session, ownership override, start/resume reddi, body413, no-store ve reddedilen istekte receipt oluşmamasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Fixture rate limit kapalıdır; pozitif survey HTTP/replay/rollback/concurrency ve rate-limit kabulü finalde halen açık. Şema/client ürün UI/dış sağlayıcı değişikliği yok; Faz6/goal aktif.


### 2026-10-27 — Runtime sıradaki anket sorusu endpointi

- POST /api/internal/v1/call-sessions/:call_session_public_id/survey-read imzalı runtime auth ve ayrı runtime.survey.read scope ile bağlandı. Write scope read yetkisi vermez; hiçbir hesaba scope otomatik atanmaz. Strict boş JSON gövdesi hedef/snapshot/soru/komut override kabul etmez.
- Request service aktif runtime bağını ve mevcut anketi aynı transactionda okur. Sıradaki soru server flow'dan gelir; cevap geçmişi ve show_when ifadeleri dönmez. Partial/completed/declined durumda soru null; resume_required sadece durum bilgisi olup devam izni değildir. Okuma anket yaratmaz veya ilerletmez.
- 1KiB body sınırı, ayrı sensitive rate-limit kuralı ve başarı/hata yanıtlarında no-store eklendi. OpenAPI soru tipleri/alanları/null durumları ve hatalarla güncellendi; generate-openapi çalıştırıldı. Read path receipt veya içerik audit kaydı oluşturmaz.
- Unit test kodu boş nesne ve override reddini; signed HTTP integration kodu write/read scope ayrımı, scope revoke, unbound session, body413 ve no-store davranışlarını kapsar. Test/typecheck/lint/build kullanıcı talimatıyla çalıştırılmadı. Pozitif bağlı anket uçtan uca akışı, onay challenge/evidence ve gerçek provider/session materialization halen açık. Şema/dış bağlantı değişikliği yok; Faz6/goal aktif.


### 2026-10-27 — Anket başlangıç/devam onayı sözleşmesi

- Mevcut genel consent_records payload'ı anket hedefi/snapshot/cevap sürümünü zorunlu bağlamadığı için doğrudan resume yetkisi olarak kullanılmadı. SurveyConsentService.prepare strict server-resolved tenant/session/release/target/snapshot/contact/current identity scope, tr/en dil ve start/resume amacını canonical digest'e bağlar. Start yalnız survey=null/version0, resume mevcut survey UUID/pozitif sürüm kabul eder.
- Türkçe/İngilizce başlangıç ve devam soruları survey-consent-v1 sürümüyle digest'e dahil edildi; amaç, dil, cevap sürümü veya kimlik değişirse önceki onay kullanılamaz. Bu pure hazırlık henüz challenge kaydı oluşturmaz ve başlatma yetkisi vermez.
- checkObservation trusted observer'dan gelecek yapılandırılmış olayın challenge/digest eşleşmesini, farklı prompt/response event referanslarını, prompt tamamlandıktan sonraki cevap sırasını ve en fazla5dakikalık expiry'yi kontrol eder. granted/denied/unknown ayrımı korunur; confirmed boolean, transcript/alıntı gibi ek alanlar reddedilir. Tarih/korelasyon kontrolü provider imzası veya kişinin gerçekten söylediğine dair kanıt değildir.
- Kalıcı challenge ve tek tüketim, doğrulanmış observer olayının kaydı, current scope/version yeniden çözümleme ve start/resume transaction bağlantısı henüz açık. Genel model/istemci observation iddiası doğrudan yetki olarak kabul edilemez. Kayıtsız moda uygun minimum metadata yaklaşımı korunur; ses/transkript depolanmadı.
- Unit test kodu scope/version/language değişimi, strict schema, expiry/sıra/korelasyon reddi ve belirsiz/olumsuz kararın korunmasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Yeni DB migrationı veya dış bağlantı yok; Faz6/goal aktif.


### 2026-10-27 — Kalıcı anket onay challenge kayıtları (migration134)

- caller_survey_consent_challenges tenant/runtime binding ve mevcut/uygulanan survey session bileşik FK'leriyle eklendi. Start survey=null/version0, resume survey+pozitif version ister. Scope/digest/dil/prompt sürümü ve issued/expires alanları immutable; DB saatiyle5dakika ömür atanır.
- Karar ve prompt/response event referansları tek seferliktir; aynı runtime binding içindeki response event tekrar kullanılamaz. Sonuç zamanları prompt→response→resolved sırasını ve expiry'yi korur. granted dışı karar tüketilemez. Tüketim aynı hedef/snapshot için uygulanmış active anket sürümünü ister; aynı survey/version geçişi ikinci bir challenge'a bağlanamaz. Tüketilen kayıt değiştirilemez.
- Insert/transition guard aktif accepted outbound görüşme, güncel contact identity, hedef/snapshot ve survey kampanya tipini tenant identity lock altında kontrol eder. Resume issue partial ve beklenen sürüme, start issue henüz açılmamış ankete bağlıdır. Parent relation FK'leri restrict; retention/delete protokolü sonraki veri yaşam döngüsü katmanının sorumluluğudur. Boş olmayan history için rollback reddedilir.
- API merkezi DB tipleri güncellendi. Accepted marketing runtime fixture'ında survey consent insert reddi için integration test kodu eklendi. Pozitif issue/decision/consume, immutable/replay/expiry/tenant/concurrency kapsamının tamamlanması ve güvenilir observer doğrulama/servis/endpoint bağlantıları halen açık. DB yapısı tek başına gerçek sözlü onay kanıtı değildir.
- Migration134 yalnız local haisly_caller/loopback kimliği doğrulanıp özel izinli pg_dump yedeği alındıktan sonra transaction içinde uygulandı. Test DB'leri henüz güncellenmedi. Test/typecheck/lint/build/rollback kullanıcı talimatıyla çalıştırılmadı; migration başarısı ürün kabul testi değildir. Rollout DB134→API; üretim/canlı arama etkisi yok. Faz6/goal aktif.


### 2026-10-27 — Anket onay persistence ve atomik geçiş servisi

- SurveyConsentStore.issue runtime.resolve ile active outbound bağını kontrol eder; hedef/snapshot/kişi kimliği ve dil server kayıtlarından, start/resume amacı mevcut anket durumundan türetilir. Resume yalnız partial ve devam edilecek sorusu olan akış içindir. Aynı bağ/digest için süresi geçmemiş pending challenge tenant identity lock altında yeniden kullanılır; expiry uzatılmaz. İlk issue minimal audit ile kaydedilir.
- applyObservedDecision yalnız internal trusted-observer primitive'idir. Challenge tenant/binding kapsamında kilitlenir; current scope ile digest yeniden hazırlanır. Tam aynı resolved observation replay olarak döner; farklı olay/zaman/karar veya yarım granted sonuç reddedilir. İlk çözümde DB zamanı, expiry ve expected survey sürümü kontrol edilir.
- Granted start mevcut ensure primitive'iyle anketi açar; granted resume aynı version üzerinden resume uygular. Anket geçişi + challenge consume + minimal audit aynı çağıran transactiondadır. Denied anketi declined durumuna taşır (başlangıçta önce oturum oluşturur); unknown oturumu açmaz/ilerletmez. Replay anketi ikinci kez değiştirmez. Cevap/ses/transkript audit'e eklenmez.
- Bu servis kendi başına gözlemin gerçekliğini doğrulamaz ve HTTP route'a bağlı değildir. Çağıran runtime authentication/authorization ve güvenilir observer doğrulamasını sağlamalıdır; modelin kendi granted iddiası yeterli değildir. Aynı bağın aktifliği replay için de gereklidir. Onay endpointi/verified observer entegrasyonu ve pozitif survey issue/consume/replay/rollback/concurrency kabulü halen açık.
- Integration test koduna unbound session issue/decision ve accepted marketing görüşmesinde issue reddi eklendi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Migration134 kullanılır; yeni şema veya dış sağlayıcı çağrısı yok. Faz6/goal aktif.


### 2026-10-27 — Bağlı anket/onay/komut bütünleşik senaryosu

- Dispatch integration akışının sonunda ayrı kişi, survey izni, liste, iki sorulu kampanya, snapshot ve bütçeyle survey fixture eklendi. Hedef capture ve prepared→submitting→accepted geçişleri mevcut servislerden geçer; aktif dispatch state'i doğrudan SQL ile zorlanmaz. Mevcut marketing assertion verileri korunur. Fixture sonunda dispatch ended olayı kaydedilir; gerçek sağlayıcı kabulü değildir.
- Ortak accepted runtime fixture artık survey kampanyasında verifyBoundSurvey yolunu çalıştırır; marketing anket reddi kapsamı korunur. Survey yolu challenge issue/reuse (expiry uzamaması), başlangıç öncesi soru olmaması, unknown/denied dalları, granted başlangıç, exact replay ve farklı observation reddini kapsar.
- İki soru üzerinde answer→pause→resume onayı→answer→completed zinciri, soru sırası/null davranışı, eski onay replay'inin durumu geri almaması, aynı idempotency key farklı payload ve stale version reddi eklendi. Savepoint rollback sonrası cevap/sürüm ve receipt'in birlikte geri alınması, tekrarlarda yalnız iki cevap revisionı oluşması, consumed onayın immutable olması da test kodunda yer alır. Runtime/anket satırları mevcut dış fixture sentinel rollback'inde temizlenir.
- Bu senaryolar yazıldı, çalıştırılmadı; kullanıcı talimatıyla test/typecheck/lint/build yok. Typed/internal fixture gözlemleri güvenilir gerçek konuşma kanıtı değildir. Positive signed HTTP/scope isolation, gerçek paralel transaction yarışları, provider observer ve publication certification kabulü halen açık; Faz6/goal aktif. Şema veya canlı bağlantı değişmedi.


### 2026-10-27 — İmzalı anket onay isteği endpointi

- POST /api/internal/v1/call-sessions/:call_session_public_id/survey-consent-request route/controller/request service olarak bağlandı. Runtime imzası/surface auth ve ayrı runtime.survey.consent.request scope zorunlu; survey read/write bu yetkiyi sağlamaz. Hiçbir hesaba otomatik scope verilmez.
- Strict boş JSON; amaç/dil/target/snapshot/expected_version/karar seçimi istemciden kabul edilmez. Servis mevcut active runtime bağından start/resume challenge'ı türetir. Bekleyen aynı challenge expiry uzatılmadan döner; expire sonrası yeni challenge oluşabilir. Endpoint anketi başlatmaz/devam ettirmez ve karar kabul etmez. Bu işlem kalıcı idempotency receipt değildir.
- 1KiB body sınırı, ayrı sensitive rate limit ve no-store eklendi. Issue audit'i authenticated service-account public ID ve actor_type ile kaydedilir; internal fixture çağrıları system actor kullanır. OpenAPI challenge/süre/scope/reuse semantiğiyle güncellendi ve üretildi.
- Unit ve signed HTTP integration test kodu payload override/confirmed/decision reddi, read/write ile yetki kazanılmaması, scope allow/revoke, unbound session, body413, no-store ve reddedilen isteklerde challenge oluşmamasını kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Positive HTTP ve gerçek observer decision entegrasyonu halen açık; şema/sağlayıcı değişikliği yok. Faz6/goal aktif.


### 2026-10-27 — Outbound runtime bağından aranmama talebi

- recordRuntimeDnc mevcut native outbound session için yalnız legacy interaction/handoff/consent kaydı aramak yerine immutable runtime binding→dispatch→release bağından kişi/current-call identity eşleşmesini doğrular. Tenant/environment, contact identity revision, provider call ref, outbound phone ve snapshot ilişkileri kilit altında kontrol edilir.
- Native binding varsa yanlış kişi/identity/phone/provider/environment eşleşmesi legacy consent ilişkisine geri düşemez. Binding olmayan mevcut inbound/legacy sessionlarda eski association yolu korunur. Yeni outbound aramada customer_interaction henüz oluşmamışken DNC kaydı alınabilir.
- DNC bir suppression işlemi olduğu için accepted veya ended dispatch kabul edilir; call completed olsa da aynı doğrulanmış ilişkiyle gecikmiş talep işlenebilir. Bu izin tool/content erişimine taşınmaz. Contact current identity mutation kontrolü ve receipt replay davranışı mevcut DNC transactionında korunur; değişmiş numara sahibine eski görüşmeden yeni engel uygulanmaz.
- Bound runtime fixture'ına geçerli native ilişki, yanlış environment/identity/missing call, farklı kişi için legacy consent varken fallback reddi, provider ref değişimi ve call completed sonrası DNC ilişkisinin kabulü eklendi. Test kodu yazıldı; kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Positive signed-native DNC mutation/replay uçtan uca kabulü finalde halen açık.
- OpenAPI association ve gecikmiş suppression davranışı açıklaması güncellendi; doküman üretildi. Yeni migration veya gerçek provider çağrısı yok; Faz6/goal aktif.


### 2026-10-27 — Anket değişiklik/correction outbox olayları

- Mevcut outbox_events altyapısında caller.survey.changed.v1 topic'i eklendi. ensureSurveySession ilk start için, applySurveySessionCommand her sürüm geçişi için aynı transactionda olay üretir. Anahtar survey public ID + version; eşleşen tekrar aynı payload ile idempotenttir, farklı payload aynı sürümde conflict olur. Yeni event tablosu veya ikinci queue oluşturulmadı.
- Strict payload yalnız survey/target/snapshot public ID, version, command kind, durum ve geçersizleşen revision sıralarını taşır. Cevap/metin/telefon/transkript event içine kopyalanmaz. Correction revise olarak işaretlenir; sonraki rapor/CRM tüketicisi tenant kapsamındaki authoritative geçmişi okuyup survey/version ile dedupe etmelidir. Event tek başına lead/arama/CRM yetkisi değildir.
- Genel runtime outbox/inbox publishing validator ve servisinde bu exact topic server-owned olarak ayrıldı; runtime.jobs.write ile sahte correction event/receipt oluşturulamaz. OpenAPI bu kısıtı açıklar ve yeniden üretildi. Existing topic'ler etkilenmez.
- Test kodu start/answer/revise olay sırası, iptal edilmiş transactionda event olmaması, replay'lerde beş survey geçişi için beş olay, payload privacy ve generic signed event yayınında reserved topic reddi için genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı.
- Domain event üretimi bağlandı; correction tüketicisinin CRM sonucu güncellemesi, dedupe lead/task davranışı, retry/dead-letter/retention ve tam uçtan uca kabulü halen açık. Yeni migration/dış çağrı yok; Faz6/goal aktif.


### 2026-10-27 — Olay sürümüne göre anket sonucu okuma (migration135)

- readSurveyChange internal consumer/report primitive'i tenant/topic/public event ID ile kayıtlı olayı okur; event key, survey/target/snapshot ve sürüm bağını kontrol eder. Güncel answer disposition yerine olay sürümünde geçerli revision'lar seçilir; sonradan superseded olmuş cevap eski olayda kaybolmaz. Koşullu akış aynı sabit soru tanımı üzerinden yeniden hesaplanır.
- Çıktı event/current version, stale ve identity_current bayraklarıyla yapılandırılmış geçmiş sonucu taşır. Stale olay yeni CRM sonucunu ezmemeli; identity_current aksiyon yetkisi değildir. Servis public runtime endpointi değildir; çağıran cevap okuma yetkisini sağlamalı, içerik log/cache/audit/outbox'a kopyalanmamalıdır. Transaction içinde dış çağrı yapılmaz.
- Tek SQL lateral sorgusu en fazla100 sabit soru için son recorded_version<=event.version revision'ını alır, geçersizleşme sınırını kontrol eder. Migration135 tenant/session/question/recorded_version DESC indeksini ekler. Sınırsız cevap geçmişini uygulamaya yüklemez; nihai EXPLAIN/load doğrulaması henüz yapılmadı.
- Integration test kodu correction sonrası önceki olayın eski cevabı/completed durumunu, yeni olayın skipped/partial sonucunu, start olayında boş cevapları ve yanlış tenant/eksik event reddini kapsar. Kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı. Consumer dispatch/dedupe ve CRM görev düzeltme bağlantısı halen açık.
- Migration135 yalnız loopback haisly_caller kimliği doğrulanıp pg_dump yedeği alındıktan sonra atomik uygulandı. Test DB'lerine henüz uygulanmadı. Rollback yalnız yardımcı indeksi kaldırır; üretim uygulanmadı. Faz6/goal aktif.


### 2026-10-27 — Düşük memnuniyet aksiyon kuralı değerlendirmesi

- Mevcut follow_up_tasks servisi incelendi; campaign rule version/ekip/tekil aksiyon bağlantısı henüz olmadığı için event'i doğrudan legacy createTask'a bağlayıp mükerrer iş üretme riski alınmadı. Low-satisfaction rule modeli ve saf değerlendirme servisi eklendi.
- Strict kural işaretli soru key, nullable/default threshold, team public UUID, automatic/review modu ve1–30iş günü hedef süresi taşır (varsayılan1). Derleme aynı survey definition içindeki scale sorusunu zorunlu kılar; varsayılan eşikler1–5≤2,1–10≤4,NPS≤6; özel eşik ölçek sınırları içinde tamsayı olmalıdır. Ekip UUID biçimi ownership/availability kanıtı değildir; yayın/atama servisinde çözülecek.
- Değerlendirme eski event/version, değişmiş/arşivlenmiş kimlik, declined anket, henüz sorulmamış veya skipped soru için yeni görev üretme kararı vermez. Geçerli düşük skor partial ankette de destek ihtiyacı olarak değerlendirilebilir. Above-threshold düzeltme ayrı sonuçtur; consumer mevcut aksiyonu güncellemeli, eski görevi kopyalamamalıdır. Çıktı automatic_task veya review kararı ve minimal score/revision/team/deadline parametreleridir; bu fonksiyon görev/lead/CRM yazmaz.
- Unit test kodu üç ölçek, kapsayıcı sınırlar, özel eşik, review modu, iş günü süresi, stale/identity/declined/skip/unanswered ve bozuk numeric cevap reddini kapsar. Test/typecheck/lint/build kullanıcı talimatıyla çalıştırılmadı. Campaign snapshot rule persistence, ekip yönetimi/round-robin, tekil aksiyon rezervasyonu, correction consumer ve UI halen açık; yeni migration/dış çağrı yok. Faz4/Faz6/Faz9/goal tamamlandı sayılmadı.


### 2026-10-27 — Tenant ekipleri ve kalıcı round-robin (migration136)

- caller_teams/caller_team_members eklendi. Aktif ekip adı tenant içinde case-insensitive tekil; ekip/member kimliği immutable; ekip config version ve archive bilgisi ayrı, assignment_cursor kalıcı sıra bookmark'ıdır. Üye silinmesi bookmark'ı sıfırlamaz. Üyelik team+tenant ve tenant_memberships(user,tenant) FK'leriyle sınırlandırılır; enable/join aktif tenant membership, aktif user ve arşivlenmemiş ekip ister.
- allocateTeamMember tenant identity lock ve team FOR UPDATE altında eligible üyeleri sabit member ID sırasıyla seçip sona gelince başa döner. Removed/unavailable, disabled/deleted membership veya user elenir. En fazla iki bounded seçim sorgusu vardır. Seçim parent membership/user share lock'uyla tutulur; cursor sadece seçilen üyeye ilerler. Ekip config version atama nedeniyle değişmez; ayrı assignment_updated_at kullanılır. Uygun kişi yoksa assignee=null (ekip kuyruğu) döner.
- Primitive internaldır: çağıran önce tekil aksiyon kaydını ayırmalı, cursor ve task aynı transactionda commit olmalı; replay cursor ilerletmemelidir. Ekip API/UI, üyelik/rol yetkileri, campaign rule binding, atama audit/notification ve boş ekip yönetici bildirimi henüz bağlanmadı. DB aktif üyelik kontrolü tek başına task yetkisi veya kampanya yayın izni değildir.
- İzole integration test kodu üç üyede round-robin/wrap, cursor rollback, müsaitlik/tenant membership/user durumu, boş kuyruk, tenant dışı erişim, archived ekip ve disabled üyeyi tekrar etkinleştirme reddi için eklendi. Test/typecheck/lint/build/rollback kullanıcı talimatıyla çalıştırılmadı; paralel task atama kabulü halen açık.
- Migration136 loopback haisly_caller kimliği kontrol edilip pg_dump yedeği alındıktan sonra transaction içinde uygulandı; test DB'lerine uygulanmadı. Dolu ekiplerde rollback reddedilir. Rollout DB136→API; üretim etkisi yok. Faz4/Faz9 ve goal aktif.
