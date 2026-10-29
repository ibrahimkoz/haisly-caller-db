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

### 2026-10-27 — Tenant ekip yönetimi API ilk dilimi

- `GET/POST /api/v1/caller-teams` ve `GET/PATCH /api/v1/caller-teams/:public_id` eklendi. Mevcut `users.manage` yetkisi, sunucudan tenant kapsamı, public UUID ve en fazla 100 kayıtlık cursor sayfalama kullanılır.
- Oluşturma/ad değiştirme/arşivleme/geri açma aynı transaction içinde audit ve idempotency receipt üretir; güncellemede If-Match gerekir. Arşivleme geçmişi silmez; mevcut allocator arşivli ekipleri reddeder. Atama cursoru dışarı verilmez veya istemciden kabul edilmez.
- OpenAPI üretildi. Şema sınırları ve mass-assignment reddi için test kodu eklendi; kullanıcı talimatıyla hiçbir test/typecheck/lint/build çalıştırılmadı. HTTP yetki/tenant ayrımı, replay/version yarışları ve arşivleme entegrasyon doğrulamaları hâlâ açık; mevcut unit testleri bunların kanıtı değildir.
- Yeni DB migration/dependency yok. Üye yönetimi, görev rol uygunluğu, client ekranı, kampanya yayın kuralları, görev oluşturma ve boş ekip bildirimi henüz açık. Tenant/public_id sayfalama sorgusu için final EXPLAIN/index değerlendirmesi yapılacak.
- ElevenLabs/SIP/test hattı henüz hazır değil; kullanıcının açık yanıtıyla canlı bağlantı olmadan geliştirme sürdürülüyor. Gerçek sağlayıcı kabulü tamamlanmış sayılmaz.

### 2026-10-27 — Ekip üyelik API ve HTTP regresyon senaryoları

- Ekip üyeleri cursor ile listelenebilir; PUT mevcut tenantın aktif kullanıcısını ekler/geri alır/müsaitliğini değiştirir, DELETE üyeliği geçmişi koruyarak kaldırır. Tüm işlemler `users.manage` ister; mutasyonlar ekip If-Match sürümü, actor-scoped idempotency, audit ve tenant kilidiyle korunur.
- Üye çıkarma arşivli ekipte ve pasif kullanıcıda da yapılabilir. Geri ekleme aynı üyelik ID'sini korur, atama sırasını sıfırlamaz. Mevcut görevler yeniden atanmaz. Listede aktif tenant kullanıcısı bilgisi görev rol uygunluğu anlamına gelmez; bu kontrol hâlâ görev atama entegrasyonunda tamamlanacak.
- OpenAPI güncellendi/üretildi; üyelik alanlarının strict validation testleri ve HTTP oluşturma/eşzamanlı replay/stale sürüm/tenant ayrımı/arşivleme/çıkarma/geri alma entegrasyon senaryosu yazıldı. Testler çalıştırılmadı; test DB 136 dahil migrasyonlarla finalde hazırlanmalı. HTTP rol reddi ve inactive-user senaryoları ayrıca genişletilecek.
- Client ekip ekranı, rol uygunluğu, kampanya kuralları, task reservation ve bildirimler açık. Yeni migration veya paket yok.

### 2026-10-27 — Client ekip yönetimi ekranı

- `/app/teams` lazy route, sayfa başlığı ve TR/EN menü eklendi; rota ve ekran `users.manage` ile korunur. Tenant değişiminde çalışma alanı yeniden mount olur.
- Merkezi RTK Query sözleşmeleri ekip oluşturma/listeleme/güncelleme ve üye listeleme/PUT/DELETE API'lerine bağlandı. Mutation sonrası ekip ve audit cache invalidation yapılır. Üyelik listesi kullanıcı değişikliklerinde UserRole tag üzerinden yenilenir.
- Ekip adı ve arşiv durumu RHF/Zod formuyla yönetilir; aktif tenant kullanıcı seçimi mevcut kullanıcı API'sini kullanır. Üye çıkarma ve müsaitlik işlemleri ekip sürümüyle gönderilir. İç ID/cursor atama bilgisi gösterilmez.
- Belirsiz mutation sonucu aynı anahtar ve payload ile tekrar edilir; form değerleri ve ekran içi ekip geçişleri kilitlenir. Üye paneli ana liste refetch hatasında kaybolmaz. Sayfadan tamamen ayrılma/reload sonrası pending isteğin geri yüklenmesi sağlanmıyor; kullanıcıya ekranı açık tutma metni gösterilir.
- Loading/empty/error/permission durumları, cursor ileri/ilk sayfa kontrolleri ve üyelik başarı geri bildirimi eklendi. Editör için belirsiz sonuç/replay ve arşivleme sürümü test kodu yazıldı.
- Kullanıcı talimatıyla test/typecheck/lint/build/browser çalıştırılmadı. Görsel, erişilebilirlik, route smoke, gerçek API uçtan uca ve üyelik bileşeni senaryoları final doğrulamada açık. Kampanya rule/task entegrasyonu ve görev rol uygunluğu henüz tamamlanmadı.

### 2026-10-27 — Kampanya anket takip kurallarının kalıcı tanımı (137)

- Migration137 tenant ve kampanya sürümü kapsamında düşük memnuniyet kurallarını saklar; ekip FK'sı aynı tenantı zorunlu kılar. Bir soru için tek kural, threshold/mode/iş günü sınırları ve aktif ekip/survey draft yazma guardları vardır. Rollback dolu tabloda reddeder.
- Kampanya create/update `survey_follow_up_rules` kabul eder. Omission mevcut kuralları korur, [] temizler. Soru düzenlemelerinden sonra eski kurallar da tekrar doğrulanır; geçersiz soru tipi/eşik veya arşivli ekip kaydı durdurur. Marketing'e geçişte kuralların açıkça temizlenmesi gerekir.
- Kurallar draft read, immutable snapshot, definition hash ve clone içine bağlandı. Önceki snapshotlarda alan yoksa boş kural kabul edilir. Kurallar boşken önceki definition hash şekli korunur. Preflight arşivlenmiş/eksik ekipleri engeller. Kurallar snapshot içinde donduğu için sonraki taslak değişikliği geçmiş görüşmenin kuralını değiştirmez.
- OpenAPI üretildi. Transaction tabanlı preserve/clear, soru/eşik/geçersiz ekip/type/archived davranışı testi yazıldı; çalıştırılmadı. Yerel haisly_caller yedeklenip 137 uygulandı; üretime dokunulmadı. Test DB migrasyonları ve test/typecheck/lint/build finalde.
- Bu dilim görev üretmez. Marketing ilgi/belirsiz sonuç kuralları, client kural editörü, çalışan role uygunluğu, action reservation/consumer/task dedupe, hedef iş günü hesabı ve yönetici bildirimi açık.

### 2026-10-27 — Client kampanya düşük memnuniyet kural editörü

- Kampanya formuna scale sorusu + aktif ekip seçimi, varsayılan/özel eşik, automatic/review modu, 1–30 iş günü ve kural kaldırma eklendi. Ekipler cursor sayfalanır; mevcut users.manage yetkisi olmadan ekip listesi çağrılmaz. Bu izin olmadan yeni ekip seçilemez, mevcut kurallar korunarak diğer alanlar düzenlenebilir.
- Formdan API'ye kurallar açıkça taşınır; mevcut kampanyayı açarken kurallar kaybolmaz. Soru silme/tip/ölçek değişiminde ve marketing'e geçişte geçersiz kurallar client şemasında reddedilir. Kurallar sessizce temizlenmez. Backend aynı kontrolleri ayrıca uygular.
- Eşik varsayılanları açıklanır; rule başına soru uyarısı, arşivli ekip etiketi, API preflight ekip hatası TR/EN karşılığı ve form-level hata vardır. Rule paneli kampanya kilidine uyar. Otomatik task işleme henüz olmadığı ekran metninde belirtilir.
- Model validasyon ve kural bileşeni invalid/remove/read-only testleri yazıldı; kullanıcı talimatıyla çalıştırılmadı. Browser/görsel/erişilebilirlik ve gerçek API entegrasyon kontrolleri finalde açık.
- Ekip seçeneklerini kampanya editörlerine özel dar bir read yetkisiyle sunma, marketing kuralları ve görev üretimi entegrasyonu sonraki dilimlerde açık. DB/API bu dilimde değişmedi.

### 2026-10-27 — Otomatik ekip atamasında görev yetkisi

- Round-robin adayları artık yalnız aktif/müsait üyelikle seçilmez: aynı tenantta aktif owner rolü veya aktif rol üzerinden `caller.tasks.assigned` gerekir. `caller.tasks.assign` yönetim yetkisi tek başına çalışan atama uygunluğu sayılmaz.
- Seçim sonrası rol/üyelik/izin kayıtları FOR SHARE ile tekrar okunup aynı transaction bitene kadar tutulur. Candidate EXISTS ile görev kaydı arasındaki yetki kaldırılması rollback/retry conflict üretir; cursor yetki kanıtı alınmadan ilerlemez. Üyelik ve kullanıcı aktiflik kilitleri korunur.
- Entegrasyon testine yetkisiz üyelerin boş ekip kuyruğuna düşmesi, role-permission kaldırma ve user-role revoke sonrası aday eleme senaryoları eklendi; testler çalıştırılmadı. Gerçek iki bağlantılı revoke yarışı ve lock-order doğrulaması finalde açık.
- İnceleme mevcut FollowUpTaskService'in hâlâ legacy tenant.read/tenant.manage kullandığını gösterdi. Atanmış görev görünürlüğü ve çalışan status/snooze yetkisi bir sonraki güvenlik diliminde uyarlanmalı; bu iş tamamlanmadan otomatik görev consumer canlı akışa bağlanmış sayılmaz. Görev üretimi/aksiyon dedupe ve bildirimler hâlâ açık.
- Yeni DB migration/dependency yok; client ekranındaki müsaitlik göstergesi görev rol uygunluğu garantisi değildir.

### 2026-10-27 — Atanmış görev API erişimi ve client izinleri

- FollowUpTaskService list/detail/status/snooze artık tenant.read/tenant.manage yerine caller.tasks.assign (tenant geneli) veya caller.tasks.assigned (yalnız auth.userId'ye atanmış) kullanır. Görev oluşturma caller.tasks.assign ister. Atanmamış/başkasının görevi çalışan detay ve mutation isteklerinde 404 verir; liste sorgusu aynı filtreyi SQL'de uygular.
- Status/snooze transaction'a alındı: tenant identity kilidi, scope filtreli row lock, güncelleme ve audit birlikte. Aynı durum/snooze zamanının tekrarı completion timestamp'ini değiştirmez veya ikinci audit üretmez. Bu tam If-Match/idempotency geçmiş sözleşmesinin yerine geçmez; eşzamanlı farklı komut politikası ayrıca geliştirilecek.
- Client görev menü/route korumaları yeni caller izinleriyle eşlendi; create route ve düğme çalışanlara kapalı. Legacy büyük görev sayfasında yalnız ilgili izin entegrasyonu değiştirildi; modülerleştirme ve scoped lead/call özet erişimi açık.
- HTTP entegrasyon senaryosu assigned-only liste, own detail/status, unassigned detail/status reddi ve permission revoke reddi için yazıldı; testler çalıştırılmadı. Gerçek tenant/rol/yeniden atama yarışları, create/snooze negatifleri ve UI izin regresyonları final doğrulamada genişletilecek.
- OpenAPI üretildi. Yeni migration yok. Otomatik action/task consumer, manuel create transaction/audit/idempotency ve atanacak kişi yetkisi kontrolleri henüz açık; otomatik görev üretimi tamamlanmış sayılmaz.

### 2026-10-27 — Tekil anket aksiyonu ve düzeltme defteri (138)

- Migration138 `caller_survey_follow_up_actions` ve revision tablosunu ekler. Tekillik tenant+target+snapshot+question; survey/target/snapshot kapsamı composite FK ile korunur. Task bağlantısı aynı tenantta tekildir ve bir kez bağlandıktan sonra başka task ile değiştirilemez. Karar sürümü geriye gidemez, aynı sürümde farklı karar yazılamaz; revision UPDATE reddedilir. Retention DELETE yolu ayrıca tasarlanacak.
- İç `reconcileSurveyFollowUp` gerçek tenant outbox olayını ve frozen snapshot kuralını okur; modelden sonuç almaz. Stale/identity-unavailable olaylar işlem yapmaz. İlk düşük skor/review tekil aksiyon açar; sonraki düzeltmeler aynı aksiyonu ve geçmiş kararları korur. Task linkine dokunmaz. Ekip arşivli olsa bile karar kanıtı tutulabilir; gerçek görev atamasında uygunluk ayrıca kontrol edilecek.
- Başlangıçta eşik karşılamayan/yanıtsız sorular için boş aksiyon oluşturulmaz. Aynı event replay'i history veya ikinci action yazmaz. Consumer'ın transaction ve tenant kilidi içinde çalışması gerekir; henüz worker dispatch'e bağlanmadı.
- 138 yalnız yerel haisly_caller yedeklenerek uygulandı. Rollback dolu action tablosunda reddeder. Testler çalıştırılmadı; mevcut survey fixture'a stale/no-rule/wrong-tenant senaryoları eklendi. Pozitif düşük skor→action, düzeltme/replay, iki bağlantı yarışı ve task FK guard testleri henüz açık.
- Henüz görev üretilmez. Action→task materialization, iş günü hedefi, round-robin bağlama, review onayı, boş ekip bildirimi ve event consumer scheduling sonraki bağımlılıklardır. Manuel task create güvenlik/idempotency açıkları da korunur.

### 2026-10-27 — Anket aksiyonundan takip görevi oluşturma

- İç `materializeSurveyTask` action row lock + tenant identity kilidi altında survey/snapshot/current identity ve en son olay sürümünü kontrol eder; snapshot kuralını güncel yapılandırılmış cevapla yeniden değerlendirir. Yalnız automatic_task kararı görev oluşturur; review kararları otomatik geçilmez.
- Round-robin yetki kontrollü allocator, follow_up_tasks INSERT, aksiyon task bağlantısı ve sistem audit aynı transaction içindedir. Kimse uygun değilse assigned_user_id null ve team_public_id metadata ile ekip kuyruğu görevi açılır. Replay mevcut görevi döndürür ve cursor ilerletmez.
- Cevap düzeltmesinden sonra aynı task'ın caller_follow_up metadatasına güncel survey sürümü/kararı yazılır. İnsan tarafından tamamlanmış işi silmez/yeniden açmaz; üst eşik için otomatik iptal yapılmaz. Düzeltme bildirim/review kapanış deneyimi henüz açık.
- Hedef tarih ilk action.created_at esaslı, frozen campaign timezone'da Mon–Fri iş günü + aynı yerel saat hesabıyla üretilir. V1 tatil takvimi yoktur; DST PostgreSQL saat dilimi kurallarıyla çözülür. 1–30 gün ve IANA zone varlığı kontrol edilir. Bu görev hedef tarihidir, arama saati izni değildir.
- `processSurveyFollowUpEvent` reconciliation ve en fazla 100 kuralın materialization'ını aynı worker transaction'ında birleştirir. Henüz worker scheduling/ack ve notification outbox delivery bağlı değildir; gerçek otomatik çalışan sistem olarak kabul edilmez.
- Mevcut isolated campaign fixture'a düşük skor→tek task, empty team queue, rollback, replay, correction→aynı task, eski sürüm bekleme, wrong tenant ve hafta sonu due-date test kodu eklendi. Çalıştırılmadı; test DB138 dahil migration ve final doğrulama gerekiyor. Yeni migration/dependency yok.
- Açık: review onayı, bildirim ve boş ekip yönetici uyarısı, worker tüketimi, assigned kullanıcı pozitif materialization/concurrency testleri, manuel task create korumaları, marketing lead/task kuralları.


### 2026-10-27 — Anket aksiyonları için worker tüketimi

- POST /api/internal/v1/survey-actions/drain imzalı runtime auth ve ayrı runtime.survey.actions.process scope ile tek olay işler. Tenant/environment auth üzerinden gelir; yalnız aynı environment provider hesabının accepted/ended dispatch kaydına bağlı survey olayları seçilir. 1 KiB body sınırı, rate limit, no-store ve OpenAPI eklendi.
- Migration139 tüketiciye özel teslim kaydı tutar; ortak outbox transport status değiştirilmez. Görev/action/cursor ve succeeded receipt aynı transaction'da commit edilir. Hata halinde savepoint domain değişikliklerini geri alır; 10/20/40/80 saniye retry sonrası beşinci hata dead-letter olur. Ham hata, cevap veya PII kaydedilmez. Tenant identity kilidi meşgulse işlem atlanır.
- Worker yalnız CALLER_WORKER_ENABLED=true ve CALLER_SURVEY_ACTIONS_ENABLED=true birlikte verilirse bu tüketiciyi çalıştırır. Yeni anahtar varsayılan false; hiçbir ortamda etkinleştirilmedi veya scope otomatik verilmedi. Worker DB'ye bağlanmaz, mevcut imzalı API istemcisini kullanır. İşlenen olay sonrası 1 saniye, boş/busy/hata sonrası 10 saniye bekler. Aggregate metrics ve 30 saniyelik readiness eklendi.
- 139 yerel haisly_caller kimliği doğrulanıp pg_dump yedeği alındıktan sonra uygulandı. Rollback dolu receipt tablosunu silmeyi reddeder. Bu migration uygulaması test sonucu değildir. Monitor sonuçları/abort/transport hatası ve kapalı varsayılan testleri yazıldı; kullanıcı kararı gereği çalıştırılmadı. OpenAPI yeniden üretildi.
- Açık doğrulamalar: gerçek transaction retry/dead-letter/replay, iki bağlantılı kilit yarışı, tenant/environment HTTP izolasyonu ve final toplu testler. Geçersiz survey bağlantılı olaylar join nedeniyle seçilmez; veri bütünlüğü alarmı ve dead-letter inceleme/yeniden kuyruğa alma yönetimi sonraki işletim dilimidir. Bildirimler, review onayı, marketing kuralları ve canlı provider kabulü henüz tamamlanmadı.


### 2026-10-27 — Kampanya editörleri için aktif ekip seçenekleri

- GET /api/v1/caller-teams/options yalnız caller.campaigns.edit yetkisiyle tenantın aktif ekiplerinin public_id/name alanlarını sayfalı döndürür. users.manage, üye bilgisi, versiyon veya assignment cursor verilmez. Strict query, en fazla 100 kayıt ve no-store davranışı eklendi; OpenAPI üretildi.
- Kampanya takip kuralı editörü yeni uç noktayı kullanır. Ekip/üye yönetimi uç noktaları users.manage gerektirmeye devam eder. Seçim anından sonra arşivlenen ekip, mevcut campaign save doğrulamasıyla reddedilir. Ekip bulunamayan sayfa için boş durum mesajı eklendi; mevcut kurallar korunur.
- HTTP testine minimal projection, yetkisiz erişim, başka tenant, arşivli ekip, limit sınırı, yalnız campaign-edit rolüyle seçenek okuma/üye yönetiminin reddi ve yetki kaldırma senaryoları eklendi. Client dar ekip projection gösterimi testi eklendi. Test/typecheck/build çalıştırılmadı; final toplu doğrulama bekleniyor.
- DB şema değişikliği yok. Önceki notlarda açık kalan kampanya editörü ekip seçimi yetki bağımlılığı kaynak kod düzeyinde kapatıldı; canlı bağlantı ve tüm faz kabulü tamamlandı sayılmadı.


### 2026-10-27 — Otomatik anket görevlerinin uygulama içi bildirimi

- Yeni survey task oluşturma dalı mevcut NotificationInboxWriter üzerinden follow_up bildirimi yazar. Görev atandıysa ilgili aktif kullanıcıya; ekip kuyruğuna düştüyse aktif tenant üyeliği olan owner veya caller.tasks.assign yetkili yöneticilere gider. Rol adı üzerinden admin varsayımı yapılmaz. Alıcılar 500'lük cursor sayfalarıyla okunur.
- Görev, aksiyon bağlantısı, bildirim ve audit aynı transaction'dadır; görev replay'i yeni bildirim üretmez. Audit inbox_notification_count içerir; sıfır alıcı gözlenebilir. Müşteri adı/telefonu, cevap veya skor bildirimde yoktur; yalnız görev public ID ve görev ekranı bağlantısı bulunur. Dil alıcının locale'ine göre TR/EN seçilir.
- Writer'a açık inbox_only seçeneği eklendi; mevcut çağıranların varsayılan push davranışı korunur. Bu dilim dış push/e-posta/SMS göndermez. Eski push kanalının follow_up izin eşlemesi ve gönderim anı yetki kontrolü ayrıca ele alınmalıdır; yeni task bildirimleri bu kanala kuyruğa alınmaz.
- Mevcut transaction fixture'a task yöneticisi alıcısı, link/projection, görevle birlikte rollback ve replay/correction sonrası tek bildirim kontrolleri eklendi. Testler çalıştırılmadı. Assigned-recipient, farklı tenant/inaktif üye/çok sayfa kapsamı ve browser gelen kutusu doğrulaması final kabulde açık.
- DB migration veya client UI değişikliği yok; mevcut gelen kutusu ve follow_up linki kullanılır. Review onayı, görev yeniden atama deneyimi, düzeltme bildirimleri ve kanal gönderim güvenliği kalan işlerdir.


### 2026-10-27 — Kampanya görevi manuel atama API temeli

- Migration140 follow_up_tasks.version alanı ve her UPDATE'te DB tarafından artan sürüm ekler. Liste/detail DTO ve OpenAPI sürümü döndürür; client modeli güncellendi. Status, snooze ve survey correction gibi diğer yazımlar da sürümü artırır; atama eski ekran sürümüne karşı korunur. Eski status/snooze endpointleri henüz If-Match zorunlu kılmıyor.
- POST /api/v1/follow-up-tasks/:public_id/assign caller.tasks.assign, Idempotency-Key, If-Match ve strict public assignee UUID gerektirir. Tenant kilidi + task row lock altında terminal görevler reddedilir; survey action ledger'ın orijinal takımında aktif/müsait üyelik ve assigned-task rol yetkisi kilitlenerek doğrulanır. Metadata üzerinden takım seçilmez. Bu dilim survey tasklarını kapsar; marketing/manual task atama bağlamları henüz yoktur.
- Atama, yeni çalışanın inbox bildirimi, audit ve mutation receipt tek transaction'dadır. Aynı key replay ikinci bildirim oluşturmaz; aynı kullanıcıya yeni istek task sürümünü değiştirmez. Manuel atama round-robin cursorunu değiştirmez. 1 KiB request sınırı ve no-store uygulanır.
- Yerel DB kimliği doğrulanıp yedek alındıktan sonra140 uygulandı; rollback ilerlemiş sürümleri silmeyi reddeder. OpenAPI yeniden üretildi. Strict assignment schema ve survey correction sürüm artışı test kodu eklendi; testler çalıştırılmadı.
- Kalan: uygun çalışanları seçme endpointi/UI, pozitif HTTP atama/replay/stale/concurrency ve yetki izolasyonu testleri, görev oluşturma/status/snooze tam mutation sözleşmesi. Bu dilim uçtan uca atama deneyimi tamamlandı anlamına gelmez.


### 2026-10-27 — Görev detayından uygun çalışana atama

- GET /api/v1/follow-up-tasks/:public_id/assignees caller.tasks.assign yetkisiyle yalnız görev aksiyonunun takımındaki aktif/müsait/assigned-task yetkili çalışanları listeler. Sadece UUID/ad döner; cursor sayfalama (varsayılan50/max100), görev sürümü ve assignable alanı vardır. Terminal/henüz desteklenmeyen legacy görevler assignable=false döndürür. Liste canlıdır; POST atama uygunluğu yeniden kilit altında doğrular.
- Görev detayına yöneticiye özel atama formu bağlandı. Merkezi RTK API, mevcut form/button stilleri, TR/EN, yükleme/boş/hata/başarı, sayfalama ve yenileme kullanılır. İstek sürümü/key/assignee ilk gönderimde dondurulur; belirsiz sonuçta aynı payload yeniden gönderilir ve form seçimi kilitlenir. Kesin409 vb. hata listeyi yeniler.
- Görev drawer'ının kapatma ve başka görev açma işlemleri pending/uncertain süresince engellenir. Tam sayfa yenileme/sidebar navigasyonu sonrası pending request kalıcılığı henüz sağlanmadı; kullanıcıya formu açık tutması söylenir. Bu sınır final UX kabulünde açık kalır.
- Client testleri aynı-key retry/donmuş sürüm ve definitive-conflict refresh için yazıldı. HTTP fixture'a assigned-only kullanıcının seçenek okumasının reddi ve unauthenticated kontrolü eklendi. Çalıştırılmadı; pozitif görev/ekip HTTP testi, pagination/race ve browser/accessibility final doğrulaması açık. OpenAPI üretildi. DB şema değişmedi.


### 2026-10-27 — Bekleyen görev atamasını sayfa yenilemede koruma

- Client pending assignment kaydı sessionStorage'da tenant UUID + actor UUID + task UUID ile ayrılır. Gönderimden önce public task/assignee UUID, reviewed version ve idempotency key strict Zod doğrulamasıyla saklanır; token, isim, telefon veya anket cevabı tutulmaz.
- Aynı sekmede sayfa yenileme/sidebar dönüşü formu yeniden açınca kaydı geri yükler; otomatik replay yapmaz. Kullanıcı aynı isteği tekrar deneyerek receipt sonucunu alır. Başarı veya kesin HTTP hatasında eşleşen key silinir; bekleyen farklı istek üzerine yazılmaz. Scope değişiminde React component key tenant/actor/task içerdiği için önceki kullanıcı isteği taşınmaz.
- Depolama erişimi/yazımı veya kayıt doğrulaması başarısızsa yeni atama gönderilmez. Bozuk kayıt sessizce silinmez; tarayıcı depolama sorununu giderip yeniden açma uyarısı verilir. Sekme kapatma veya tarayıcının sessionStorage'ı temizlemesi kalıcılık kapsamı dışındadır; görev sürümü server'da ayrıca korunur.
- Exact replay/remount, actor/tenant/task izolasyonu, farklı payload üzerine yazma reddi, yanlış key ile silmeme ve bozuk veri koruma test kodu eklendi. Çalıştırılmadı. Önceki nottaki aynı-sekme reload/sidebar pending state eksikliği kaynak kodda kapandı; gerçek browser ve toplu test doğrulaması hâlâ açık.
- API/DB kontratı değişmedi; mevcut mutation receipt mekanizması kullanılır.


### 2026-10-27 — Anket aksiyonu onay/ret API ve geçmişi

- Migration141 caller_survey_action_reviews tablosu action+survey_version başına tek approved/rejected karar, reviewer üyelik FK, 10–500 karakter gerekçe ve tarih tutar. UPDATE yasaktır; INSERT güncel review aksiyonu, aynı survey sürümü ve henüz görev oluşmamış olmasını kilit altında doğrular. Ret aynı sürümde sonradan onaya çevrilmez; yeni cevap sürümü yeni değerlendirme gerektirir. Gerekçe audit metadatasına kopyalanmaz.
- POST /api/v1/survey-actions/:public_id/review caller.tasks.assign, Idempotency-Key, If-Match (survey version), strict decision/reason ister. Tenant/action/survey/current identity kontrolü yapılır; arşivli veya kimliği değişmiş kişi ve eski cevap reddedilir. Approved kararı + yeniden değerlendirilen frozen kural + görev/atama/bildirim/audit/receipt aynı transaction'da oluşur. Task oluşturulamıyorsa onay da kaydedilmez. Rejected karar görev oluşturmaz.
- Materializer review modunda sadece aynı sürüme ait kalıcı approved kaydı varsa görev açar. Otomatik mod korunur; worker replay veya manuel tekrar ikinci görev üretmez. Mevcut göreve düzeltme politikası değişmedi.
-141 yerel DB kimliği doğrulanıp pg_dump yedeğinden sonra uygulandı; dolu review geçmişi rollback ile silinmez. OpenAPI üretildi. Test fixture otomatik/onaylı varyantlara genişletildi; onaysız/retli görev açılmaması, onaylı görev ve mevcut rollback/replay/correction testleri yazıldı. Strict reason/decision testleri eklendi; çalıştırılmadı.
- Kalan: kanıt içeren review list/detail API, onay kuyruğu UI ve gerekçe formu, HTTP approval replay/tenant/role/stale/concurrency testleri. Faz9 kabulü henüz tamamlanmadı. Bildirim tesliminde yeniden deneme ve isteğe bağlı kanal tercihlerinin tam entegrasyonu ayrıca açık.


### 2026-10-27 — Güncel anket inceleme kuyruğu ve kanıt API'si

- GET /api/v1/survey-actions/reviews caller.tasks.assign kapsamında cursor sayfalı pending kuyruğu döndürür. Sadece review kararlı, görev bağlantısı olmayan, aynı sürümde kararı bulunmayan, güncel survey ve kişi kimliğine bağlı aksiyonlar görünür. Tenant tüm ilişkilerde sınırlandırılır; 50 varsayılan/100 üst limit. Arşivli ekipler ret kararı verilebilsin diye işaretli olarak görünür.
- GET /api/v1/survey-actions/:public_id/review tenant identity kilidi altında güncel outbox evidence ve frozen snapshot kuralını yeniden değerlendirir. Soru/ölçek/skor/eşik/cevap sequence, snapshot UUID, kampanya adı, ekip ve iş günü hedefi döner. Diğer cevaplar, kişi adı/telefonu/transcript dönmez. Eski veya işlenmiş inceleme404, tutarsız kanıt409 olur; POST karar sırasında uygunluk tekrar doğrulanır.
- Her iki route success/error no-store kullanır. OpenAPI list/detail sözleşmeleri eklendi ve üretildi. Strict pagination, owner empty queue/no-store ve assigned-only/unauthenticated erişim reddi test kodu eklendi; çalıştırılmadı.
- DB değişikliği yok. Pozitif kanıt projection/tenant/identity düzeltme, pagination ve review race HTTP testleri ile UI onay kuyruğu sonraki işlerdir. Liste canlı görünüm; sayfalama arası kayıt değişimleri snapshot garantisi taşımaz.


### 2026-10-27 — Aksiyon inceleme kuyruğu arayüzü

- /app/survey-reviews route, menü ve sayfa başlığı caller.tasks.assign yetkisiyle eklendi. Tenant/actor değişiminde sayfa state'i sıfırlanır. Cursor sayfalı kuyrukta yükleme, boş sayfa, hata ve yenileme; seçili aksiyonda kanıt yükleme/retry bulunur. Merkezi RTK Query list/detail/decision endpointleri kullanılır.
- Kanıt paneli kampanya/soru, ölçek/skor/eşik, ekip, iş günü hedefi ve cevap sürümü/sırasını gösterir. Form ilk görüntülenen kanıtı sabit tutar; background refetch pending isteğin sürümünü değiştirmez. 10–500 karakter gerekçe ve açık etki teyidi zorunludur. Onay görev oluşturma etkisini, ret aynı sürüm için kesinlik etkisini açıklar. Arşivli ekip onayı kapalı, ret açıktır.
- Karar isteği key/version/decision/reason ile sabitlenir; belirsiz sonuçta aynı payload tekrar gönderilir, alanlar ve kuyruk seçimi kilitlenir. Kesin hatada form eski kanıtla yeniden gönderilemez; kapatıp güncel incelemeyi açma mesajı verilir. Başarıda kuyruk yenilenir; oluşan göreve link gösterilir.
- Form/schema testleri açık teyit, reason sınırı, archived-team onay reddi ve aynı-key retry için yazıldı. Test/browser/typecheck/build çalıştırılmadı. Responsive/accessibility kabulü ve olumlu HTTP uçtan uca senaryo final doğrulamada açık.
- Bu formun belirsiz karar state'i henüz sayfa yenilemesi/başka route sonrası kalıcı değil; atama formundaki recovery yaklaşımının reason içeren review isteğine uygulanması sonraki iş. DB/API kontratı bu dilimde değişmedi.


### 2026-10-27 — Belirsiz inceleme kararını geri yükleme

- Onay/ret isteği gönderimden önce sessionStorage'da tenant+actor kapsamında strict UUID/version/decision/reason/key sözleşmesiyle kaydedilir. Aynı actor/sekmede çözülmemiş tek review tutulur; farklı istek üzerine yazılmaz. Kullanıcının teyit ettiği gerekçe payload'ın parçası olarak tutulur; skor, soru, müşteri alanları ve credentials kopyalanmaz.
- Kuyruk sayfası mount olduğunda bekleyen isteği ayrı recovery panelinde gösterir. Otomatik replay yoktur. Kuyrukta aksiyon artık bulunmasa veya GET evidence404 olsa bile kullanıcı aynı POST/key ile receipt sonucunu alabilir. Yeni karar seçimi recovery çözülene kadar kapalıdır. Başarıda görev linki, kesin ret/hata halinde güncel kuyruğu inceleme mesajı gösterilir.
- Network/belirsiz sonuç kaydı korur; başarılı veya kesin HTTP sonuçta sadece eşleşen key temizlenir. Okuma/yazma/bozuk veri hataları yeni gönderimi durdurur. Aynı sekme reload ve route dönüşü kapsanır; sessionStorage temizlenmesi/sekme sonlandırılması kapsam dışıdır. Server If-Match ve receipt koruması devam eder.
- Exact request replay, otomatik gönderim olmaması, kullanıcı/tenant izolasyonu, başka karar üzerine yazma reddi, yanlış key ile silmeme ve bozuk kayıt koruma testleri yazıldı. Önceki form testleri yeni storage scope'a uyarlandı. Testler çalıştırılmadı; browser/end-to-end kabulü açık.
- API/DB değişmedi. Önceki dilimde açık kalan review reload kurtarma işi kaynak kodda tamamlandı; Faz9'un diğer işleri ve final doğrulama devam ediyor.


### 2026-10-27 — Görevden bağımsız kalıcı inbox teslimi

- Ürün spec8'deki bildirim hatasının görevi geri almaması kuralı için migration142 caller_task_notification_outbox eklendi. Task/assignment transaction'ı sadece (tenant,task,task_version) tekil bildirimi niyet olarak kaydeder; inbox satırları burada oluşturulmaz. Audit alanı notification_intent_count oldu. Önceki aynı-transaction inbox teslimi notlarının yerini bu akış alır.
- Mevcut runtime survey drain önce action/task transaction'ını commit eder, sonra ayrı transaction'da aynı tenant/environment accepted/ended dispatch bağlamından bir notification intent işler. İkinci transaction hatası ilkini geri alamaz. Scope ve kapalı worker feature flag değişmedi. API status iki tüketicinin birleşik sonucudur; created sadece yeni task sayısıdır.
- Teslim savepoint'i inbox satırları ve succeeded receipt'i birlikte commit eder. Başarısızlıkta inbox yazımları geri alınır; 10/20/40/80 saniye bekleme, beşinci başarısızlık dead-letter. Uygun alıcı yoksa retry olur. Ham hata/PII tutulmaz. DB bağlantı hatası pending kaydı korur; görev commit edilmiş kalır.
- Teslim anında aktif üyelik ve owner/tasks.assign/tasks.assigned alıcı yetkisi yeniden doğrulanır. Terminal görev, değişmiş assignee veya aynı task için daha yeni notification intent varsa eski bildirim skipped olur; A→B→A durumunda eski A bildirimi gönderilmez. External push/e-posta hâlâ yok; inbox_only kullanılır.
-142 yerel DB loopback kimliği ve pg_dump yedeği sonrası uygulandı. Rollback dolu teslim geçmişini silmeyi reddeder. OpenAPI üretildi. Mevcut transaction fixture intent idempotency/rollback ve inbox savepoint rollback sonrası task/intent korunması için güncellendi; testler çalıştırılmadı.
- Kalan: HTTP/iki bağlantılı gerçek retry/dead-letter/environment izolasyonu testleri, operatör dead-letter replay UI, tercihli dış kanal teslimi ve final kabul. Phase9 tamamlanmış sayılmadı.


### 2026-10-27 — Görev durum/erteleme sürüm ve idempotency sözleşmesi

- POST task status/snooze artık zorunlu Idempotency-Key ve If-Match(task.version), 1 KiB body sınırı ve no-store kullanır. Tenant identity kilidi + task row lock altında mevcut görev erişimi receipt'ten önce kontrol edilir. Başka çalışana aktarılmış görev eski actor receipt'iyle okunamaz. Eski sürüm veya aynı key/farklı payload409 verir.
- Receipt yalnız task UUID/applied_version ve input hash tutar, PII/metadata kopyalamaz. Replay işlemi yeniden uygulamaz; yetkili güncel task projection'ını döndürür. Completion zamanı/sürümü tekrar değişmez, duplicate audit yazılmaz. Yeni snooze gelecek tarih ister; daha önce işlenmiş snooze tekrarında tarih geçmiş olsa da receipt kontrolü önde olduğu için işlem uygulanmadan mevcut görev döner.
- Client merkezi API key/version gönderir; form ilk gönderimde payload/sürüm/key dondurur. Belirsiz sonuçta kontroller ve drawer değişimi kilitlenir, aynı istek için ayrı retry butonu ve kalıcı hata metni gösterilir. Background task refetch pending formu sıfırlamaz. Kesin hata sonrası güncel detay alınır.
- Assigned-task HTTP testine completion replay zamanı/sürümü, stale version ve same-key/different-payload409 eklendi. Eski resource testleri header sözleşmesine, client fixture'ları version alanına uyarlandı. Testler çalıştırılmadı; OpenAPI yeniden üretildi.
- Yeni DB migration yok (140 version trigger kullanılır). Eski entegrasyonlar artık header göndermeden state değiştiremez; API/client birlikte dağıtım gerektirir. Bu state formunun reload recovery'si henüz atama/review formundaki kalıcılığa taşınmadı; uçtan uca retry/assignment-revocation testleri ve manual create mutation korumaları açık.


### 2026-10-27 — Manuel görev oluşturmanın transaction sınırı

- Manuel görev oluşturma ayrı task-create servisine taşındı. Tenant identity advisory lock, yetki kontrolü, kaynak çözümleme/kilitleri, insert, minimal audit ve response projection aynı transaction içinde. Kaynak veya audit başarısızlığında görev commit edilmez.
- Sorumlu artık users.tenant_id üzerinden değil aktif tenant_memberships üzerinden doğrulanır; aktif/silinmemiş kullanıcı ve üyelik FOR SHARE ile korunur. Owner veya caller.tasks.assigned izin tanığı commit'e kadar kilitlenir. Ekip allocator ve manuel atamanın ortak izin sorgusu ayrıca revoked_at IS NULL ister.
- Doğrudan kişi bağlantısı arşivli kişiyi reddeder. Call/case/lead referansları tenant kapsamında kilitlenir; mevcut DB identity guard'ları ilişki tutarlılığı ve kişi revision yakalamasını sürdürür. Audit görev UUID, pending durumu ve assigned boolean tutar; başlık/açıklama/kişi içeriği kopyalamaz.
- Mevcut assigned-task HTTP fixture'ına manuel create/audit, silinmiş üyelik reddi ve geçersiz lead bağlantısında görev oluşmaması senaryoları eklendi. Yalnız kaynak/diff incelemesi ve formatter kullanıldı; kullanıcı talimatıyla test/typecheck/lint/build çalıştırılmadı.
- DB migration veya client sözleşme değişikliği yok. Manuel create idempotency, client belirsiz sonuç recovery, farklı bağlantılarla yarış testleri ve genel final doğrulama hâlâ açık; bu dilim mükerrer oluşturma koruması sağlamaz. Faz9/goal tamamlanmış sayılmadı.


### 2026-10-27 — Manuel görev oluşturma idempotency sözleşmesi

- POST /api/v1/follow-up-tasks zorunlu 8–200 karakter Idempotency-Key, 64 KiB body sınırı ve success/error no-store kullanır. Yeni kaynak olduğu için If-Match aranmaz. Tenant identity lock altında tenant+actor+task.create+key receipt kontrolü, görev ve audit tek transaction'dadır.
- Aynı key ve doğrulanmış payload replay'i yeni görev/audit üretmeden mevcut görev projection'ını okur. Payload farkı veya süresi dolmuş receipt409 verir. Receipt yalnız görev UUID ve request hash tutar; başlık/açıklama/metadata kopyalamaz. Replay öncesi caller.tasks.assign yetkisi yeniden kontrol edilir.
- Client merkezi create endpoint key/body ayrımını uygular. İlk istekte body/key sabitlenir; network/belirsiz hatada form ve drawer hareketleri kilitlenir, aynı isteği tekrar gönder butonu görünür. Kesin400/401/403/404/409/413/422 sonuç pending'i temizler. Tenant/actor değişiminde sayfa bileşeni yeniden oluşturulur; pending state başka tenant'a taşınmaz.
- HTTP kaynak testlerine replay UUID, tek audit, farklı payload409, eksik key400, minimal receipt ve yetki kaldırıldıktan sonra replay403 eklendi; eski create fixture'ları header'a uyarlandı. Client transport test kodu network hatası sonrası aynı key/body gönderimini kapsar. Testler çalıştırılmadı. OpenAPI API çalışma dizininden yeniden üretildi; ilk kök dizin denemesi tsx çözümleme hatası verdi, doğru dizindeki üretim başarılı oldu.
- DB migration yok. API/client birlikte dağıtılmalı; eski headersız create istemcileri400 alır. Belirsiz create ve state isteklerinin reload/route sonrası kalıcı recovery'si, UI retry kabul testi ve iki bağlantılı concurrency kanıtı açık. Bu dilim yalnız mevcut mount ömründe client pending'i korur. Faz9 ve goal devam ediyor.


### 2026-10-27 — Manuel görev oluşturma reload kurtarması

- Client ilk create POST öncesinde key ve tam gönderilecek body'yi sessionStorage'a tenant+actor kapsamında kaydeder. Tek sekmede aynı aktörün çözülmemiş tek create isteği tutulur; başka istek üzerine yazılmaz. Strict UUID/body şeması ve 64 KiB kayıt sınırı kullanılır. Başlık/açıklama/metadata kullanıcı girdisi olarak saklanabilir; bu kayıt PII içermiyor varsayılmaz.
- Görev sayfası mount'unda pending kayıt okunur. Görev listesi veya oluşturma drawer'ında recovery paneli görünür; otomatik POST yoktur. Kullanıcı aynı isteği tekrar gönderdiğinde mevcut API receipt sözleşmesi uygulanır. Başarıda sadece eşleşen key silinir ve görev detayına gidilir; kesin HTTP sonuçta listeyi kontrol etme mesajı gösterilir; belirsiz hatada kayıt korunur.
- Depolama okuma/yazma/şema hatasında yeni create gönderimi durur. Recovery varken yeni create formu kilitlenir. Tenant/actor keyed page sınırı korunur. Aynı sekmede reload/route dönüşü kapsamda; sekme kapatma veya sessionStorage'ın kullanıcı tarafından temizlenmesi kapsam dışında.
- Helper test kaynakları exact payload, tenant/actor izolasyonu, farklı istek üzerine yazma reddi, yanlış key ile silmeme ve bozuk kaydı korumayı kapsar. Recovery component test kaynağı otomatik gönderim olmaması, belirsiz sonuçta koruma, exact retry ve başarıda temizlemeyi kapsar. Test/typecheck/browser çalıştırılmadı; yalnız kaynak/diff incelemesi ve formatter kullanıldı.
- API/DB kontrat ve migration değişmedi. Görev durum/erteleme reload recovery'si, gerçek browser kabulü ve diğer Faz9 işleri açık; goal tamamlanmış değildir.


### 2026-10-27 — Görev durum ve erteleme reload kurtarması

- Durum/erteleme POST öncesinde tenant+actor kapsamında tek pending istek sessionStorage'a kaydedilir: işlem türü, görev UUID, ilk sürüm, key ve minimal body. Strict şema yanlış tür/body/sürümü reddeder. Yeni işlem eski pending üzerine yazamaz; başka tenant veya kullanıcı kaydı okunmaz.
- Sayfa mount'unda recovery okunur; liste veya edit drawer'ında ayrı panel kullanıcı isteğiyle aynı POST'u gönderir. Yeni state formu pending/depolama hatası sırasında kilitlidir. Başarı eşleşen key'i temizler ve güncel göreve gider; kesin hata sonrası durum kontrolü mesajı, belirsiz hatada korunan kayıt ve retry sunulur. Arşivlenmiş/değişmiş erişimde mevcut API yetki/receipt sırası uygulanır.
- Önceden gönderilmiş snooze'un tarihi geçmiş olabilir; storage şeması yalnız ISO datetime doğrular ve future şartı koymaz. Böylece API'nin receipt öncelikli replay davranışı korunur. Yeni snooze için API gelecek tarih kuralı değişmedi.
- Kaynak testleri özgün sürüm/key korunması, actor/tenant izolasyonu, overwrite/yanlış-key clear reddi, bozuk kayıt, geçmiş tarihli snooze replay, otomatik gönderim olmaması ve definitive403 temizliği için eklendi. Test/typecheck/lint/build/browser çalıştırılmadı. Formatter ve kaynak/diff incelemesi yapıldı.
- API/DB değişmedi. Aynı sekme reload/route dönüşü kapsanır; sekme kapatma/storage temizliği kapsamında değil. Gerçek browser ve iki bağlantılı API kabul kanıtları final doğrulamada açık; Faz9 ve sonraki fazlar devam ediyor.


### 2026-10-27 — Tükenmiş görev bildirimi operasyon API'si

- GET /api/v1/task-notifications/failures caller.tasks.assign kapsamında sadece tenant'ın dead-letter bildirimlerini döndürür. Görev UUID+bildirimin task_version alanıyla 50 varsayılan/100 üst limitli cursor sayfalama; başlık, kişi bilgisi, internal ID ve ham hata dönmez. Cursor alanları birlikte zorunludur. Canlı sayfalama snapshot garantisi vermez.
- POST /api/v1/task-notifications/:public_id/:version/retry aynı yetki, zorunlu Idempotency-Key ve 10–500 karakter gerekçe ister. Path version mevcut görev sürümü değil immutable bildirim niyetinin task_version değeridir. Tenant identity lock + task/outbox row lock altında yalnız dead-letter yeniden pending yapılır; kapalı görev, değişmiş assignee veya daha yeni niyet409 verir. İşlem sadece beş denemelik teslim hakkını sıfırlar, yeni görev veya anlık bildirim oluşturmaz.
- Receipt ve audit reset ile aynı transaction'dadır. Aynı key/body replay yeni reset/audit üretmez. Audit eski/yeni durum, attempt_count, bildirim sürümü ve kullanıcının gerekçesini tutar; gerekçe kullanıcı girdisi olarak PII içerebilir. Mevcut runtime tenant/environment koşulları ve kapalı worker flag değişmez.
- Route'lar success/error no-store, retry4KiB body limiti kullanır. OpenAPI üretildi. Kaynak testlerine cursor/reason sınırları, liste/no-store/minimal projection, retry/reset, replay tek audit, pending tekrar409 ve assigned-only403 eklendi. Test/typecheck/lint/build çalıştırılmadı. Formatter'da bulunan OpenAPI literal sözdizimi hatası düzeltildi, ardından üretim başarılı oldu.
- DB migration yok. Client operasyon sayfası, tenantlar arası ve terminal/superseded race HTTP kanıtları, dead-letter teslim çevrimi ve genel final doğrulama sonraki işlerdir. Faz9 tamamlanmış sayılmadı.


### 2026-10-27 — Bildirim teslim hataları arayüzü

- /app/task-notifications route, TR/EN menü ve sayfa başlığı caller.tasks.assign yetkisiyle eklendi. Sayfa tenant+actor key ile yenilenir. Merkezi RTK Query API'si cursor alanlarını birlikte gönderir, retry key'i header'da ve gerekçeyi body'de taşır; başarılı/değişen işlemler liste ve audit cache'ini invalid eder.
- Liste yükleme/hata/boş durumlarını, yenileme, ilk/sonraki sayfa ve görev detay bağlantısını sunar. Bildirim zamanı ve tükenmiş deneme sayısı gösterilir; iç ID veya müşteri alanları ekrana basılmaz. Yeniden kuyruğa alma RHF+Zod formunda 10–500 karakter gerekçe ve açık etki teyidi ister. Görev oluşturulmayacağı, yalnız teslim denemelerinin yenileneceği açıklanır.
- Gönderim öncesi request UUID/version/key/reason tenant+actor kapsamında sessionStorage'a kaydedilir. Başka pending üzerine yazılmaz. Belirsiz sonuçta aynı istek panelden tekrar gönderilir; mount otomatik gönderim yapmaz. Success/definitive sonuç yalnız eşleşen kaydı temizler; storage sorunu yeni gönderimi kapatır. Başarı mesajı kuyruğa alınmayı teslim edilmiş saymaz. Gerekçe kullanıcı girdisi olarak storage'da tutulur.
- Kaynak testleri explicit confirmation/reason sınırı, exact retry, izolasyon, bozuk kayıt koruması, yanlış-key clear reddi, reload'da otomatik POST olmaması ve yeni formun kilitlenmesi için eklendi. Test/typecheck/lint/build/browser çalıştırılmadı. Formatter ve kaynak/diff incelemesi yapıldı.
- API/DB değişmedi. Gerçek browser responsive/a11y kabulü, tenantlar arası API/race testleri ve notification dead-letter çevrimi final doğrulamada açık. Hata listesi live pagination'dır; başarılı replay sonucu teslim garantisi değildir. Faz9 ve tüm goal devam ediyor.


### 2026-10-27 — Teyitli geri arama takvimi okuma API'si

- Mevcut122 callback veri temeli korunarak GET /api/v1/callbacks eklendi. caller.campaigns.read yetkisi ve tenant kapsamı zorunlu; from dahil/to hariç en fazla31 günlük aralık, kampanya ve pending/canceled durum filtresi,50 varsayılan/100 üst limit vardır. Route success/error no-store kullanır.
- Due time + public UUID sıralı birleşik cursor alanları birlikte zorunludur ve aralığın içinde olmalıdır. PostgreSQL due timestamp mikro saniyeleri cursor'a UTC text olarak korunur; sonraki karşılaştırma JS Date dönüşümü olmadan timestamptz ile yapılır. Aynı filtrelerle dönen cursor aynen kullanılmalıdır; liste canlıdır, snapshot garantisi yoktur.
- Yanıt callback/kampanya public kimliği ve kampanya adı, teyit/due/pencere saatleri, alıcı saat dilimi, kayıt durumu ve iptal nedeni içerir. Kişi alanları, transcript, evidence_reference ve internal ID dönmez. Pending için window_expired statement_timestamp ile türetilir; bu kalıcı missed veya takip görevi oluşturulduğu anlamına gelmez.
- Sorgu şeması kaynak testleri31 gün sınırı, eksik/uygunsuz cursor, geçersiz durum ve fazladan tenant alanını kapsar. HTTP fixture owner boş liste/no-store, unauth401 ve assigned-only403 için genişletildi. OpenAPI üretildi. Test/typecheck/lint/build/browser çalıştırılmadı.
- DB migration yok. Calendar client, pozitif veri/tenant izolasyonu/mikro saniyeli pagination testleri, teyit runtime yazımı, callback dispatch/missed yaşam döngüsü ve takip görevi işleri açık. Bu read API çağrı planlamaz veya göndermez; Faz9 ve goal aktif.


### 2026-10-27 — Geri arama takvimi arayüzü

- /app/callbacks route, TR/EN başlık/menü ve caller.campaigns.read koruması eklendi. Tenant+actor değişiminde sayfa yeniden oluşturulur. Merkezi callbackCalendar RTK Query istemcisi tam cursor timestamp'ını dönüştürmeden taşır; filtre değişiminde cursor sıfırlanır.
- UTC olarak açık etiketlenmiş ilk/son gün filtresi, dahil son günün API exclusive end'e çevrilmesi,1–31 günlük doğrulama, durum filtresi,7 gün geri/ileri ve kampanya satırından daraltma bulunur. Varsayılan bugün dahil7 gün. Gruplar UTC gününe göre; her planın due/pencere saati recipient_timezone ile gösterilir. Tarayıcının desteklemediği timezone'da açık UTC fallback vardır.
- Sayfalı görünüm pending/canceled, pencere geçmiş gözlemi, teyit saati ve iptal nedenini gösterir. Pencere geçmiş pending kayıt “sonuç bekleniyor” olarak etiketlenir; missed lifecycle veya görev üretimi olmuş gibi gösterilmez. Call mutation kontrolü yoktur. Loading/error/empty/retry, ilk/sonraki sayfa ve odak dışını atlayan10 saniyelik polling eklendi.
- Test kaynakları UTC dahil/exclusive sınırı, artık gün/yıl geçişi, geçersiz ve uzun aralık, mikro saniyeli cursor korunması, kampanya değişiminde cursor sıfırlanması ve expired gözlemi/read error UI için eklendi. Test/typecheck/lint/build/browser çalıştırılmadı; formatter ve kaynak/diff incelemesi yapıldı.
- API/DB değişmedi. Gerçek browser/a11y, pozitif API pagination/tenant kabulü ve callback teyit/dispatch/missed/görev yaşam döngüsü açık; Faz9 ve goal devam ediyor.


### 2026-10-27 — Missed geri arama terminal durumu ve görev bağı

- DB143 caller_callback_plans'a missed terminal durumu, DB-owned missed_at ve tenant-scope follow_up_task_id FK ekler. pending/canceled/missed alan şekilleri ayrı kısıtlanır; missed geçişi yalnız pending kaydın30dk penceresi geçmişse ve pencere sonrası oluşturulmuş, aynı tenant/kişi/identity_revision görevi varsa kabul edilir. Bir görev iki callback'e bağlanamaz. Missed/canceled terminal kayıt tekrar değiştirilemez; kanıt/timing geçmişi silinmez.
- Kampanya stop trigger'ı ve API finish/drain aday sorguları canceled+missed durumlarını çözümlenmiş sayar; diğer bilinmeyen durumlarda kapalı kalır. Pause/cancel callback işleyicisi sadece pending kayıtları işlemeye devam eder; missed geçmişi iptal adına değiştirilmez.
- Calendar API state filtresi/DTO/OpenAPI missed ve missed_at ile genişledi. Client filtrede ve etikette kalıcı missed durumunu, sadece window_expired olan pending gözleminden ayırır. Missed etiketi DB'nin zorunlu görev bağını yansıtır.
- Yerel DB adı/loopback adresi kontrol edildi; pg_dump yedeği700 dizin/600 dosya izinleriyle alındıktan sonra143 transaction içinde uygulandı. Rollback missed/görev bağlı geçmiş varsa reddeder. Bu migration uygulaması davranış testi yerine sayılmaz. Final test DB'lerine143 de uygulanmalı.
- Callback stop fixture'ına premature missed reddi, pending/canceled null alanları ve canceled→missed reddi kaynak testleri; client missed filter testi eklendi. OpenAPI üretildi. Test/typecheck/lint/build/schema-validator/rollback/browser çalıştırılmadı.
- Bu dilim DB geçiş sözleşmesidir: süre aşımını tarayan worker, görevi aynı transaction'da üreten servis ve bildirim teslim bağlantısı henüz eklenmedi. Pozitif missed/tenant/kimlik/race kabulü ve callback dispatch bağlama açık. Faz9/goal tamamlanmış sayılmadı.


### 2026-10-27 — Missed callback görev materializer ve ortak bildirim teslimi

- Internal materializeMissedCallback tenant+environment+callback UUID alır, caller-owned transaction içinde identity advisory lock ve plan/source/provider kilitleri kullanır. Kaynak accepted/ended ve aynı provider environment olmalıdır; yanlış ortam404. Terminal missed mevcut görev UUID'sini döndürür, canceled değişmez, pencere dolmamış plan not_due döner.
- Süresi geçen planın güncel hedef/kişi/snapshot bağlamı kilitlenir. Aktif kampanya cancel isteği, DNC/arşiv/identity değişimi veya canceled hedef varsa plan uygun nedenle canceled olur; görev açılmaz. Pause tek başına süre aşımını durdurmaz. Kaynak haricinde sonradan hazırlanmış/aktif/belirsiz/kabul edilmiş/bitmiş hedef çağrısı varsa, callback dispatch bağı henüz kurulmadığından reconciliation_required döner; missed tahmini yapılmaz.
- Uygun planda bir iş günü son tarihli, genel yönetici kuyruğunda sorumlu bekleyen görev oluşturulur. Snapshot dili/timezone'u kullanılır. Görev, callback missed+FK bağı, minimal system audit ve notification intent aynı transaction'dadır; sonraki replay yeni görev/bildirim üretmez. Ekip seçimi/round-robin callback konfigürasyonu ve manuel atama bağlamı sonraki iştir; burada rastgele ekip seçilmez.
- Bildirim primitive'leri queueTaskNotification/deliverTaskNotice olarak genelleştirildi; TR/EN metinleri anket dışında da doğru olacak şekilde düzenlendi. Ayrı inbox consumer survey action veya missed callback görevinin accepted/ended kaynak dispatch'inden tenant/environment uygunluğunu doğrular. Görev transaction'ını inbox hatası geri alamaz. Public worker scope/feature flag açılmadı.
- Callback fixture'a yanlış environment reddi, not_due ve canceled replay kaynak testleri eklendi. OpenAPI consumer açıklaması güncellendi/üretildi. Test/typecheck/lint/build çalıştırılmadı; kaynak/diff incelemesi yapıldı.
- DB migration yok (143 kullanılır). Otomatik tarama/runtime endpoint/worker, retry/dead-letter, pozitif missed/replay/rollback/identity/dispatch race testleri ve gerçek callback dispatch bağlantısı açık. Bu servis henüz periyodik çalıştırılmıyor; Faz9/goal devam ediyor.


### 2026-10-27 — Callback süre aşımı tüketicisi ve kapalı worker bağlantısı

- DB144 callback başına tenant-scoped processing receipt ekler: pending/succeeded/needs_review/dead_letter,0–5 attempt, available/completed zamanları ve yalnız processing_failed/dispatch_reconciliation_required hata kodu. Review durumu null olmayan mutabakat kodu ister; dead-letter beş denemeye bağlıdır. Dolu geçmişi rollback silmez. Yerel DB/loopback doğrulama+pg_dump yedeği sonrası144 uygulandı; test DB'leri finalde144'e kadar taşınmalı.
- drainCallbackExpiration bir transaction'da tenant try-lock altında bir expired pending plan seçer; kaynak accepted/ended provider environment sınırı korunur. Domain task/callback/audit/notification intent ve succeeded receipt atomiktir. Savepoint hata halinde domain yazılarını geri alır;10/20/40/80 saniye retry ve beşinci hata dead-letter. Mutabakat gerektiren plan needs_review olur ve tekrar aday seçilmez; diğer planları bekletmez. Clock correction not_due sonucunda attempt harcamadan10s bekler.
- POST /api/internal/v1/callbacks/drain runtime.callbacks.process imzalı servis hesabı scope'u, strict boş body,1KiB sınır, no-store ve sensitive rate limit kullanır. Tenant/env kullanıcı body’sinden alınmaz. Callback transaction commit sonrası ayrı notification drain transaction'ı çalışır; inbox hatası görevi geri alamaz. Aggregate status yanında review_required korunur; created sadece callback görevi sayar.
- CALLER_CALLBACKS_ENABLED varsayılan false; mevcut CALLER_WORKER_ENABLED ile birlikte gerekir. Monitor idle10s, processed/review1s; aggregate scans/failures/created/dead_letters/needs_review ve30s readiness eklendi. Worker DB'ye doğrudan bağlanmaz; signed API kullanır. Hiçbir flag etkinleştirilmedi, dış çağrı gönderilmez.
- Kaynak testleri wrong-env/future idle, review/dead-letter DB constraint, unauth401/no-store, default-off ve monitor status/abort davranışları için eklendi. OpenAPI üretildi. Test/typecheck/lint/build/schema-validator/rollback/browser çalıştırılmadı.
- Kalan: pozitif expiry/replay/rollback/race ve signed-scope/env HTTP kabulü; callback pending-scan index/query plan, needs_review/dead-letter operasyon görünümü ve kontrollü çözüm; callback teyit/dispatch binding/ekip atama. Bu worker kaynak kodda bağlı ama çalıştırılmadı; Faz9 ve goal devam ediyor.

### Callback expiration recovery API — 2026-10-27

Migration 145 adds a monotonically increasing processing receipt version and a pending expiration scan index. Calendar responses now include nullable processing status/version/attempt count/sanitized error code. POST /api/v1/callbacks/:public_id/processing/retry requires campaigns.edit + tasks.assign, Idempotency-Key, If-Match and an audited reason. Only a pending plan with dead_letter processing can be requeued; needs_review cannot be overridden. Replays reuse the receipt without resetting attempts again. No calls are placed and worker flags remain unchanged.

Local haisly_caller was backed up and migrated through 145. OpenAPI regenerated. No tests, typecheck, lint or build run per user instruction. Validation source added; positive retry/replay/concurrency integration coverage and client processing labels/retry interaction remain pending. F9 is not complete.

### Callback processing recovery UI — 2026-10-27

Client calendar consumes processing status/version/count and distinguishes pending, completed, exhausted and reconciliation-required outcomes. Requeue is available only with campaigns.edit + tasks.assign, for pending/dead-letter rows. Reason and explicit confirmation are required; If-Match protects the selected processing version. An exact request is saved before POST in tenant/actor-scoped sessionStorage, restored without automatic submission, and replayed with the same idempotency key after unknown outcomes. Known client errors clear the pending request; unavailable/corrupt storage blocks submission. No review override or direct call action was added.

Source tests cover confirmation, unknown-response replay, reload recovery, storage isolation and read-only status visibility. Tests/typecheck/lint/build/browser verification remain deferred to the final batch per user instruction. API/DB runtime unchanged in this slice; migration remains 145. F9 and the overall goal remain incomplete.

### Callback confirmation preparation — 2026-10-27

Added internal CallbackConsentService for exact future minute-level callback readback in TR/EN with recipient IANA timezone and explicit UTC offset. Vague/naive/past/sub-minute times are rejected without silent rounding. Canonical UTC intent digest binds tenant, runtime session/release, target/snapshot, source dispatch, contact identity revision and the exact prior plan being replaced. DST repeated wall times therefore have distinct readbacks/digests. Extracted existing survey observation timing/correlation validation into a shared dialogue confirmation primitive without loosening its five-minute challenge, distinct-event or prompt-before-response checks; callback additionally rejects confirmation after its proposed time.

This is pure internal preparation and evidence correlation, not proof of observer authenticity, a public scheduling endpoint, temporal eligibility, challenge persistence or plan insertion. Runtime-owned context resolution, durable challenge consumption, atomic reschedule and nearest-eligible offer remain pending. Source tests cover canonical instants, changed intent/context, vague/past/precision rejection, DST readback, stale/mismatched evidence and unknown decisions; no tests/typecheck/lint/build run per user instruction. No DB migration, client runtime change or live call in this slice. F9 remains incomplete.

### Durable callback consent challenges — 2026-10-27

Migration 146 stores callback confirmation challenges bound by tenant FK to the immutable runtime release binding, exact due time/timezone, stored prompt/digest and optional prior callback. Database guards require the active matching outbound call, current contact identity/no DNC, uncanceled target/campaign and a future whole-minute time. Issue timestamps/expiry are DB-clock controlled (at most five minutes, capped by due time). Scope and resolved decisions are immutable; response events cannot be reused in the same bound call. Consumption requires a matching confirmed plan and, for replacement, the old plan canceled as rescheduled. Populated-table rollback refuses evidence loss.

Internal CallbackConsentStore resolves scope from runtime, reuses an unresolved identical challenge without extending expiry, records trusted observer decisions idempotently, audits issuance/resolution and rejects changed prior-plan/context/evidence. A granted observation remains unconsumed and does not insert or cancel a callback; the temporal/budget eligibility and atomic plan writer are still pending. No public confirmation endpoint or live observer was enabled.

Local haisly_caller backed up and migrated through 146. Added integration source coverage inside existing bound-runtime fixture for challenge replay, wrong environment/prior plan, immutable scope, exact decision replay, invalid consumption and no scheduling from consent alone. Tests/typecheck/lint/build not run per user instruction; fixture coverage is not acceptance evidence. Client runtime unchanged. F9 remains incomplete.

### Callback confirmed-plan transaction — 2026-10-27

Added internal scheduleConfirmedCallback/applyCallbackConfirmation orchestration: runtime-bound granted evidence is re-resolved, locked, expiry/context/current-plan checked, then the prior plan is canceled as rescheduled, a new plan inserted, the challenge consumed against its DB-enforced matching plan, and audit appended in the same caller-owned transaction. Replays return the original plan rather than inserting another. Denied/unknown evidence does not schedule. Blocked budget decisions must be committed to retain existing budget pause/events.

Planning checks enforce contact consent/status/identity, verified recipient timezone, campaign date/window, published country/tenant policies effective at proposed time, attempts, known production cooldown/daily limits and current account/budget capacity estimated using the source tariff. The active source call is never assigned a fabricated end; a proposal has a 15-minute lower bound from current time and dispatch must recheck against its actual eventual end. Added future-policy reader while existing dispatch policy reads remain DB-current-time based.

Important remaining dependencies: this internal primitive is not connected to a trusted live observer/public endpoint and never grants dispatch authorization or reserves a future budget. Complete test/legacy/inbound history, nearest-eligible offer, human task on blocked limits, positive schedule/reschedule/replay/concurrency acceptance, callback-to-dispatch binding and final send-time gates remain pending. Added source tests for source lower bound, cross-campaign/rolling limits, history integrity, and unconfirmed scheduling rejection; no tests/typecheck/lint/build executed per user instruction. No schema/client runtime changes; local DB stays at 146. F9 incomplete.

### Callback alternate-time offers — 2026-10-27

Added internal proposeCallbackTime with authenticated runtime context, exact current replacement-plan check, known production-history lower bound, and a bounded published policy timeline under the shared policy lock. Candidate search returns the earliest whole-minute time at/after the request, intersecting campaign and country/tenant local windows, weekdays and excluded dates. Published future policy changes apply at their effective instant. UTC traversal handles DST without invented offsets; CPU work yields every 256 candidates and timezone formatters have a bounded cache. Search is limited to 31 days and 1,024 policy entries and returns an explicit unavailable result when bounded search cannot find a slot. Final contact/time/attempt/budget checks run once on the candidate; canceled campaigns are rejected.

An offer does not create consent, edit a plan, reserve funds or authorize a call. A changed time requires the exact-time confirmation workflow. Runtime endpoint/observer integration, full extra call history, human follow-up on hard blockers and offer-to-challenge orchestration remain pending. Source tests cover exact offers, local window intersection, excluded dates, future policy activation, attempt/end boundaries and DST; no test/typecheck/lint/build run per user instruction. No DB migration or client runtime change; DB stays 146. F9 incomplete.

### Signed callback offer and confirmation-request endpoints — 2026-10-27

Added POST /api/internal/v1/call-sessions/:call_session_public_id/callback-offer and callback-consent-request. Separate runtime.callbacks.propose/runtime.callbacks.consent.request scopes, signed runtime credentials and active tenant/environment-bound session resolution are required. Both accept only exact requested time, IANA timezone and prior-plan UUID/null; ownership, language, release and source call are server-derived. Both have 1 KiB body limits, sensitive rate limits and no-store on errors/success.

Consent request first runs the offer/gate workflow. Only an unchanged eligible requested time issues/reuses a pending challenge; a shifted candidate returns an offer and must be explicitly resubmitted for exact readback. New challenge audit identifies the authenticated service account. No decision ingestion or automatic scheduling is exposed; trusted observer acceptance remains separate. Added OpenAPI contracts and regenerated artifact. Integration test source extends runtime boundary coverage for anonymous/missing/denied scopes, unbound sessions, forged consent/ownership fields, vague time, oversized body and absence of challenge writes. Positive bound HTTP/observer/provider acceptance remains unverified. Tests/typecheck/lint/build not run per user instruction. DB remains146; client runtime unchanged; F9 incomplete.

### Human review for callback limit/end blockers — 2026-10-27

Migration147 adds immutable caller_callback_review_actions with tenant-scoped binding/task foreign keys and one task per bound source conversation. Insert guard validates the active correlated outbound call and task/contact identity; populated rollback refuses provenance loss. Internal materializer creates a localized one-business-day review task plus notification intent/audit atomically, or reuses the existing task even if a second qualifying blocker is reported. Nonqualifying blockers produce no task.

Runtime offer/consent requests and confirmed scheduling attach this task for attempt_limit_reached, campaign_ended or campaign_ends_before_eligibility. Campaign end before any eligible slot now returns the specific end blocker. Unavailable runtime responses include nullable follow_up_task_public_id. Independent notification drain recognizes review provenance in the authenticated environment; creating a review never authorizes an external call.

Local haisly_caller backed up and migrated through147; OpenAPI regenerated. Source integration cases cover conversation-level deduplication, wrong environment, nonqualifying reasons, one notification and immutable provenance. Tests/typecheck/lint/build not executed per user instruction. Review tasks currently enter the manager assignment queue; frozen callback team config, round-robin allocation and manual assignment support for callback tasks remain outstanding (existing assignment endpoint only handles survey-action team context). Client runtime unchanged; F9 incomplete.

### Captured callback team and task assignment — 2026-10-27

Migration148 adds tenant-FK callback team and 1–30 business-day deadline to campaign drafts, with active-team draft validation and loss-refusing rollback. API settings preserve omitted values, allow explicit clearing, expose the selection, capture it in existing snapshot/hash/clone settings flow, and require a callback team at preflight. Client campaign editor now provides paged team selection and deadline input with loading/error/empty/saved-selection states and save locking.

Missed-callback and hard-blocker review materializers use the captured team with the existing atomic round-robin allocator and captured deadline. Eligible assignee gets task/notification; no eligible member leaves an unassigned queue task. Legacy snapshots without a team remain in the manager queue with one-business-day default; archived configured teams fail closed through the existing allocator. Manual assignment and assignee listings now resolve callback team from immutable source dispatch/snapshot provenance as well as survey ledgers, never task metadata; existing task version/permissions/notification checks remain. Ambiguous provenance is rejected.

Local DB backed up and migrated through148; OpenAPI regenerated. Added source integration settings preservation/snapshot/unknown-team assertions and client team/deadline/locked-form tests. Positive callback allocation, replay cursor, callback manual reassignment, browser/typecheck/build and broad tests remain unexecuted until final batch per user instruction. F9 still incomplete; no live calling/deployment.

### Callback-to-dispatch binding — 2026-10-27

Migration149 adds immutable tenant-scoped callback/dispatch links. Each dispatch links to at most one callback; another attempt for the plan is allowed only when prior linked attempts are definitively rejected/canceled. Insert guard requires matching target/snapshot/contact identity and environment, a prepared new attempt, an actually ended source call plus 15-minute cooldown, and the live 30-minute window. A dispatch transition trigger rechecks pending plan/window before provider submission, including cancellation/reschedule after preparation. Rollback refuses populated history loss.

Internal prepareProductionIntent accepts optional callback_public_id; a target with a pending plan requires its exact UUID, validates its window and unresolved links, uses the confirmed callback exception in existing spacing checks, and writes the binding atomically with reservation/intent. Other campaign cooldown, daily/attempt, contact, policy and budget gates stay in force. No final dispatch authorization is granted.

Local DB backed up and migrated through149. Added source cases for omitted/wrong callback, future-window denial and invalid self-binding. Tests/typecheck/lint/build not run per user instruction. Acceptance-to-started terminal lifecycle, late/uncertain reconciliation, positive binding/retry/concurrency verification, full extra history and actual dispatch integration remain pending; current missed worker stays conservative about later calls. Client runtime unchanged; F9 incomplete.

### Missed callback replay and captured settings correction — 2026-10-27

Source review found callback team allocation accidentally placed inside the already-missed replay branch, referencing context before initialization and leaving new task creation without an assignment variable. Allocation now runs only immediately before creating a new task, after cancellation/reconciliation checks. Replays read the existing task without allocating, advancing a team cursor or queuing another notification. Task deadline/team settings now come from the immutable source dispatch snapshot, matching manual task-assignment provenance.

Added an isolated service replay regression with a recording SQL connection that rejects unexpected reads/writes; it is not a substitute for database/concurrency acceptance. Source diff reviewed; tests/typecheck/lint/build remain deferred to the final batch per user instruction. No migration, API contract, client runtime or live provider change. Local DB remains149. The planned accepted-dispatch-to-started callback lifecycle is still outstanding; this correction was prioritized before it. F9 and the overall goal remain incomplete.

### Provider acceptance completes callback start lifecycle — 2026-10-27

Migration150 adds the terminal started state with immutable accepted timestamp and tenant-scoped dispatch provenance. The transition requires a149 callback link and provider acceptance in [due_at, window_ends_at); DB derives started_at from that dispatch. Started is provider acceptance, not answer or business success. Campaign stop treats it as terminal callback work while still waiting for unresolved calls. Rollback refuses started-history loss.

Authenticated normalized dispatch-event processing reconciles the bound plan in the same transaction, including duplicate/late observations. Eligible pending plans become started and earlier expiration receipts resolve; repeat observations do not add audit/version changes. Out-of-window or canceled/missed conflicts preserve call facts and original task/history, and persist needs_review without automatically dispatching again. Calendar API/OpenAPI/client expose started filtering and nullable started_at with precise acceptance labels.

Local haisly_caller backed up and migrated through150; OpenAPI regenerated. Added source assertions for unlinked start denial, query filtering and UI acceptance/timestamp labels. Tests/typecheck/lint/build/browser and positive provider-event/boundary/concurrency acceptance remain deferred to the final batch. No real provider connection or calls. Full history gates, runtime observer/dispatch integration, F9 remaining tasks and later phases remain open; goal not complete.

### Marketing interest confirmation and decision contract — 2026-10-27

Added strict marketing-interest preparation, rule, persisted-result projection and typed decision contracts. TR/EN readback explicitly names information/quote/demo, the subject, and forwarding the request to sales. The digest binds tenant, session, release, target, snapshot, dispatch, contact identity revision and result version, so a corrected result/different request cannot reuse its confirmation. Shared dialogue evidence checks enforce delivered prompt ordering, distinct event references, exact challenge/digest and bounded expiry; they do not prove provider authentication or speech recognition.

Pure evaluation permits automatic lead+task only for current-identity, current-revision human interest with an explicit requested action and granted confirmation under automatic mode. Unknown/unconfirmed interest enters review; denied interest does not create a lead; callback/representative requests remain separate workflows. It neither writes records nor authorizes calls. Inputs must later be read from authoritative persisted state, not model/client booleans. No HTTP endpoint exposes this decision function.

Added test source for digest binding, changed requests/revisions, malformed preparation, evidence substitution/expiry, denied/unknown decisions, human/identity/revision gates and review mode. Tests/typecheck/lint/build not run per user instruction. Durable marketing results/consent, frozen campaign rule configuration, idempotent lead/task materialization, review and correction UI remain outstanding. No DB/client runtime changes or migration; DB remains150. F09-T02 and the full goal remain open.

### Captured marketing follow-up configuration — 2026-10-27

Migration151 adds tenant-scoped sales team, 1–30 business-day deadline (default1), and automatic/review mode (default automatic) to campaign versions. Active-team/draft guard protects configuration changes; rollback refuses configured data loss. API settings preserve omitted fields and support explicit team clearing, return the saved settings and capture them through existing snapshot/hash/clone settings flow. Marketing publication preflight requires an active sales team. Follow-up preflight now deduplicates all team IDs, fixing false unavailability when callback and survey/sales use the same team. Survey campaigns do not execute marketing rules; retained marketing settings are dormant when the campaign type changes.

Client campaign editor shows sales configuration only for marketing. A shared follow-up settings component replaces the callback-only component and retains paging, saved-selection fallback, loading/error/empty and locked-save behavior; review mode is explicit and uncertain interest always requires review. Shared API team lookup keeps tenant/active checks consistent.

Local haisly_caller backed up and migrated through151; OpenAPI regenerated. Source integration assertions cover setting persistence, snapshot capture, omitted-field preservation and unknown sales team rejection. UI test source covers sales selection, review mode, callback-field independence and locked controls. Tests/typecheck/lint/build/browser deferred per user instruction. Durable interest result/confirmation, actual lead/task materialization, correction/review workflows and end-to-end acceptance remain open; F09-T02 and overall goal are not complete. No live calls/deployment.

### Durable marketing result observations — 2026-10-27

Migration152 adds immutable marketing-result revisions linked by tenant-scoped FKs to the runtime binding, target and immutable snapshot. A tenant-serialized insert guard requires an active correlated outbound marketing call and unchanged contact identity, evidence timestamp within the started conversation, the next target/snapshot revision and nondecreasing observation time. Unique binding/request keys prevent duplicate observation records. Business outcome and human/voicemail/unknown connection classification are separate; request type is allowed only on interested outcomes. Rollback refuses populated history loss.

Internal MarketingResultStore resolves trusted runtime context, hashes each request, returns original same-key replay, rejects conflicting reuse/stale expected version, appends the revision and minimal audit atomically, and reads the current target/snapshot result. Observer authenticity and human classification must be verified by the caller; no model/public endpoint is wired to this primitive. Observations have no granted-consent field, and current reads explicitly report not_requested. This is active-conversation observation persistence, not the finalized-call correction path or automatic lead creation.

Local haisly_caller backed up and migrated through152. Added source validation cases for structured outcomes, ownership/consent injection rejection, revision bounds and evidence shape. Tests/typecheck/lint/build and positive DB/replay/concurrency tests remain deferred. Durable consent challenge/consumption, finalized-result reconciliation, result outbox, lead/task materialization and UI remain outstanding. No client runtime/API contract or provider connection changes. F09-T01/T02 and full goal remain open.

### Durable marketing interest confirmation — 2026-10-27

Migration153 persists a five-minute readback challenge for a specific marketing result revision and bound runtime conversation. DB guards require the current explicit human interest result, matching request/language/captured campaign name, active correlated call and unchanged contact identity. Challenge scope/timing is immutable; one settled granted/denied/unknown decision per result and unique response-event use per conversation prevent repeated or substituted evidence. Resolved history cannot be edited/deleted; populated rollback refuses data loss.

Internal MarketingConfirmationStore issues/reuses unexpired challenges without extending expiry, derives scope and subject from trusted runtime/snapshot, rechecks exact digest and current result before settling, and treats exact repeated evidence as replay. Current result reads derive confirmation from that revision only; unresolved evidence maps to unknown and a new result starts without confirmation. Minimal audit contains identifiers/version/decision, not spoken content. The subject currently uses the captured campaign name. No public/model endpoint or real provider observer is wired; a trusted caller must verify provider signatures and speech interpretation. This does not yet materialize a lead/task.

Local haisly_caller backed up and migrated through153. Added bound-runtime integration source for result/confirmation replay, wrong environment, changed revision, conflicting evidence, immutable settled decisions and no consent carry-over. Tests/typecheck/lint/build remain unrun until final batch. Durable result events, finalized-call corrections, review/action materialization and UI remain open; F9/goal incomplete. Client runtime unchanged; no live calls/deployment.

### Confirmed marketing interest materializes one opportunity and task — 2026-10-27

Migration154 adds immutable marketing lead/task provenance unique per tenant/target/snapshot, with tenant FKs for result, granted confirmation, captured team, lead and task. Insert guard requires the latest human interest result, automatic snapshot rule, current contact identity, matching source call, lead/task contact/assignee and creation after consent. Populated rollback refuses history loss.

Internal materializer resolves the authenticated environment and latest result, evaluates the captured rule/settled proof, allocates the existing round-robin team, and creates lead, linked follow-up task, provenance, notification intent and audit in one transaction. Deadline uses the captured business-day count from confirmation time; empty teams use the unassigned queue. Replay returns the same public IDs without allocating/notifying again. Later result corrections annotate existing lead/task metadata and audit without resetting human status, owner, deadline or completion. Identity-unavailable/stale/configuration-unavailable results do not create actions; review outcomes await the review workflow.

Manual task assignment resolves marketing team from the immutable ledger; independent notification delivery recognizes its source environment. Local haisly_caller backed up and migrated through154. Extended bound-runtime source fixtures for configured sales queue, before-consent noncreation, same-action replay, wrong environment, task/lead link, single notification, team provenance and correction preservation. Tests/typecheck/lint/build not run per user instruction. Automatic event/worker wiring, human review mode, finalized-call corrections, lead-specific visibility/assignment review and UI acceptance remain pending. Client runtime unchanged. F9/overall goal incomplete; no live calls/deployment.

### Durable marketing events and bounded action consumer — 2026-10-27

Result revisions and settled confirmations now atomically emit server-owned caller.marketing.changed.v1 outbox events containing only public references and transition kind. Deterministic keys and payload conflict checks deduplicate replays; exact result/decision replay can repair a missing event without another business write. External event publishers are forbidden from using the topic. Consumer resolves actual stored result/settled proof rather than accepting payload consent/identity claims.

Migration155 adds independent marketing action receipts (pending/succeeded/needs_review/dead_letter), preserving shared outbox transport for other consumers. Internal per-environment drain takes one event under tenant lock, materializes within a savepoint and retries failures up to five attempts with bounded backoff. Failed materialization rolls back lead/task/team cursor changes; only sanitized processing_failed is retained. Review outcomes are excluded from automatic retries. Historical review receipts remain event-specific; the future review UI must resolve current result/decision, not count old receipts as active review work.

Local haisly_caller backed up and migrated through155. Source tests cover reserved topic, strict reference-only payloads, one event per transition, wrong environment, review receipt and exactly-once task creation via drain. Tests/typecheck/lint/build remain deferred. Runtime endpoint/scheduler, retry/review UI, failure/concurrency acceptance, historical event backfill and remaining F9 tasks are not complete. Client runtime unchanged. No workers enabled or live calls/deployment.

### Marketing action runtime and optional monitor — 2026-10-27

Added POST /api/internal/v1/marketing-actions/drain requiring a signed runtime account with runtime.marketing.actions.process. Tenant/environment are authentication-derived; strict empty body, 1 KiB limit, no-store on errors/success and sensitive rate limiting apply. The endpoint processes one marketing event, commits its action/receipt, then drains one task notification in a separate transaction. Notification failure preserves created count and review-required state. Callback and marketing reuse the same transaction/status orchestration and monitor loop to preserve consistent recovery behavior.

CALLER_MARKETING_ACTIONS_ENABLED defaults false and requires CALLER_WORKER_ENABLED. The optional monitor polls every10s idle/1s after processed or review work, aborts on shutdown, records scans/created/failures/dead letters/review encounters, and participates in the30s readiness freshness check. Counters are cumulative observations, not current queue backlog. It emits only bounded sanitized events. No worker was started or configuration enabled. Before enabling, deploy DB through155 and matching API/worker, grant the scoped runtime account, and inspect failed/review receipts; disable the marketing flag to stop automatic consumption while retaining queued events and receipts.

OpenAPI regenerated. Added source tests for anonymous/missing/denied scope, authorized empty drain, spoofed body/oversize rejection, default-off config, monitor statuses/failures/abort. Tests/typecheck/lint/build remain deferred. Human review/retry screens, provider observation adapters, finalized-call correction and full acceptance remain open. No DB migration or client runtime change; DB stays155. Goal incomplete.

### Human marketing review decision API — 2026-10-28

Migration156 adds immutable tenant-scoped result review decisions with reviewer, bounded reason and DB timestamp. Guards require current human evidence, unchanged contact identity, active tenant membership and no prior action. Approval requires captured review mode plus explicit settled customer confirmation; uncertain/unconfirmed interest can be rejected but human approval cannot manufacture consent. Marketing action provenance now accepts approved review-mode results and rejects rejected results.

POST /api/v1/marketing-results/:public_id/review requires campaign-read and task-assignment permissions, result-version If-Match and an idempotency key. Review approval, opportunity/task allocation, audit and review event commit atomically; failures roll back the decision too. Existing actions cannot be reviewed again. The marketing consumer verifies review events against stored decisions; rejected results create no action. Strict body, 4 KiB limit, sensitive rate limit and no-store apply. OpenAPI regenerated.

Local haisly_caller backed up and migrated through156. Added source coverage for rejection of approval without customer confirmation, immutable review history, strict payload/event schemas, anonymous access and missing records. Tests/typecheck/lint/build remain deferred by user instruction; positive approval/replay/concurrency acceptance remains outstanding. Client runtime unchanged: review listing/detail/UI, uncertain-interest human follow-up, retry recovery and remaining F9 work are still open. No provider connection, worker enablement, live calls or deployment. Overall goal remains active.

### Marketing pending-review reads — 2026-10-28

Added tenant-authorized GET /api/v1/marketing-results/reviews and GET /api/v1/marketing-results/:public_id/review. Both require campaign-read and task-assignment permissions. Pending work is derived directly from the latest human result, settled confirmation, current contact identity and absence of a review/action, rather than historical delivery receipts. Denied, non-interest, superseded, resolved and identity-changed evidence is excluded. UUID keyset pagination is bounded to100; DTOs expose campaign/snapshot/result references, request, confirmation state, evidence time, reason and evidence-based approval eligibility, without phone/contact PII, internal IDs or provider event references. Reads are snapshots; the mutation still rechecks under lock.

OpenAPI regenerated; source assertions added for query bounds, unknown filters, unauthenticated/no-store, empty authorized list and missing detail. Tests/typecheck/lint/build remain deferred. Positive populated pagination/isolation and concurrent mutation acceptance are pending. No DB migration; local schema remains156. Client screens still pending, with no runtime client change in this slice. F9 and full goal remain incomplete; no live service calls or deployment.

### Marketing review client workflow — 2026-10-28

Added /app/marketing-reviews with localized sidebar/title and both campaign-read/task-assignment route and page permission gates. Central RTK Query endpoints consume the pending list/detail and versioned decision API. The responsive queue supports refresh/keyset paging, loading/error/empty states and a retained evidence panel. Review shows captured campaign, request, customer confirmation, result revision and deadline; evidence-ineligible approval is disabled and guarded in submit. Rejection remains available. A bounded reason and explicit acknowledgement are required; success links to the created task.

The already-confirmed request is preserved in actor/tenant-scoped session storage under a separate marketing namespace. Unknown network outcomes lock editing and retain the exact key/version/payload for explicit retry, including after remount when the result has left the queue. Storage failure blocks new submissions; definitive failures require current evidence. Evidence/contact data and credentials are not copied into pending storage. Marketing cache invalidates task/notification/audit views after decisions.

Added unrun source tests for form validation, absent-confirmation approval restriction, exact retry after unknown outcome, pending recovery and actor-scoped storage. No tests/typecheck/lint/build/browser were run per user instruction. Browser/mobile/accessibility verification, populated API acceptance, team-unavailability UX, uncertain-interest follow-up and remaining F9 tasks remain outstanding. DB stays156; no migration, provider calls or deployment. Full goal remains active.

### Marketing review team availability — 2026-10-28

Review list/detail now resolve the captured sales team within the same tenant and expose its name/availability. Approval eligibility requires both confirmed customer evidence and an available team; the evidence reason remains confirmed_interest when only the team is unavailable. The decision endpoint checks and share-locks the active captured team before recording approval. Rejection is unaffected by archived teams. Client shows team availability separately from consent, preventing a misleading missing-consent message for a confirmed request with an archived team.

OpenAPI regenerated. Added unrun screen coverage for unavailable-team messaging/disabled approval/available rejection and API source assertions that assigned-task-only users cannot list/read/decide marketing reviews. Tests/typecheck/lint/build/browser remain deferred. Populated API concurrency/approval acceptance and the remaining F9 workflows are still pending. DB remains156; no migration or live service changes. Overall goal active.

### Marketing exhausted-processing recovery API — 2026-10-28

Migration157 adds monotonic DB-managed versions to marketing consumer receipts and an exhausted-processing index. Every receipt update increments version and sets DB update time. Local haisly_caller was backed up and migrated through157. The worker continues its existing five-attempt bound; shared outbox transport is unaffected.

GET /api/v1/marketing-actions/failures lists tenant-scoped dead-letter receipts with UUID pagination and sanitized error code, attempt count, version and time. POST /api/v1/marketing-actions/:public_id/processing/retry requires campaign-edit and task-assignment permissions, If-Match, idempotency key and bounded reason. Tenant/row locking plus version checks reject stale requests; only dead-letter receipts reset to pending with zero attempts. Needs-review, succeeded and pending receipts cannot be forced through. Audit records actor/reason/state; exact replay returns the original result. Requeue places no call and does not bypass the worker's evidence checks. Strict body/4KiB/no-store/rate limiting apply.

OpenAPI regenerated. Unrun source tests cover bounded query/reason, injected state rejection, anonymous/assigned-only denial, empty owner list and missing receipt. Tests/typecheck/lint/build remain deferred. Positive retry/replay/concurrency acceptance and client recovery UI remain pending. No worker enabled, live provider connection or deployment. F9 and overall goal remain active.

### Marketing processing recovery screen — 2026-10-28

Added /app/marketing-failures with localized navigation/title, route/page gates for campaign-edit and task-assignment, central RTK Query list/retry endpoints and bounded UUID paging. Queue displays processing time and exhausted attempts with loading/error/empty states. Requeue requires a bounded reason and explicit confirmation; copy explains that current evidence is evaluated again, eligible outcomes may create a lead/task, and requeue neither confirms completion nor places a call.

Actor/tenant-scoped pending storage retains the exact event/version/key/reason in a dedicated namespace. Unknown results remain locked for explicit same-request retry, including after reload; no automatic POST occurs on mount. Storage failure blocks submission, definitive failure clears only the matching pending request, and successful requeue refreshes the failure cache/audit view. Existing notification recovery remains unchanged.

Added unrun model, screen and transport test sources for confirmation, bounded reason, isolation/corrupt storage, frozen replay after network failure, reload recovery and quoted If-Match/idempotency headers. Tests/typecheck/lint/build/browser remain deferred. Populated API recovery/concurrency acceptance, browser accessibility/responsiveness and other F9 tasks remain pending. API/DB unchanged except progress notes; schema157. No live calls/deployment. Goal active.

### Assigned opportunity read isolation — 2026-10-28

Lead list/detail and event list/detail now use the existing caller task authorization model: caller.tasks.assign grants tenant-wide reads; caller.tasks.assigned restricts reads to leads owned by the actor. tenant.read alone no longer grants these reads. Ownership filters are applied inside result queries, including history joins, so task assignment alone does not expose another person's lead. Unassigned/other-owned detail and history return not-found. Existing contact identity filtering is retained. Read endpoints set no-store; OpenAPI documents the scope.

Client lead navigation, route guards and badge fetching use these permissions instead of legacy sales.read. Source integration fixtures cover own lead/list/history access and hidden unassigned detail/history for an assigned-only role. Tests/typecheck/lint/build remain deferred. Manager lead assignment, employee lead state/note mutations, action controls and broader acceptance remain outstanding; existing write permissions were not expanded. This is read isolation only, not completion of F09-T03/T05. No migration/schema change (157), provider calls or deployment. Goal active.

### Opportunity version contract — 2026-10-28

Migration158 adds a positive monotonic lead version, incremented by the database on every update (including legacy writes and automated result corrections), with overflow refusal. Added tenant/owner/creation index for scoped employee reads. Local haisly_caller backed up and migrated through158. API list/detail mapper, OpenAPI Lead schema and client LeadRead type now expose the required version; no timestamp is used as a concurrency token.

Source integration assertions cover version1 on creation/version2 after a write. Corrected the preceding ownership-list assertions to use the actual public response key lead_public_id instead of public_id. Tests/typecheck/lint/build remain deferred. This prepares optimistic concurrency only: assignment/status/convert endpoints still need version/idempotency enforcement and corresponding client recovery work; no claim of protected legacy writes. No provider connection or deployment. Goal and F9 remain active.

### Versioned opportunity status updates — 2026-10-28

POST lead status now requires Idempotency-Key and quoted If-Match. Under the tenant lock it reauthorizes manager/assigned-owner access and locks the lead before inspecting replay receipts; losing ownership prevents replay access. Stale versions/conflicting or expired keys fail. Status write, audit and minimal receipt commit together; exact same state does not increment version or duplicate audit, repeated conversion preserves its time, and reopening clears converted_at. Replay returns current authorized state without reapplying the old command. Route adds 4KiB/no-store/sensitive-rate protection; OpenAPI updated. Assignment and convert remain separate legacy writes pending their migration.

Client status requests carry the displayed lead version. Actor-scoped pending state retains exact key/version/status and blocks new status submissions on uncertain outcomes/storage failure. Page-level recovery remains available after drawer closure/reload without automatic submission; explicit retry uses the stored request. Definitive rejection requests reopening current evidence. Existing status form is disabled while recovery is pending.

Added unrun API source assertions for owned status update, replay, stale version and replay after ownership removal; updated resource fixture headers. Client hook source tests cover uncertain retry and mount recovery. Tests/typecheck/lint/build/browser remain deferred. Full assignment/convert protection, permissions on remaining action controls and broad concurrency acceptance are pending. DB158 unchanged. No live calls/deployment; F9 and goal active.

### Versioned opportunity ownership changes — 2026-10-28

Lead assignment now requires caller.tasks.assign, Idempotency-Key and lead-version If-Match, with tenant/row locking, bounded body/no-store/rate limit and transactional audit/receipt. Converted/disqualified/lost opportunities reject assignment. Active tenant/user membership and assigned-work permission are locked for a selected owner. Campaign-generated opportunities additionally require available membership in the immutable marketing action's captured sales team, with an active team. Null ownership returns an open opportunity to the unassigned queue. Same owner preserves version; same-key replay returns the original response after authorization. Linked task ownership remains independent.

Client assignment carries displayed version and shares the status workflow's actor-scoped pending request recovery. Assignment and status cannot overwrite one another's unresolved request; replay routes to the original operation with the original key/body/version. Existing saved status requests remain readable. Added unrun source cases for assignment replay/permission loss and uncertain assignment recovery; resource fixture sends required headers. OpenAPI regenerated; tests/typecheck/lint/build/browser remain deferred.

Owner candidate discovery/UI still uses the previous limited options and needs captured-team paging; convert remains a legacy write and action visibility needs completion. Assignment notification semantics and populated team/concurrency acceptance remain open. No migration (DB158), calls or deployment. F9 and overall goal active.

### Eligible opportunity owner selection — 2026-10-28

GET /api/v1/leads/:lead_public_id/assignees now requires assignment management and returns a bounded UUID-paged list of active tenant/user memberships with assigned-work permission. Marketing provenance restricts candidates to available members of the active captured sales team. Closed opportunities return assignable=false. The response includes lead version; no contact details or internal IDs are returned. Assignment remains authoritative and rechecks membership/permission/version at write time. OpenAPI regenerated.

Replaced the lead edit drawer's current-user-only owner selector with a dedicated query-backed component. It handles fetching/error/empty/closed states, paging, explicit unassigned selection and refresh. No owner is selected by default; submission uses the version from the candidate view and the existing pending-command recovery. The component is shown only to assignment managers. Removed obsolete assignment form/state orchestration while preserving manual-create defaults.

Added unrun source checks for authorized candidate listing, anonymous/assigned-only denial, invalid limit, explicit UI selection and closed opportunity controls. Tests/typecheck/lint/build/browser remain deferred. Populated captured-team membership/pagination race acceptance, assignment notices, remaining action visibility and convert protection remain outstanding. DB158 unchanged; no live calls/deployment. F9 and goal active.

### Versioned opportunity conversion — 2026-10-28

Lead conversion now requires assignment-management permission and versioned mutation headers. Under tenant/lead locks it rejects stale versions and changed/archived bound identities; an associated opportunity cannot be moved to another contact. Null/omitted contact preserves the existing association instead of clearing it. Binding a previously unbound lead requires caller.contacts.manage and an active same-tenant contact. Conversion/audit/receipt commit atomically, unchanged conversion preserves timestamp/version, and replay returns the original authorized command response. Existing DB relationship/identity guards remain authoritative. Route adds bounded body/no-store/rate protection; OpenAPI regenerated.

Client conversion uses the shared actor-scoped pending-command recovery with original version/key/body and the correct endpoint on replay. Assignment/status/conversion cannot overwrite one unresolved command. Conversion controls are manager-only; contact selection locks for an existing association or missing contact-management permission. Added unrun source assertions for null association preservation, conversion timestamp/version preservation, replay, reassociation rejection, assigned-only denial and uncertain client conversion recovery. Tests/typecheck/lint/build/browser remain deferred.

No migration (DB158), provider connection or deployment. Broader lead action visibility, note workflow, assignment notices, end-to-end concurrency/identity acceptance and remaining F9/later phases remain open. Goal active.

### Opportunity UI privileges and CSV cell protection — 2026-10-28

Centralized lead UI control permissions. Assigned-only employees no longer see manual-create/export controls or trigger the tenant-wide customer lookup. Create route/handler require assignment-management plus the existing tenant.manage creation privilege; contact options load only for authorized contact managers with an open create/edit drawer. Assignment/conversion share the centralized management gate, while owned status editing remains available. Export control requires explicit caller.contacts.export.

The existing client-only CSV generator now neutralizes textual formula prefixes (including leading whitespace/control characters) before quoting, preserves typed numbers, and uses a .csv extension and text/csv MIME rather than labeling CSV as Excel binary. Added unrun permission-matrix and hostile-cell regression sources. This is UI/data-format hardening, not server-audited export completion: the report/export service and audit requirement remain pending for F12. No backend permission claim is inferred from hidden buttons; existing APIs remain authoritative.

Tests/typecheck/lint/build/browser remain deferred. Lead note workflow, assignment notices and full UI/API acceptance are still outstanding. API/DB progress notes only; schema158. No live calls/deployment. Goal active.

### Opportunity note API — 2026-10-28

Added POST /api/v1/leads/:lead_public_id/notes with strict note-only payload (trimmed 1–4000 characters), required Idempotency-Key, 8 KiB body cap, sensitive rate limiting and no-store responses. Managers can append to tenant opportunities; assigned-only staff can append only to their current opportunities. Actor, event type and timestamp are server-owned. The existing lead_events history stores notes; arbitrary legacy event writes remain tenant.manage-only.

Tenant/lead locking, access-before-receipt lookup, payload hash and atomic event/audit/receipt writes prevent duplicate notes on concurrent replay. Receipts and audit contain only event references, not note text. Notes do not change lead version, so append-only history does not invalidate an unrelated status edit. Reassignment revokes replay access. Expired/conflicting keys require history reconciliation.

OpenAPI regenerated; integration source scenarios added for concurrent replay, one event/audit, hidden-owner denial, reassignment replay denial, malformed/mass-assignment inputs, unauthenticated requests and note text exclusion from audit. These tests were not executed. All tests/typecheck/lint/build/browser remain deferred per user instruction. DB schema remains158, no migration required. Client note composer/recovery, history pagination, assignment notices and later phases remain pending. DB/client commits record progress only. No provider connections, calls or deployment; goal remains active.

### Opportunity note client — 2026-10-28

Connected the lead detail follow-up note composer to the dedicated notes API. Shared strict schema trims and bounds notes, current-detail/error gates prevent use of a previous opportunity response, and the shared actor/tenant-scoped pending-command mechanism stores the original note/key in tab-local session storage before sending. Uncertain requests lock other opportunity mutations; reload does not automatically submit. Explicit recovery uses the notes endpoint and original key. Successful direct submission or recovery clears the matching visible draft; rejected requests retain draft text. The API remains the ownership authority.

Added unexecuted component/recovery sources for blank-note rejection, trimmed note submission without version, locked fields, recovery draft cleanup, reload and same-key replay. Existing legacy generic event API is not used for notes. Test/typecheck/lint/build/browser execution remains deferred. History pagination and assignment notifications remain open, as do outstanding F9 and later-phase work. API/DB progress-only commits; schema158 unchanged. No external provider calls or deployment. Goal active.

### Opportunity history pagination — 2026-10-28

Lead event history now returns newest recorded events first (internal insertion sequence, not user-supplied occurred_at) with a public next_cursor and before query. Existing data array remains; next_cursor is an added response field. Default page50, maximum500. Cursor lookup is tenant/opportunity-scoped; actual data query reapplies owner isolation. Limit+1 determines whether another page exists. Newer arrivals do not shift the boundary of an older-page query; this is a live view, not an export snapshot. Unknown/foreign cursor returns404.

Client history moved into a dedicated component with current-response data, loading/error/empty states, retry, older/previous/latest controls and escaped note text. A confirmed note resets history to latest. Added unrun API scenarios for page order, newer arrival between pages, end cursor and foreign/invalid cursor; UI sources cover navigation and suppressing stale data on error. OpenAPI regenerated. Migration159 adds tenant/lead/id index; local haisly_caller was backed up before applying. Rollback drops index only. All tests/typecheck/lint/build/browser remain deferred. Final acceptance, assignment notifications and remaining phases stay open. No live provider calls/deployment; goal active.

### Opportunity reassignment notifications — 2026-10-28

Changed opportunity ownership now writes inbox-only lead notifications atomically with assignment/audit/idempotency receipt. Eligible active new owners receive the assignment notice; returning a lead to the unassigned queue notifies active assignment managers. Shared task/lead recipient selection enforces active tenant membership, user and role state and task assignment/assigned permissions. Same-owner writes and same-key replay create no duplicate notice. Messages use generic localized text and a public opportunity link without customer/title/note data. Current detail ownership remains authoritative after later reassignment.

These are local inbox writes through the existing writer, with no push/network side effect or new worker/outbox. Failure rolls back the assignment and callers retry with the same key. Existing campaign materialization still queues its linked task notification; this change covers explicit opportunity reassignment and does not add a second initial campaign notification. Task notification drain behavior is preserved through extraction of its recipient query. Client assignment invalidates inbox/audit caches.

OpenAPI regenerated. Unrun integration scenarios cover assignment, same-key replay, same-owner no-op, release-to-manager and safe notice metadata/body. DB schema159 unchanged. All tests/typecheck/lint/build/browser remain deferred. Full acceptance, remaining F9 work and subsequent phases are still outstanding; goal active. No external messages, calls or deployment were performed.

### Finalized marketing evidence revisions — 2026-10-28

Added separate trusted MarketingResultStore recordFinalized/readFinalized entry points, backed by a lifecycle-aware bound context resolver. Active runtime tools still use the original active-call resolver. Finalized mode requires terminal call and runtime session, matching tenant/environment, dispatch/target/snapshot/release/agent/phone/provider identity and current contact revision. It never closes a call, grants consent or invokes a provider. Immutable marketing revisions carry observation_phase; evidence time must be within the accepted call window and both terminal timestamps, with no future dates. Active phase behavior and existing active request hashes are preserved.

The existing ordered expected-version, request-key replay, audit and deterministic marketing outbox path handles late revisions. New revisions do not inherit confirmation. Existing action materialization annotates the same lead/task without resetting human status, owner or deadline. Added unrun bound-fixture scenarios for rejecting finalized writes during active calls, rejecting active writes after closure, wrong environment, finalized replay, no consent carry-over, existing action preservation and post-call evidence time rejection.

Migration160 applied to backed-up local haisly_caller. Rollback refuses to drop provenance when finalized evidence exists; use roll-forward remediation then. API deploy requires160 first. This is the internal evidence persistence/reconciliation primitive, not completed provider finalization: authenticated provider observation wiring, separated final call/survey/quality projection, UI and end-to-end acceptance remain open. Client progress-only update. Tests/typecheck/lint/build/browser remain deferred. No live calls, external provider connection or deployment; F09-T01/T02 and overall goal remain incomplete.

### Separated persisted call outcome API — 2026-10-28

Added GET /api/v1/calls/:call_public_id/outcomes under calls.read with tenant isolation, no-store and a repeatable-read projection. Response separates stored call connection status/classification from the latest marketing outcome for that exact runtime binding and its revision-specific confirmation. Public campaign/target/snapshot/release/session context identifies attribution. Survey progress explicitly carries target_snapshot scope: it is current shared survey state and must not be presented as an immutable per-call answer snapshot. Multiple bindings return409 rather than silently choosing one; unbound legacy calls have null context/results.

The response contains no transcript, answer values, evidence references, customer content or internal IDs. Missing marketing/survey data stays null. Quality remains null pending the evaluation projection; no success/evaluation is inferred from call completion. This endpoint is a current persisted-state read, not a finalization certificate or provider observation writer.

OpenAPI generated; added unrun bound-result source assertions for completed-call/noninterested separation, revision3/no inherited consent, source context and wrong tenant, plus HTTP authentication/permission/missing-call/no-store scenarios. Tests/typecheck/lint/build/browser remain deferred. DB160 unchanged; client integration, final result snapshot/quality, provider observation wiring and all later open tasks remain pending. Goal active; no live calls or deployment.

### Call outcome client summary — 2026-10-28

Outbound call detail summary now reads the separated outcomes endpoint through the central RTK Query API. It shows connection status/classification independently of marketing interest, request, revision-specific confirmation and observation stage. Missing results are explicitly not recorded; quality remains unavailable, not scored. Survey progress is clearly described as current target/campaign-version state that may include later call continuation. Legacy unbound calls are labelled without campaign results.

Dedicated component uses only matching current-response data, hides cached outcomes on error, supports loading and explicit refresh, and is mounted only for the current outbound detail. Added unrun component source cases for completed/noninterested separation, absent confirmation, survey scope, absent observation, access error and stale other-call response. No transcript/answer content or evidence references are fetched by this component.

API/DB progress-only commits; schema160 unchanged. Tests/typecheck/lint/build/browser remain deferred, including responsive and accessibility verification. Provider observation/finalization wiring, immutable final result/quality projection and remaining phases still open. Goal active; no live calls/deployment.

### Verified dispatch end closes bound call/session — 2026-10-28

recordDispatchEvent now reconciles the authoritative ended dispatch into its exact runtime-bound call/session on first observation and on receipt replay. Tenant lock, row locks, provider reference, outbound number/direction, terminal timestamps and start/end ordering are checked before writes. Definitive transport end reasons map to call/session lifecycle statuses only; voicemail/completed never imply customer interest, consent, survey completion or settled cost. Existing duration/cost/metadata remain untouched.

Matching already-closed rows return unchanged. Missing bindings return unbound for later materialization/reconciliation. Multiple bindings, contradictory existing terminal facts or invalid end times return needs_review and write one deduplicated audit warning without overwriting call facts or rolling back the valid dispatch receipt. A subsequent replay re-evaluates the mapping. Successful closure is atomic with the event receipt and enables the previously added finalized-result evidence path.

Bound-marketing fixture source now uses a normalized verified end event instead of directly closing call/session rows; added source assertions for replay, closure and conflict preservation/deduplicated review plus transport-status mappings. These sources were not run. Tests/typecheck/lint/build/browser remain deferred. No schema change (160), no live webhook/provider call or deployment. Adapter authentication/mapping and late unbound materialization, immutable final results/quality and later phases still require work; goal active. Client/DB progress notes only.

### Interrupted survey on verified call end — 2026-10-28

Successful bound call-end reconciliation now pauses an active survey using the existing versioned survey transition and deterministic survey-changed outbox path. It preserves answer revisions, emits a pause event and minimal audit, and does not create a survey when one was never started. Completed, declined and already partial surveys are unchanged; replay does not increase version or append another event. The same transaction commits survey pause, call/session closure and provider receipt.

Target/snapshot/current identity guards prevent altering a historical identity. A later accepted attempt for the same target/snapshot supersedes the old end observation, so late events/replays cannot pause newer-call work. Resumption continues to require the existing explicit consent flow. Added unrun bound-survey sources for interrupted partial/version preservation, event replay and preserving completed surveys. Later-attempt concurrency and full provider acceptance remain final verification work.

No migration (DB160) or client runtime change; the outcome summary already reads survey state. Tests/typecheck/lint/build/browser remain deferred. Provider observation authentication/mapping, late unbound lifecycle creation, immutable final results/quality and remaining phases stay open. Goal active; no live calls or deployment.

### Immutable initial call-end snapshot — 2026-10-28

Migration161 adds caller_call_end_snapshots, unique per tenant/runtime binding, with database-derived dispatch/call/target/snapshot references, stored end fact/status, the known marketing result version and confirmation, and survey state/version/revision count. Its trigger requires a closed matching provider-bound outbound call/session and derives fields from authoritative rows under the tenant lock; update/delete are rejected. It stores no transcript, answer text or raw evidence payload. Later accepted attempts suppress attribution of shared survey state to the older call (superseded).

Successful verified end reconciliation captures this initial snapshot in the same transaction after survey pause and call/session closure. Receipt replay returns the existing snapshot; late marketing corrections remain separate revisions and do not overwrite the initial view. captured_at distinguishes observation processing time from provider ended_at; this is the first processed closure snapshot, not a claim that every business/quality result was already available at physical hang-up. Audit records snapshot creation once.

Local haisly_caller backed up and migrated161. API requires161 before deployment; rollback refuses to erase existing snapshots. Retention/purge handling remains F13 work. Added unrun source assertions for one snapshot on replay, frozen marketing version2 despite later version3, immutability, and partial/completed survey snapshots. Tests/typecheck/lint/build/browser remain deferred. Public snapshot projection/UI, final correction history/quality and provider acceptance remain outstanding, along with later phases. Client progress notes only. No live calls/deployment; goal active.

### Initial closure versus current outcomes — 2026-10-28

Call outcomes API now includes nullable initial_end from the tenant/call/runtime-bound immutable snapshot. Its marketing result joins the pinned immutable revision, and confirmation is read from the frozen snapshot rather than live consent. It exposes provider end time separately from processing capture time, end reason, call status and captured survey attribution/version/state/revision count. No internal IDs, answer text or evidence payloads are added. Existing calls.read and repeatable-read/no-store boundaries apply.

Outbound detail displays Initial closure record separately from Current outcomes. Missing closure is labelled, and later-attempt survey suppression is explained without presenting later survey data as an old call result. Added unrun bound-source assertions that current marketing version3/not_interested remains distinct from frozen version2/interested/no confirmation, and client cases for frozen view, absent record and superseded survey attribution. OpenAPI regenerated.

Schema161 unchanged. Tests/typecheck/lint/build/browser remain deferred. This exposes initial closure provenance; it does not complete provider ingestion, quality evaluation, correction history or full F9/later-phase acceptance. Goal active; no live calls or deployment.


### Quality rubric calculation foundation — 2026-10-28

Added a pure internal quality calculator with the spec's 30/25/20/25 default weights, integer 0–100 dimension scores, strict total-100 weight validation and bounded UUID evidence references. Missing weighted evidence yields a null score rather than renormalizing available dimensions; coverage and missing dimensions are explicit. Zero-weight missing dimensions still require review. Critical do-not-call and tool-authorization checks are mandatory regardless of weights. Only verified-event violations appear in critical_violations; unknown checks and model-only claims require review. A high numerical score never clears a critical violation.

This is calculation infrastructure only, not a public evidence-ingestion boundary: verified_event must be derived from authoritative tenant/call-bound records by the future orchestrator, never accepted from a model or client. No endpoint, campaign pause, persistence, rolling-window alert or user-visible quality result was enabled. Existing policy_evaluation_logs remain unchanged. Call outcomes still returns quality:null until a persisted verified evaluation exists. Schema remains161; DB/client runtime unchanged.

Added unrun unit sources for weighted scores, missing evidence, zero-weight critical checks, model claims and invalid inputs. Tests/typecheck/lint/build/browser remain deferred by user instruction. Remaining F12-T04: evidence resolution/provenance, immutable evaluations and captured tenant weights, audited review/correction, verified-critical pause integration, last20 warning and UI. No live provider connection/deployment. Goal active.


### Immutable model quality revisions — 2026-10-28

Migration162 adds caller_quality_assessment_revisions with tenant/runtime-binding revision and idempotency uniqueness, tenant-safe call/snapshot foreign keys, and bounded evaluator reference. Insert requires a captured bound call end; DB derives call/snapshot, serializes contiguous revisions under the tenant lock, derives score/coverage/missing dimensions independently and rejects update/delete. Evidence references currently support only immutable end snapshots and marketing result revisions of the exact tenant/runtime binding. Model critical checks cannot claim verified_event, and all model revisions require review with no verified critical flags.

API internal CallQualityRevisionStore.recordModel validates bounded strict payloads, checks closure/evidence ownership, preserves replay results after later revisions, rejects changed-payload keys and stale expected versions, and audits each new revision in the same transaction. UUID inputs normalize case. The future worker must supply captured weights/evaluator identity from trusted configuration, not model output; reference ownership alone does not prove semantic relevance. No model/provider invocation or public write endpoint was enabled.

Local haisly_caller backed up and migrated162. API deployment requires162. Rollback refuses to delete existing evaluation provenance; retention/purge integration remains F13. Added unrun bound-marketing fixture coverage for incomplete evaluation, revision/replay, stale/conflicting inputs, tenant/missing-evidence rejection, DB immutability and rejecting forged verified provenance. Tests/typecheck/lint/build/browser remain deferred. Client runtime/OpenAPI unchanged; outcomes quality remains null pending read/UI integration.

This does not complete F9/F12: tenant-weight configuration/capture, broader evidence sources, authenticated evaluator job orchestration, semantic evidence review, verified-critical enforcement, human correction/appeal, last20 warning and quality read/UI remain outstanding. No live calls or deployment; goal active.


### Call quality read projection and detail UI — 2026-10-28

The existing calls.read/no-store/repeatable-read outcomes endpoint now projects the latest immutable model quality revision for the exact tenant/call/runtime binding. It exposes public revision ID/version/time, model source, rubric version, nullable score, coverage, review requirement, dimension scores/captured weights and explicitly unverified critical-check claims. Explicit mapping omits evaluator identifiers, raw evidence references, internal IDs and assessment payload. Absent evaluation remains null; an incomplete weighted score is null rather than zero. OpenAPI regenerated.

Client call detail now renders a separate quality section with localized objective/survey labels, real zero versus absent-evidence distinction, weights/coverage and review requirement. Model compliance and violation claims are labelled unverified; a high score is not presented as permission verification or a campaign pause decision. Existing call-scoped currentData/error handling suppresses cached quality on access failure. No new fetch path or dependency.

Added unrun projection source assertions for latest revision and exact tenant/call/binding isolation, plus component sources for missing evaluation, incomplete score, real zero, high-score review, Turkish labels and cached quality suppression. Schema162 unchanged. Tests/typecheck/lint/build/browser remain deferred. Full evidence viewing, semantic verification, evaluator orchestration, tenant configuration/capture, human correction/appeal, verified-critical enforcement and last20 warning remain pending; this is not full quality acceptance. Goal active; no live calls/deployment.


### Campaign last20 quality window — 2026-10-28

Campaign operations now includes quality_window under existing caller.campaigns.read and repeatable-read/no-store behavior. The bounded result uses the latest quality revision per exact call binding BEFORE excluding null scores, orders eligible calls by immutable end time then call ID, and takes20 across campaign versions. Calls with ambiguous multiple runtime bindings are excluded. Revisions are not extra calls; a later incomplete correction removes the older score from eligibility. No person/evidence identifiers or raw payloads are returned.

The mean is withheld until20 scorable calls. Integer hundredths preserve exact <70 comparison, including69.9995 versus70; a full zero-score sample remains a real zero. Client operation summary displays sample size, incomplete-window state, unrounded mean (up to4 decimals), and an owner-review warning below70. At/above70 explicitly does not certify permission/safety; low scores do not pause a campaign. This is an on-screen warning, not yet a durable owner notification/review workflow.

Added unrun unit and UI cases for sample sizes0/19/20, zero/threshold/near-threshold, invalid scores, plus bound-source checks that revisions do not multiply calls, incomplete latest revisions suppress older scores, and other tenant/campaign reads are isolated. OpenAPI regenerated. Schema162 unchanged; no migration. Query plans/load, full20-call ordering fixture, durable owner notice/review, evaluator orchestration and verified-critical pause integration remain pending. Tests/typecheck/lint/build/browser deferred. Goal active; no live calls/deployment.


### Durable quality warning episodes and owner inbox — 2026-10-28

Migration163 adds caller_quality_alerts with one open episode per tenant/campaign, scoped opening/recovery revision references, frozen opening score/time and guarded one-way recovery/notification provenance. API quality revision persistence now reconciles the latest20-call window within the same tenant-locked transaction. Below70 opens one episode; continued low scores retain it; insufficient evidence cannot clear it. A complete at/above70 window records numerical recovery. A later decline can open a new episode. Score warnings never mutate campaign state.

An open low-score episode creates local inbox-only call notifications for active tenant owners with active membership and active nonrevoked owner roles. Notices use generic localized text and public campaign/alert references, linking to the related call. No customer details, external delivery or push. Episode notification timestamp and audit commit atomically with revision and notices, preventing repeated notices while the same episode remains open. No eligible owner leaves notification pending; later new revisions retry it while still below threshold. Independent retry after membership changes is not yet implemented.

Campaign operations exposes the persisted open episode and pending/notified state. Client keeps it visible when current evidence becomes insufficient and explains that inbox creation does not mean human review. Numerical recovery is separate from human acknowledgement/correction, which remains pending. OpenAPI regenerated.

Local haisly_caller backed up and migrated163; API requires163 before deployment. Rollback refuses to erase existing episodes. Added unrun transition-policy sources, insufficient-sample/no-alert integration assertions, and UI coverage of persistent warnings after evidence loss. Full20-call notification/recovery/concurrency/recipient integration fixture, independent pending delivery drain, human review, semantic evidence orchestration and final verification remain pending. Tests/typecheck/lint/build/browser deferred. Goal active; no live calls/deployment.


### Independent pending quality-notice drain — 2026-10-28

Migration164 adds due time and bounded error-code metadata to quality warnings, with an index for open unnotified episodes. New signed runtime POST /api/internal/v1/quality-alerts/drain requires runtime.quality.alerts.process, derives tenant/environment from authentication and restricts candidates by the opening revision's bound call environment. Empty strict body, 1KiB limit and no-store apply. One due episode is selected under a nonblocking tenant lock; campaign-wide quality and current active owners are rechecked before local inbox delivery. Reconciliation uses the newest campaign observation as its cause rather than falsely attributing recovery to the old opening revision.

No-owner/incomplete-evidence episodes and failed delivery are deferred five minutes so they do not monopolize the queue. A savepoint rolls back partial notifications/audit/recovery on failure before retaining generic retry metadata. Already notified/recovered episodes are excluded. Owner availability can therefore lead to delivery without another quality revision. Retry is ongoing with bounded cadence; no attempt limit discards an ownerless warning. A recovered window suppresses stale delivery, and incomplete evidence preserves the existing warning.

Worker CALLER_QUALITY_NOTICES_ENABLED defaults false, also requires CALLER_WORKER_ENABLED and the dedicated service-account scope. Reuses action monitor polling/abort/metrics and adds readiness gating. It performs no calls, model evaluation, external push or campaign pause. This switch was not enabled and no worker was started. OpenAPI regenerated.

Local haisly_caller backed up and migrated164. Disable this worker before API/schema rollback; rollback164 removes only retry scheduling metadata, preserving episodes and notices. Added unrun signed-route auth/scope/body-limit/no-store/idle sources, default-off config assertion and worker status/abort sources. Full pending-owner/recovery/rollback/concurrency integration fixture and runtime acceptance remain final verification work. Tests/typecheck/lint/build/browser deferred. Human quality review/correction, evaluator orchestration and remaining phases remain open; goal active.


### Owner acknowledgement of quality warnings — 2026-10-28

Migration165 adds one immutable reasoned owner review per tenant/alert with reviewer, server time and durable request key/hash. Active tenant owner, user and membership are required by the service before both new writes and replay; insert is independently guarded by the database. Alert and reviewer references are tenant scoped. Same actor/key/body returns the original review; a different owner/key/body conflicts. Review acknowledges immutable opening facts, so no mutable-campaign If-Match is required. Historical recovered alerts can be reviewed by ID. No score, preference, campaign state or numerical-recovery fields change.

POST /api/v1/quality-alerts/:public_id/review uses strict bounded reason/header/path validation, 8KiB limit, sensitive mutation limiting and no-store. Review creation and minimal audit commit together; reason text is not copied to audit. Campaign operations returns the review and reason for an open alert under existing campaign-read authorization. Reviewed episodes suppress still-pending new notices in both direct reconciliation and independent drain; existing inbox records remain.

Client shows the saved reason as escaped text and offers the editor only to an authenticated owner. The editor is keyed by tenant/user/alert, uses RHF/Zod, and is a button-based command inside the existing campaign form. The first request freezes its key/reason for explicit uncertain-response retry; unique alert review protects against duplication across reload. Mutation invalidates Campaign/AuditLog. Acknowledgement never removes the numerical warning. Review history after recovery and correction/appeal of the actual model assessment remain outstanding.

Local haisly_caller backed up and migrated165. API requires165 before deployment. Rollback refuses to erase reviews; retention/purge remains F13. Added unrun bounded/mass-assignment validation sources and UI invalid-reason/parent-form/uncertain-retry sources. Full owner/revoked-role/tenant/concurrent-review DB/API acceptance still required. Tests/typecheck/lint/build/browser deferred. OpenAPI regenerated. No live calls/deployment; goal active.


### Quality warning and owner review history — 2026-10-28

GET /api/v1/campaigns/:public_id/quality-alerts now exposes campaign-scoped warning history under caller.campaigns.read, repeatable-read and no-store. Newest recorded alert ID first, default25/max100, limit+1 keyset pagination with a public before cursor that must belong to the same tenant/campaign. Recovered episodes remain available with opening/recovery times and scores plus immutable owner reason/reviewer public ID. Reuses the open-alert query and explicit mapper; internal IDs/evidence/evaluator data remain omitted. Pages are a live view, not an export snapshot.

Client operation view lazily opens history with previous/older/latest/refresh controls, loading/error/empty states and escaped reasons. Recovery and human review are separately labelled. Active owners can acknowledge an unreviewed recovered alert using the existing immutable review command; open-alert review stays in the current operations section. History cache keys and component state are partitioned by tenant/user scope, and errors suppress cached notes. The viewer key is client cache context only and is not sent as authorization.

Added unrun query-boundary validation sources, API fixture assertions for anonymous/no-store/empty/invalid-limit/cursor behavior, and client sources for pagination, recovery distinction, escaped notes, stale-error suppression and owner-only historical editor. Full populated cross-tenant/campaign pagination, concurrent insert and review acceptance remain final verification work. OpenAPI regenerated. Schema165 unchanged; no migration. Tests/typecheck/lint/build/browser deferred. Model-assessment appeals/corrections, evaluator orchestration and remaining phases stay open; goal active.


### Owner correction of quality dimensions — 2026-10-28

Migration166 extends immutable quality revisions with assessment_source, preceding revision, reviewer and bounded correction reason. A separate insert guard requires the immediately preceding revision of the same bound call and an active tenant owner/membership; captured weights and mandatory checks must exactly match the base. Existing revision/evidence/score/immutability guards remain in force. Model observations retain their original default source. New observations and owner corrections remain ordered revisions, never overwrites.

POST /api/v1/quality-assessments/:public_id/corrections requires active owner authorization before replay, Idempotency-Key and quoted If-Match of the latest base. Strict body supplies only reason and four nullable dimension scores with bounded same-call end/marketing evidence references. Existing mandatory checks and weights are copied server-side. Actor/base/version/body hash protects replay; stale or conflicting requests fail. New revision, reason-free audit and recalculated campaign warning commit atomically. Shared owner guard now serves both acknowledgement and correction. Body limit64KiB and sensitive rate limit/no-store apply.

Call outcomes exposes model versus owner source and correction provenance/reason; the client labels and escapes this reason while still showing unchanged mandatory model checks as unverified. Campaign window source is now latest_assessment and its wording includes owner revisions. Missing evidence still produces null score, and owner score correction does not certify consent or trigger campaign pause. The dedicated evidence inspector and correction editor are not yet implemented; the API command and outcome display are this slice's boundary.

Local haisly_caller backed up and migrated166. API requires166; rollback refuses to erase corrections. Added unrun strict-body/version sources, DB fixture sources for owner provenance/unchanged mandatory review/frozen weights/nonowner rejection, and owner-source display coverage. Full correction HTTP replay/revoked-role/cross-tenant/stale concurrency acceptance remains pending. Tests/typecheck/lint/build/browser deferred. OpenAPI regenerated. Goal active; no live calls/deployment.


### Revision-pinned quality evidence inspection — 2026-10-28

Added GET /api/v1/calls/:call_public_id/quality/:revision_public_id/evidence under calls.read, exact tenant/call/revision lookup, repeatable read and no-store. It returns explicit assessment fields and bounded summaries only for referenced immutable end snapshots/marketing revisions of the same runtime binding. Raw provider evidence references, transcripts, recordings, evaluator and internal IDs are omitted. Missing evidence is explicit. Inspecting an old revision does not substitute newer call outcomes. Model checks remain unverified and record references alone do not prove semantic grounding, identity or customer consent.

Call outcomes now has an on-demand evidence panel tied to the displayed revision, grouped by dimension/mandatory check, with record type, outcome, timestamp/version and public reference. Missing evidence, loading, refresh and denied-access states are explicit; errors hide cached data. OpenAPI regenerated. Added unrun validation, bound-call projection/isolation/older-revision and client provenance/cache-error sources. Schema166 unchanged; no migration or live integration. Tests/typecheck/lint/build/browser remain deferred to the final batch per user instruction.

Owner correction editor, additional semantic evidence sources, evaluator orchestration, tenant weight configuration, verified-critical enforcement and full F9/F12/F13 acceptance remain pending. This is evidence inspection infrastructure, not semantic verification or full quality completion. Goal remains active.


### Owner quality correction editor — 2026-10-28

Call detail passes authenticated owner identity to the evidence panel. The editor is keyed by tenant/actor/revision and uses strict RHF/Zod validation for four nullable integer scores, bounded evidence IDs and a required reason. Available referenced same-call records are selectable; unavailable references are removed from defaults and cannot silently support a numeric score. Empty score becomes null; zero remains zero. Current weights and mandatory checks are informational and omitted from the mutation. Server owner/evidence/latest-version checks remain authoritative.

POST uses the captured revision/version, quoted If-Match and a fresh idempotency key. First send freezes the command; explicit retry reuses the exact key/body/version and bypasses revalidation of disabled inputs. Busy guard prevents double-send; no automatic POST and no nested form. Successful mutation invalidates Calls/Campaign/AuditLog views. Closing/reloading discards in-memory retry state; server latest-version guard prevents overwriting an accepted correction. Owner role loss removes the editor and server independently rechecks authorization.

Added unrun form and payload sources for null versus zero, numeric/evidence validation, immutable retries, parent-form isolation and unavailable-evidence rejection. Tests/typecheck/lint/build/browser remain deferred. API/schema166 unchanged; no production action. The editor currently selects from evidence already referenced by the inspected revision; discovery of additional same-call artifacts, evaluator orchestration, broader semantic evidence and remaining quality/phase acceptance remain open. Goal active.


### Additional same-call quality evidence selection — 2026-10-28

GET /api/v1/calls/:call_public_id/quality/:revision_public_id/evidence/candidates now discovers immutable records not already referenced by an assessment. Shared exact tenant/call/revision resolution, calls.read, repeatable read and no-store apply. First page includes the bound call-end record plus up to25 (maximum100) marketing revisions; subsequent pages use same-tenant/binding public marketing cursors and descending internal IDs. Cursor lookup cannot cross calls or tenants. Responses contain only public summary fields. This is a live candidate view, not a frozen export; newly observed records can appear on refresh, and are never silently attached to old assessments.

Owner correction editor has an explicit paginated picker. Adding a record makes it available for per-dimension selection; it does not save or change scores. Existing references are deduplicated, unavailable/error pages are hidden, and correction submission freezes candidate changes with the original request. Server same-call evidence checks and the latest-revision guard remain authoritative. This closes the editor's restriction to already-referenced artifacts; supported artifact kinds remain end snapshots and marketing revisions only, not transcript or semantic verification.

Added unrun candidate query-bound, call/tenant/cursor isolation, first-page end record, no-repeat pagination and UI explicit-selection/error sources. OpenAPI regenerated. Schema166 unchanged; no DB migration. Tests/typecheck/lint/build/browser deferred per user instruction; full populated pagination/concurrency/query-plan acceptance remains for final verification. Quality evaluator, broader evidence, captured weight configuration, verified-critical enforcement and remaining phases remain open. Goal active.


### Immutable tenant quality policy and snapshot capture foundation — 2026-10-28

Migration167 adds immutable tenant quality policy revisions with exact four integer weights (0–100, total100), tenant/version uniqueness, active-owner insert guard, contiguous versions, tenant lock and database timestamp. No mutation endpoint or settings UI is enabled yet. Defaults remain30/25/20/25 when no policy exists. Policy records cannot be rewritten/deleted; rollback refuses once policy provenance exists.

Campaign snapshots now store quality_policy_id and quality_weights. Existing snapshots receive baseline defaults without changing their documents or hashes. New snapshot creation reads current policy under the existing tenant mutation lock and includes public policy identity/version/weights in authoring snapshot hash v5. A DB insert guard requires exactly the current tenant policy; existing snapshot immutability preserves captured weights when future policy versions change. Policy changes affect new snapshots, not already captured campaigns.

Model revision persistence requires captured snapshot weights after replay lookup; the DB independently rejects new model revisions with arbitrary weights. Previous revision replay remains intact and historical assessments are not recomputed. Owner corrections still preserve their preceding assessment weights/checks, including historical provenance. This establishes trusted weight input for the future evaluator; it does not implement evaluator jobs or tenant settings commands.

Local haisly_caller backed up and migrated167. API now requires167; rollback after policy creation requires provenance-preserving repair rather than dropping policies. Added unrun policy isolation/version/immutability/check and model wrong-weight guard sources. Tests/typecheck/lint/build/browser remain deferred; concurrent policy/snapshot capture and full rollout acceptance remain final verification. Client runtime unchanged. Owner settings read/update UI/API, evaluator orchestration, semantic evidence, verified-critical enforcement and remaining phases are still open; goal active.


### Owner quality policy API and tenant settings form — 2026-10-28

GET/POST /api/v1/quality-policy now read the baseline/current policy and append owner policy revisions. Active user/membership/nonrevoked owner checks run before both read and mutation receipt replay. POST requires strict four integer weights totaling100, bounded Idempotency-Key and quoted If-Match including0 for baseline. No controls permit disabling mandatory checks. Tenant-locked version comparison, immutable policy insert, actor-scoped receipt and before/after audit commit atomically. Matching unexpired receipts replay before stale-version comparison; conflicting or expired receipts return409. No-store on all responses,2KiB body limit and sensitive mutation rate limit. Uses schema167; no new migration.

Tenant account settings now includes an owner-only form with total percentage, integer/range/total validation and explicit new-snapshot-only wording. Query cache is scoped by tenant/actor, errors suppress cached settings, and role loss unmounts the form. Captured version and key/body are frozen after first send; explicit same-request retry survives uncertain responses while the editor remains mounted. Success refreshes campaign/policy and audit views. Refresh/reload discards the in-memory command; server If-Match and receipt checks prevent overwrites/duplicate accepted changes. Existing call assessments and snapshots remain unchanged.

OpenAPI regenerated; added unrun header/body validation and client invalid-total/immutable-retry sources. Tests/typecheck/lint/build/browser remain deferred. Full HTTP owner revocation, receipt expiry/replay, transaction rollback and concurrent settings/snapshot acceptance remain for final verification. Snapshot detail presentation of captured policy, evaluator orchestration, semantic evidence, verified-critical enforcement and remaining phases remain open. Goal active; no production or live-call action.


### Captured quality policy in campaign snapshot detail — 2026-10-28

Existing authorized/repeatable-read campaign snapshot detail now explicitly projects captured policy public ID, version and weights through a tenant-safe policy join. Baseline snapshots report null public ID/version0. Comparison reads current policy in the same transaction and flags changed policy identity or weights; it never substitutes current settings for the captured values. Internal policy IDs remain omitted. API contract regenerated.

Client snapshot detail displays the four captured weights, policy version/default baseline and immutable-snapshot semantics. A differing current policy prompts creation of a new snapshot; it suppresses the misleading no-differences message. Existing loading/access-error behavior still hides failed snapshot reads. Also supplied the missing survey-follow-up section label in this touched detail mapper.

Added unrun snapshot projection assertions and UI coverage for real zero weights and policy drift. Schema167 unchanged. Tests/typecheck/lint/build/browser remain deferred; concurrent snapshot/policy integration and full acceptance remain final verification work. Evaluator orchestration, broader semantic evidence, verified-critical enforcement and other phase dependencies remain open. Goal active.


### Immutable transcript capture for quality evaluation — 2026-10-28

Inspection confirmed existing transcript ingestion/finalization can update call_transcripts. Migration168 therefore adds caller_quality_transcript_snapshots with tenant-safe bound-call attribution, immutable versioned segments, content SHA-256, capture time and tenant/binding/request-key uniqueness. The DB derives call, transcript body/order/hash/version from authoritative rows rather than accepting caller text. Capture requires an immutable bound call end and rejects ambiguous multiple runtime bindings for the same call. Zero transcript segments, more than1000 segments or over1MiB raw content fail rather than silently truncating; stored JSON is independently bounded to2MiB. Source speaker/timing labels remain observations, not verified identity or complete-conversation proof.

Internal captureQualityTranscript serializes with the tenant mutation lock, returns the original snapshot for the same binding/key, and writes a reason/text-free system audit atomically. A new key can capture later corrected transcript state without rewriting earlier evidence. It returns only public ID/version/count/hash/time; transcript text is not copied to its response or audit. No public route, default worker or provider call is enabled. Future orchestration must authenticate tenant/environment before invoking this internal primitive, and any text-reading route must require caller.transcripts.read in addition to its call scope.

Local haisly_caller backed up and migrated168. Rollback refuses to remove captured transcript evidence; privileged retention/purge integration remains mandatory F13 work before production enablement. Added unrun fixture sources for old-text preservation after source correction, stable replay, new-version/hash, wrong-tenant lookup, immutable updates and text-free audit. Tests/typecheck/lint/build/browser deferred. This does not yet register transcript snapshots as assessment evidence, expose transcript evidence UI, certify provider ingestion, or run automatic evaluation. Those integrations and all other remaining phases stay open; goal active.


### Transcript evidence references and protected reader — 2026-10-28

Migration169 extends the existing quality assessment guard to accept immutable transcript snapshot public IDs only for the exact tenant/runtime binding. Other score/provenance/immutability controls remain unchanged, including mandatory unverified model checks. Rollback refuses while assessments reference transcript snapshots. Shared API evidence ownership helper now serves model persistence and owner corrections for end, marketing and transcript artifacts; it does not treat ownership as semantic verification.

Quality evidence projection returns transcript metadata only (public ID/version/capture time/kind), never segments. New GET /api/v1/calls/:call_public_id/quality-transcripts/:snapshot_public_id requires BOTH calls.read and caller.transcripts.read and exact tenant/call/snapshot lookup. Immutable pages use bounded after count and default50/max100 segments; no-store applies to errors and success. The endpoint neither fetches providers nor replaces evidence with current mutable transcripts. Captured transcript contents remain untrusted observations, not verified identity, consent or completeness.

Client evidence inspector opens captured transcript text on demand, pages the same snapshot, escapes text and hides cached contents after an access error. Transcript types/labels also work in correction options. New transcript candidate discovery is not yet added to the existing marketing candidate pager; evaluator-produced referenced snapshots can be inspected and reused by corrections. OpenAPI updated.

Local haisly_caller backed up and migrated169. Added unrun fixture sources for transcript references accepted by model/DB guards, metadata-only projection and ownership rejection, plus query bounds and client on-demand/pagination/XSS/access-error sources. Tests/typecheck/lint/build/browser deferred. Full HTTP permission/revocation/no-store acceptance, retention/purge, authenticated evaluator orchestration and other remaining phases stay open; no provider calls or production enablement. Goal active.


### Trusted evaluation context and model-output boundary — 2026-10-28

Added a provider-independent internal quality-evaluator-v1 contract and context reader. One scoped SQL projection binds tenant/environment/runtime binding/call/end/snapshot/transcript, returning only captured weights, compiled campaign text and immutable transcript/end evidence; no raw agent/provider configuration. Payloads over2MiB fail instead of truncating. Transcript completeness, missing tool/retrieval/survey events and unavailable compiled campaign are explicit limitations. This helper is internal; future orchestration must authenticate tenant/environment before calling it.

Structured evaluator responses can contain only four nullable dimension scores and mandatory check claims. They cannot supply weights, total score, provenance or actions. Validation copies captured weights and assigns model_assessment provenance, rejects references outside the supplied evidence pack and requires transcript evidence for numeric conversation scores/conclusive preference claims. Missing compiled campaign blocks objective/grounding/identity scores; missing tool events blocks preference_tools scores and conclusive tool authorization; survey completion remains unscored without survey events. Missing evidence therefore stays unknown/null rather than producing a fabricated complete score.

Versioned evaluator instructions explicitly treat all campaign/transcript content as untrusted evidence, forbid following embedded instructions or executing tools/actions, and distinguish lifecycle closure from semantic proof. No provider is called, no model adapter is configured and no job/worker is enabled by this slice. This is input/output infrastructure, not completion of automatic evaluation.

Added unrun response tampering/fabricated citation/missing-evidence validation and exact-tenant/environment context fixture sources. Schema169 and public API/client runtime unchanged. Tests/typecheck/lint/build/browser remain deferred. Authenticated durable evaluation jobs, provider adapter, tool/retrieval/survey evidence, verified-critical enforcement, retention and remaining phase dependencies stay open. Goal active.


### Durable initial quality evaluation enqueue — 2026-10-28

Bound call-end capture now atomically enqueues one quality.evaluate-initial job in the separate caller-quality queue using the existing background_jobs/job_attempts/lease system. Tenant/queue/binding dedupe prevents duplicate jobs on closure replay; replay also repairs an absent job for an already captured end without resetting completed/dead-letter state or attempts. Payload contains only versioned public binding/end/environment references, no transcript, campaign content or provider credentials. New jobs are retry-safe at the business persistence layer, max5 attempts, and first available after five minutes for late transcript arrival. No worker or provider adapter is enabled; provider billing/idempotency handling must be completed before execution.

A shared strict payload contract rejects inline text and authority overrides. Internal job reader re-resolves tenant/environment/call/binding/end relationships from the database rather than trusting stored payload scope. Future signed-runtime execution must independently verify a live attempt lease and preserve tenant-before-job lock ordering. Existing foundation worker remains scoped to caller-foundation and does not consume this new queue.

Queue creation and one text-free audit commit with closure. Duplicate-key collisions with another payload/type fail instead of silently reusing unrelated work. Existing historical ends are not bulk-enqueued in this slice; a bounded authenticated backfill/reconciliation path remains pending.

Added unrun payload validation and bound-fixture sources for dedupe/audit-once, reference-only payloads, initial retry settings and cross-tenant/environment rejection. Schema169 unchanged. Tests/typecheck/lint/build/browser deferred. Durable attempt preparation/model-version pinning, authenticated lease handling/worker, result commit, bounded retry/dead-letter controls, provider adapter and all remaining phase dependencies remain open. Goal active; no provider calls or production enablement.


### Durable prepared inputs for quality jobs — 2026-10-28

Migration170 adds one immutable caller_quality_evaluation_inputs row per tenant/background job, with exact binding/transcript references, evaluator/protocol version, input hash and initial expected assessment version0. DB insert guard verifies running job/active attempt/unexpired lease, exact versioned job payload/tenant/call/environment bindings and absence of an existing assessment. Records cannot be rewritten/deleted; rollback refuses once prepared inputs exist.

Internal prepareQualityEvaluation takes the tenant lock before job lock, resolves runtime environment independently, verifies the active attempt and captures the transcript using a stable job-derived key. It hashes captured context together with evaluator instructions and evaluator reference, then stores the prepared row plus text-free audit atomically. The caller must commit preparation before any provider request. Retries rehydrate the original immutable transcript and verify the original evaluator/input hash rather than reading changed live transcripts. Evaluator/configuration changes fail closed; expired/stale attempts cannot prepare or reuse inputs. The internal context contains text but is not exposed by a public route or copied to audits/receipts.

Local haisly_caller backed up and migrated170. Added unrun fixture sources for replay after mutable transcript change, immutable prepared rows, evaluator mismatch, wrong environment, missing/expired attempt. Tests/typecheck/lint/build/browser remain deferred; full concurrent lease/persistence acceptance is pending. No worker/provider adapter is enabled. Signed runtime preparation/execution, result persistence and job completion, retries/dead-letter actions, retention and remaining phase dependencies stay open. Goal active.


### Atomic quality result persistence and job completion — 2026-10-28

Migration171 adds immutable evaluation-result receipts linking tenant/job/prepared input/assessment/attempt with response hash. Insert guard verifies the active lease/attempt, exact prepared binding/evaluator, initial assessment version and job-derived idempotency key. Background jobs of this quality type cannot reach succeeded without a matching recorded result and succeeded active attempt. Added missing job_attempts(id,tenant_id) uniqueness to support the tenant-safe result FK. Rollback refuses recorded results.

Internal completeQualityEvaluation takes tenant then job locks, resolves environment and prepared identity, rehydrates immutable context, checks context/instruction/evaluator hash and validates model output. Assessment insert, quality-window reconciliation, result receipt, attempt/job success and text-free completion audit commit in the caller's single transaction. Live lease is rechecked before result acceptance; transaction failure must roll back all changes. Successful same-attempt/same-response replay returns its original assessment; changed response/attempt conflicts. The initial job cannot overwrite subsequent human/model work. Provider calls remain outside transactions.

Generic background-job completion explicitly rejects quality jobs, with a DB guard as a second layer. Result/attempt metadata contains only assessment IDs/version/hash, not model response text or transcript. Existing failure/lease handling is unchanged pending dedicated bounded error mapping and runtime worker integration.

Local DB backed up. First migration171 application rolled back because job_attempts lacked the composite unique key; corrected the not-yet-applied migration and successfully applied171. Added unrun fixture sources for receipt/job atomic success, exact replay, conflicting response/attempt, environment rejection and rejecting generic DB completion without evidence. Tests/typecheck/lint/build/browser remain deferred. Signed runtime execution, worker/provider adapter, failure/dead-letter controls, historical reconciliation, retention and remaining phases remain open. Goal active; no provider or production calls.


### Authenticated quality preparation/completion — 2026-10-28

Added signed internal POST quality-evaluations/prepare and /complete, requiring dedicated runtime.quality.evaluate scope. Tenant/environment derive from authenticated service account; existing primitives enforce exact job, prepared input, active attempt and lease. Preparation accepts job/attempt UUIDs only and uses deployment CALLER_QUALITY_EVALUATOR_REF (unset by default); callers cannot select evaluator identity or override tenant, environment, weights, instructions or verification provenance. Preparation transaction commits before returning bounded immutable context plus instructions. Completion atomically persists validated assessment/result and job success, preserving exact successful replay. Captured evaluator identity remains authoritative for completion after deployment configuration changes.

Routes have 1KiB/64KiB request limits and no-store on success/error. Preparation returns sensitive captured transcript context only to the dedicated runtime scope; do not enable request/response body logging or cache this endpoint. No provider calls, new credentials, worker activation, database migration or client UI changes in this slice. Added unrun validation/configuration tests and regenerated OpenAPI. Tests/typecheck/lint/build/browser and signed endpoint integration acceptance remain deferred to the final batch. Dedicated environment-filtered leasing, worker/provider adapter, bounded failure mapping/dead-letter controls, historical reconciliation and remaining phase dependencies remain open. Goal active.


### Environment-bound quality leasing — 2026-10-28

Added dedicated signed runtime.quality.evaluate lease and heartbeat endpoints, with 1KiB limits and no-store. Lease is disabled without evaluator configuration. Candidate selection joins all tenant/binding/end/call/environment references rather than trusting a claimed environment ID, uses a nonblocking tenant lock and SKIP LOCKED, and returns only public job/attempt/expiry references. Ordering is priority/availability/id; attempt number derives from durable attempt history with an independent maximum check. Invalid payloads with resolvable bindings and exhausted histories go to dead_letter with bounded reason codes and text-free audit.

Recovery handles up to100 expired jobs in the authenticated environment. Unprepared retry-safe attempts retry after30seconds within the limit. Prepared inputs mean a provider call may already have happened; expired prepared jobs go to dead_letter with QUALITY_LEASE_EXPIRED_REVIEW_REQUIRED rather than risking duplicate external evaluation/billing. Heartbeat verifies the environment-bound job and live current attempt before extending60seconds. No worker/provider is enabled. Generic job leasing/recovery excludes the entire caller-quality queue; generic heartbeat/failure/completion reject it.

Extended unrun fixture sources for actual dedicated lease, wrong environment, generic mutation denial, prepared expiry manual-review state, generic recovery exclusion and unprepared retry with incremented attempt. Added unrun request override checks. OpenAPI regenerated; no DB migration/client UI changes. Tests/typecheck/lint/build/browser remain deferred. Concurrent leasing and signed endpoint acceptance, dedicated bounded failure handling, operator dead-letter reconciliation UI/commands, malformed unbound-job reporting, provider adapter/worker and the remaining phases are still open. Goal active.


### Bounded quality failure commands — 2026-10-28

Added signed runtime.quality.evaluate POST quality-evaluations/fail with strict job/attempt/code body, 1KiB limit and no-store. Exact tenant/environment binding and active attempt required. Only predefined failure codes are accepted; provider text, output, arbitrary metadata, retry time and retry-safe overrides are rejected. Pre-preparation input/evaluator-unavailable failures may retry within retry_safe/attempt budget with 30-second exponential backoff capped at15minutes. Prepared/ambiguous provider results, invalid output and other failures go to dead_letter for explicit reconciliation; no automatic provider reissue.

Job failure state, attempt receipt and text-free audit are atomic. Identical same-attempt/code replay returns the original next_status/retry_at receipt even after a newer attempt starts, without mutating current work; changed code conflicts. A receipt describes the original attempt rather than current job status. Failure and heartbeat writes recheck lease expiry using DB clock at mutation time. Scope/configuration rotation does not block authenticated in-flight failure reporting.

Added unrun policy/body-contract tests and fixture scenarios for tenant/environment denial, retry scheduling, original receipt replay, replay after newer lease, conflicting failure code and prepared timeout dead-letter handling. OpenAPI regenerated; no DB migration or client UI changes. Tests/typecheck/lint/build/browser remain deferred. Dedicated worker orchestration/provider adapter, operator dead-letter reconciliation, provider idempotency/billing evidence and remaining plan phases are still incomplete. No provider/production call or worker activation; goal active.


### Provider-independent quality worker orchestration — 2026-10-28

Added processQualityEvaluation and sequential polling orchestration with an injected evaluator and signed runtime client. Each leased job prepares immutable input, checks protocol/evaluator identity/instructions/context hash and2MiB context limit, then gives the adapter a private clone. A15-second heartbeat maintains the lease; loss aborts execution. Provider evaluation has a120-second timeout and cancellation race even if the adapter ignores AbortSignal. Model output is schema/evidence validated and the completion command is capped at64KiB before submission. No raw exception, provider response or transcript is emitted into metrics/failure reporting.

Completion transport errors retry the exact same completion command up to3times without re-evaluating. Once completion was attempted, the worker never sends a failure command because the server may already have committed; unresolved completion remains completion_unknown for lease/result reconciliation. Pre-completion failures report only bounded codes through the dedicated endpoint, with at most2identical failure-command attempts. Shutdown/lease loss suppress stale completion/failure writes. Metrics contain outcome counts and last completed-step time only. Polling is sequential, one evaluation in flight per worker.

Added unrun worker tests for lost completion response, ambiguous completion, tampered input, adapter mutation isolation, bounded error reporting, ignored cancellation and shutdown-before-lease. No tests/typecheck/lint/build/browser executed. The orchestration is not registered or enabled: concrete provider adapter, bounded runtime response transport, startup configuration/health integration, provider billing/idempotency evidence, operator reconciliation and remaining phases still need implementation/acceptance. No DB migration, client UI change, credentials, production/provider call or worker activation. Goal active.


### OpenAI quality adapter and opt-in worker registration — 2026-10-28

Added a concrete Responses adapter using the existing repo REST pattern, based on fetched official OpenAI Structured Outputs docs. Fixed HTTPS endpoint, rejected redirects, one provider request/no automatic retries, no tools, store:false, strict output schema, separate trusted instructions/untrusted user-role evidence, explicit model and versioned evaluator reference. Refusal/incomplete/tool/multiple-message/invalid evidence responses fail closed. Provider body is bounded256KiB, structured output64KiB and context2MiB. Adapter timeout110seconds fits worker120seconds; raw provider errors/outputs never enter failure commands.

Extracted the existing ElevenLabs bounded JSON reader into a shared helper, preserving its2MiB wrapper. Worker runtime client now bounds responses3MiB and cancels unsuccessful bodies without logging. Moved evaluator error type out of worker into provider boundary. Registered sequential quality worker behind default-false CALLER_QUALITY_EVALUATION_ENABLED plus global worker flag; startup requires dedicated key, explicit model and matching openai/<model>/quality-v1 reference. API deployment must use the same reference. Health/metrics include quality activity when enabled; lease/heartbeat success updates activity during long evaluation. No env file, secret, model default or active process was changed.

Added unrun adapter/config/stream-limit tests covering fixed request contract, provider errors without retries, refusal/incomplete/duplicate/tool outputs, invalid JSON, cancellation, limits, default-disabled startup and identity mismatch. Added docs/quality-worker-runbook.md in API with exact configuration and acceptance limits. No tests/typecheck/lint/build/browser or live provider calls executed. Provider request/usage receipts, billing/idempotency reconciliation, operator dead-letter controls, staging certification and remaining phases remain open. Worker is code-wired but not enabled; goal active.


### Owner quality-job operations visibility — 2026-10-28

Added GET /api/v1/campaigns/:public_id/quality-jobs requiring caller.campaigns.read plus an active tenant owner. Exact tenant/campaign/binding/end/call/environment joins constrain stored job references. Repeatable-read keyset pagination defaults25/max100; a cursor must belong to the same campaign, independent of the selected view. attention shows failed/dead-letter/expired-running jobs; all includes other states. Projection contains public call/job references, environment, status, attempt counts, dates, prepared/result flags and allowlisted reason codes only. Unknown stored error text maps to QUALITY_UNKNOWN_FAILURE. No transcript/phone/raw provider error/internal IDs or retry side effect; no-store on all responses.

Client campaign operations has an owner-only lazy evaluation-jobs panel with tenant/actor-partitioned cache, attention/all views, older/previous/latest pagination, refresh, loading/empty/error states and cached-data suppression after errors. Labels distinguish evaluation failure from call failure, show retry eligibility time and prepared ambiguous-result warnings. Unknown reason values use a generic label, and metadata renders as escaped text. This slice provides visibility only; no manual retry button was added before safe reconciliation commands exist.

Added unrun API validation/reason-redaction tests and UI tests for lazy loading/cache partition, paging reset, refresh, access-error hiding and escaped metadata. OpenAPI regenerated. No DB migration; existing jobs/prepared inputs/results are read without mutation. Tests/typecheck/lint/build/browser deferred. Signed/owner revocation/cross-tenant/cross-campaign cursor acceptance, query plans at scale, operator reconciliation commands, malformed unbound-job reporting, provider usage receipts and remaining phases remain open. Goal active; no provider/production calls.


### Durable quality job owner review commands — 2026-10-28

Migration172 adds immutable caller_quality_job_reviews with tenant-safe job/reviewer FKs, monotonically versioned per-job decisions, expected attempt, reason, actor and idempotency key/hash. DB guard requires active owner, current dead-letter attempt and next review version. retry_unprepared additionally rejects prepared/result/assessment evidence, unsafe jobs or exhausted durable attempt history. keep_closed records review without clearing the failure or pretending provider reconciliation succeeded. Later owner decisions can append a new version while the job remains dead-letter. Rollback refuses existing review evidence.

POST /api/v1/quality-jobs/:public_id/reviews requires campaign read plus active owner, quoted If-Match review version (0 initially), Idempotency-Key and expected_attempt_no. Authorization precedes replay. Exact actor/key/hash replay returns original review even after queue progression, without requeueing again. New retry verifies bound job/environment and no assessment, then queues after30seconds; no attempt count reset, max-attempt increase or automatic retry of prepared ambiguous work. Review insert, optional queue transition and text-free audit commit atomically. Added8KiB/no-store/sensitive-action-rate-limit contract. Job list exposes latest_review and server-derived retry_eligible for the upcoming editor.

Local haisly_caller backed up and migration172 successfully applied. Added unrun unit validation tests and fixture guard scenarios for immutable reviews, version conflict, inactive/missing owner and prepared retry denial. OpenAPI regenerated; no test/typecheck/lint/build/browser executed. UI editor/decision history, full signed API idempotency/revocation/concurrency acceptance, privileged retention, provider usage receipts/reconciliation and remaining phases are pending. Client code unchanged in this slice; goal active, no production/provider call or worker activation.


### Owner quality job review editor — 2026-10-28

Client campaign operations now exposes the versioned review command for dead-letter quality jobs. Default keep_closed records a reason without reopening work. retry_unprepared is offered only from server retry_eligible, with an explanation of30-second scheduling, remaining attempt limit and no new customer call. Latest review action/version/attempt/date/reason is shown as escaped text. Command capture freezes job, attempt, review version, decision, reason and idempotency key on first submission; explicit retry bypasses disabled-field validation and resends the exact command. A synchronous busy guard prevents double sends. The independent command uses type=button inside the existing editor rather than a nested form.

Successful writes invalidate Campaign/AuditLog; failures retain the frozen command and do not silently refresh it away. Errors offer same-command retry or refreshing current state. Tenant/actor-scoped panel remount and job/attempt/review-version editor keys prevent reuse across identities or changed records. In-memory command persistence ends on unmount/reload; server optimistic checks remain authoritative. Added unrun UI tests for eligibility, required reason, immutable retry payload, double-submit prevention, initial version0 and escaped review reason. Runbook updated to reflect implemented commands and remaining prepared-result reconciliation.

No API/schema migration or provider call in this slice. Tests/typecheck/lint/build/browser remain deferred. Full review history browsing, signed mutation concurrency/revocation/idempotency acceptance, provider usage receipts/ambiguous result reconciliation, retention and remaining phases remain open. Goal active.


### Quality job decision history — 2026-10-28

Added GET /api/v1/quality-jobs/:public_id/reviews requiring campaign read and active tenant owner on every request. Repeatable-read pagination is scoped to tenant and exact quality job/type, ordered by immutable review version descending, default25/max100. A cursor from another job is rejected. History remains available after a job leaves dead_letter; response projects only public review IDs, versions, attempt numbers, decisions, reasons and dates. No-store applies on success/error. Existing immutable review indexes/records are reused; no migration.

The campaign quality panel now has an on-demand decision-history section per job, tenant/actor-partitioned cache, previous/older/latest pages and explicit refresh. Loading/empty/error states are present and errors suppress cached reasons. Review text is escaped. Successful review commands already invalidate Campaign data, refreshing open history. Added unrun UI tests for lazy identity-scoped reads, pagination/refresh, access-error data hiding, escaped reasons and empty state; OpenAPI regenerated and worker runbook updated.

Tests/typecheck/lint/build/browser remain deferred. Signed owner-revocation/cross-tenant/cross-job-cursor/concurrent-append acceptance and query-plan verification still need final batch coverage. Provider request/usage receipts, prepared ambiguous-result reconciliation, retention and remaining phases stay open. No provider/production call or worker activation; goal active.


### Immutable provider usage observation receipts — 2026-10-28

Migration173 adds caller_quality_provider_receipts with tenant-safe job/prepared-input/attempt FKs, one immutable receipt per attempt and tenant/provider/response-ID uniqueness. Bounded provider/request/model identifiers, outcome/HTTP status and nullable input/output/total/cached/reasoning counts are stored without raw input/output, cost or secrets. Null remains unknown, distinct from measured zero. Count nonnegativity, total consistency and cached/reasoning subset bounds are enforced. DB guard verifies prepared job/attempt linkage and prevents attribution to an attempt that completed before the input existed; no job state transition occurs. Rollback refuses recorded observations.

Signed runtime.quality.evaluate provider-receipt endpoint accepts4KiB/no-store and resolves exact tenant/environment/prepared context hash/attempt. Tenant then job locks serialize immutable receipt/replay checks. Identical observation replay returns the original; changed values or reusing a response ID across attempts conflict. Late observations can attach after expiry/completion without reviving, completing or billing a job. Observation is runtime-worker evidence, not independently verified provider billing authority. Text-free audit records receipt ID/outcome only.

Local DB backed up and migration173 applied successfully. Added unrun validation/guard fixture sources for unknown versus zero, inconsistent counts, forbidden raw payload fields, wrong environment, exact replay, conflicting payload, immutability and late receipt not changing job state. Initial OpenAPI generation exposed a missing delimiter in the new schema; fixed it and regenerated successfully. Tests/typecheck/lint/build/browser remain deferred. Adapter/worker production of receipts is not yet wired; provider field extraction, provider request/usage reconciliation, owner usage display, retention and remaining phases stay open. No provider/production call or worker activation; goal active.


### Adapter/worker provider observation delivery — 2026-10-28

Extended evaluator contract with an observation callback. OpenAI adapter now extracts only bounded response/request IDs, configured model, outcome/HTTP status and nullable usage counters after one provider request. Successful semantic validation marks completed; incomplete/refused/invalid outputs and transport errors retain their distinct outcomes. Raw response/error/refusal/transcript text is never copied. Missing/invalid counters remain null; inconsistent totals or cached/reasoning subsets become unknown without inventing totals. Counter shape checked against fetched official cookbook Responses examples; no live request executed.

Quality worker submits observations with its exact prepared context and job/attempt, retrying only the identical receipt command twice. Successful completion follows receipt acknowledgement. Failed persistence never repeats evaluation and uses the bounded failure/manual-review path. Late callbacks may persist after cancellation without reviving jobs. Configured model is recorded, not a provider-reported alias; observations remain runtime evidence rather than billing authority. Process-crash receipt loss and enrichment/reconciliation of unknown observations remain unresolved for independent reconciliation work.

Added unrun extraction, adapter and worker tests for missing/zero/invalid counters, safe fields, refused outputs, identical receipt replay, receipt-before-completion and no provider repeat when receipt writes fail. Updated OpenAPI description and runbook. Tests/typecheck/lint/build/browser remain deferred; no migration/client UI change or worker activation. Owner usage read model, provider attempt/invoice reconciliation, append-only corrections, retention and remaining phases stay open. Goal active.


### Owner provider usage visibility — 2026-10-28

Campaign quality-jobs owner read model now projects the latest recorded provider observation by attempt number, scoped through the tenant/job attempt relationship. A late receipt from an older attempt cannot displace a newer attempt observation. Public receipt ID, configured model, outcome, nullable counters, attempt and recording time are returned; external response/request identifiers and raw payloads are excluded. Existing owner authorization, campaign/environment binding and pagination are retained. No migration required; OpenAPI regenerated.

Client displays the observation per job, explicitly identifying older-attempt data. Unknown counters remain unknown, measured zero remains zero, and missing receipt does not imply no usage. Cached input/reasoning are labeled as subsets of input/output. Display does not aggregate attempts or claim verified invoices/costs. Added unrun UI tests for null/zero, missing receipts, older attempt attribution and escaped provider text; typed fixtures updated.

Tests/typecheck/lint/build/browser remain deferred by user instruction. Final acceptance still needs owner revocation, cross-tenant/campaign isolation, receipt selection under late delivery and query-plan verification. Request-start accounting, provider invoice reconciliation, append-only enrichment, retention and remaining phases remain open. No provider call, worker activation or production operation; goal active.


### F12 accepted-attempt report foundation — 2026-10-28

Added GET /api/v1/campaigns/:public_id/reports/attempts guarded by analytics.read, tenant ownership and no-store. Required offset-aware from/to define a half-open provider acceptance interval, positive and at most366 days. Optional snapshot is scoped to the exact tenant/campaign; optional source list is tenant-scoped. Repeatable-read aggregation uses production billing reservations, dispatch snapshot and captured target-source EXISTS rather than current membership. Counts include accepted attempts, distinct attempted targets, still-active and ended attempts, plus call end reasons. Transport retries/test/inbound do not become production attempts. No phone, contact identities, raw evidence or internal IDs are projected.

The date window selects accepted calls; end states are current known states of that cohort, not a historical as-of reconstruction or end-date report. Late reconciliation can change a subsequent read. Completed end reason is explicitly not human reach or business success. Human reach, confirmed interest, survey, costs, business-outcome filtering, full report UI/export remain open. Added identity-partitioned typed client query contract but no screen yet, so analyst report discovery/UI is not claimed complete.

OpenAPI regenerated successfully; added unrun query-validation tests for timezone offsets, exact366-day bound, inverted/empty/oversized windows and forbidden selector fields. Source diff reviewed. Tests/typecheck/lint/build/browser stay deferred. Final PostgreSQL acceptance must prove multi-list deduplication, multiple attempts per target, exact from/to boundaries, archived/current membership independence, foreign tenant/campaign filters, test exclusion, empty results and late state changes; query plan/index adequacy remains to be verified. No migration, live service operation or phase completion. Goal active.


### F12 analyst report discovery and attempt screen — 2026-10-28

Added analytics.read-only GET /api/v1/reports/campaigns with tenant UUID keyset paging (25 default/100 max), same-tenant cursor validation and no-store. Projection is limited to public campaign ID/name/type; does not grant draft/audience/agent access. This permits analyst campaign selection without widening campaign-read permissions. OpenAPI regenerated; input validation test source extended. No migration.

Analytics page now mounts a permission-gated, on-demand campaign attempt report section. Tenant/actor changes remount the panel and partition RTK cache. Campaign labels are escaped; paging and refresh are provided. Selected campaign displays accepted attempts, distinct targets, active/ended counts, end reasons and calculated-at time. RHF/Zod date form uses explicit UTC day boundaries, inclusive start/exclusive end and366-day bound, default last30 UTC days including today. Applied interval stays visible independently of edited fields. Fetching/errors hide report totals, and campaign errors suppress selected report. Empty production interval is explicit; completed is not human reach or sales success.

Added unrun client coverage for lazy scoped loading, escaped labels, cached-result hiding on failure, campaign cursor paging, attempt/target distinction, empty results and UTC/calendar date boundaries. Tests/typecheck/lint/build/browser remain deferred. Final DB authorization/cursor/query-plan and UI accessibility/responsive acceptance are still required. Snapshot/list selector UI, business-outcome filter, human-reach/survey/interest/cost KPIs and async export are not yet delivered; full F12 remains open. Existing legacy report-definition screen behavior was not reclassified as verified outbound reporting. All remaining phases/goal stay active; no live provider or production operation.


### F12 report snapshot/source selectors — 2026-10-28

Added analytics.read filter-options endpoint scoped to tenant and exact campaign, with kind=snapshot|list, UUID keyset paging default25/max100 and same-scope cursor validation. Snapshot projection contains only public ID/sequence number. List projection uses EXISTS over captured campaign target sources, includes archived lists, and exposes only public ID/current name/archive flag; no current membership, contact records or snapshot document is returned. Options are independent of date interval and each other, so valid combinations can yield zero results. OpenAPI regenerated. No migration.

Attempt report UI now offers lazy paged version/source selectors with explicit all/reset, selected labels retained across option pages, refresh and loading/error/empty states. Campaign/tenant/actor remount and cache scopes are preserved. Changing either filter immediately updates the existing report request while keeping the applied date interval. CurrentData and loading/error suppression prevent displaying totals from another filter request. Archived list labels and version meaning are explicit. Added unrun selector/pagination/reset/escaping/access-error and combined-filter request tests; API validation covers kinds, pagination and forbidden fields.

Source diffs reviewed; tests/typecheck/lint/build/browser remain deferred. Final PostgreSQL acceptance must cover cross-tenant/campaign/kind cursors, target/list deduplication, archived membership changes, snapshot filtering and query plans; UI responsive/accessibility checks remain pending. Business-outcome filtering, human-reach/survey/interest/cost KPIs, exports and remaining phases are still open. Goal active, no production/provider operation.


### F12 survey completion in accepted-call cohort — 2026-10-28

Attempt report now includes survey metrics for survey campaigns and survey=null for marketing. The existing production/date/snapshot/captured-list selection is deduplicated by target/snapshot before joining tenant-scoped current survey sessions, so repeated accepted calls and overlapping lists do not multiply surveys. Started is persisted survey-session count; completed/partial/active/declined use authoritative current session state. Targets without a session are separate. Completion percent is completed/started, null with zero denominator; API keeps unrounded ratio and rejects inconsistent counts. Reuses existing unique tenant/target session constraint; no migration.

UI shows completion percentage, numerator/denominator states, partial results and not-started targets separately. It explains that the date range selects an accepted-call target cohort, not survey start/end dates, and later resumes/corrections can update results. Marketing omits survey section. OpenAPI regenerated; added unrun pure-count tests and UI tests for distinct denominator, partial results, null versus measured zero, invariant rejection and ratio precision. Source and schema constraints reviewed, but tests/typecheck/lint/build/browser not run by user instruction.

Final DB acceptance still needs repeated-call/list overlap, exact target/snapshot joins, correction/resume behavior, date boundaries and tenant isolation coverage. Human reach/confirmed interest were inspected: marketing has revision-bound observations and confirmations, but all-campaign human-reach evidence is not yet complete; call end reason will not be treated as human proof. General reach, confirmed-interest aggregation, question distributions, business-outcome filter, cost KPIs/export and remaining phases stay open. Goal active; no provider/production operation.


### F12 selected-version question distributions — 2026-10-28

Attempt report includes survey_questions only when a survey snapshot is explicitly selected; null otherwise, preventing questions/options from different immutable definitions being merged. Reuses the exact production/date/list/dispatch-snapshot cohort and deduplicates targets before joining current sessions. Two bulk SQL aggregates count only active revisions with no invalidated_version, excluding superseded/dependency-changed answers. All defined questions appear, including zero responses. Counts separate answered, explicit skipped and no_active_answer among started sessions; no_active_answer is not falsely labeled skip or not-reached. Fixed choice/boolean/scale bins include zeros; multiple-choice totals may exceed respondents. Numeric questions provide min/max/average, unknown when absent. Free-text/date/datetime answer values are never fetched into report output; only counts. No migration.

Client renders per-question expandable distributions and explains selected-version scope, revision semantics, missing versus explicit-skip and multiple-choice totals. Question/option labels are escaped; numeric null remains a dash. Added unrun bin/schema-bound tests, UI tests and a report fixture invoked after the existing survey-dispatch fixture, comparing aggregate counters to current active answers and checking no-store and all-version suppression. OpenAPI regenerated; source diff reviewed. Tests/typecheck/lint/build/browser remain deferred by user instruction.

Final acceptance still needs full multi-target/multi-attempt/cross-list fixtures, correction/branch invalidation, every answer type, tenant isolation, query plans/load and responsive/keyboard verification. General reach, confirmed-interest aggregation, business-outcome filtering, cost KPIs/export and remaining phases are still open. No production/provider operation; goal active.


### F12 accepted-call cost and uncertainty — 2026-10-28

Report now aggregates production reservation costs for the exact selected accepted-call cohort. Distinct reservation IDs avoid join multiplication. Settled amount uses sale_amount minus same-tenant audited adjustments linked to the original usage entry, following existing billing-budget semantics; corrections are attributed to the original call interval. Held/uncertain reserve and pending call count remain separate. total_amount is null while any selected cost is pending; empty/known zero is a six-place zero string. PostgreSQL numeric plus BigInt decimal formatting preserve precision, including aggregate totals above a single-entry bound. No new ledger or migration.

Client displays settled, reserve and total separately with explicit pending-cost explanation and accepted-call scope. Money remains decimal strings, never JS Number. OpenAPI regenerated; unrun unit/UI cases cover pending-versus-zero, reserve not spend and large-value precision. Source diff reviewed. Tests/typecheck/lint/build/browser remain deferred. Final DB acceptance must still verify adjustment replay/credits/debits, isolated tenants, late settlement and combined date/version/source filters, plus query-plan/load checks.

This is not whole-campaign invoice or cost-per-success delivery: rejected/pre-accept costs and the complete verified success denominator still require their own scope handling. General reach/interest, business-outcome filtering, full cost-per-success/export and remaining phases remain open. Goal active; no production/provider operation.


### Report cost integration acceptance sources — 2026-10-28

Extended existing isolated billing-adjustment fixture to read report costs before correction, after concurrent identical correction/replay and after restoring the original effective amount. Assertions require one settled call throughout, exact credited/debited amounts and no foreign-tenant reservation projection. Added survey-report assertions for pending cost, anonymous401/no-store, exact inclusive-from/exclusive-to millisecond boundaries and empty-cohort zero versus pending total=null.

New report-cost-settlement fixture starts from the ended survey call, checks reserve/pending state, applies a fixture-only verified zero-cost settlement, checks known-zero/no-reserve, repeats the identical settlement and requires unchanged totals. All settlement/ledger/budget effects are rolled back to a savepoint before returning, preserving downstream fixture state. No fixtures or tests were executed; only test source and progress notes changed. Final execution and additional multi-attempt/list/tenant/query-plan acceptance remain required. Runtime API/client/DB behavior unchanged in this slice; no migration or external call. Full goal and remaining phases stay active.


### Publication preflight budget diagnostics — 2026-10-28

Revisited the actual publication path: draft preflight still has unimplemented live certification dependencies, and campaign lifecycle has no ready production publication path. Added real read-only budget diagnostics within its repeatable-read snapshot: missing/reconciliation account, no available balance after reserves (including negative reconciliation balances), missing/paused/exhausted tenant monthly and exact campaign limits. Reuses existing corrected budgetUsages without calling the mutating budget reservation gate; no pause writes, notifications, funds or calls. Uses DB transaction time for schedule/monthly checks and adds canceled/stopping lifecycle blockers. Only reason codes are exposed to campaign readers, no financial amounts or budget identifiers.

Client supplies actionable Turkish/English messages and makes clear that a positive balance does not pass the pending final tariff/reservation gate. OpenAPI regenerated; unrun unit sources cover missing configuration, reserved balance, paused replenished budgets, exhausted scopes, exact micro-unit values and negative reconciliation balance. Source reviewed; tests/typecheck/lint/build/browser remain deferred. No migration. Real publication/test certification, verified test-number lifecycle, dispatcher scheduling and earlier phase dependencies remain open; these diagnostics do not enable activation or count as publication completion. Goal active; no external or production operation.


### Preflight remediation navigation — 2026-10-28

Client preflight now maps known fixable blockers to scoped editor sections or existing billing/team screens. Local buttons scroll/focus only inside their own campaign form and never submit. Question-specific failures lead to survey editing; instructions/source selections, scheduling/agent/phone settings and follow-up team selection lead to their sections. Billing and team links use tenant-aware routes, new tabs and noopener/noreferrer to preserve the current draft. Links require billing.read or the actual team-page users.manage permission; unauthorized viewers receive a support instruction. Unknown implementation/certification blockers have no fabricated fix link and do not enable publication.

Added unrun UI coverage for same-form focus without submit, missing implementation actions, billing permission/new-tab behavior and real team permission. Source/diff reviewed, preserving existing spacing after section wrappers. Tests/typecheck/lint/build/browser remain deferred; keyboard/mobile/browser acceptance still pending. API/DB behavior unchanged, no migration. Full publication/test certification and remaining goal work stay open.


### F12 recorded marketing reach and confirmed interest — 2026-10-28

Report now includes marketing-only aggregates over the exact selected production accepted-call cohort. Each dispatch resolves its tenant-bound runtime binding and latest result revision. Human reach is distinct targets with any selected call's current human observation; voicemail is excluded, and targets with no human evidence plus unknown/missing classifications are separately counted. Confirmed interest uses the highest result version among selected calls for each target and requires interested/human, explicit request and granted confirmation tied to that exact result and binding. Old confirmations cannot transfer to corrected results; repeated calls do not inflate target counts. Ratios are human/attempted and confirmed/human, null for zero denominators. Calls outside the selected interval are not consulted.

Client shows numerator/denominator, unresolved reach, current-evidence caveat and late-update/correction semantics. Survey campaigns return marketing=null; general survey human reach remains open. OpenAPI regenerated; unrun invariant/denominator/null-zero and UI tests added. SQL source and binding uniqueness reviewed. Tests/typecheck/lint/build/browser remain deferred. Final real PostgreSQL acceptance must prove superseded result/confirmation handling, latest-per-call and latest-among-selected ordering, multiple calls, absent bindings, tenant isolation and query-plan/load behavior. Observer ingestion/live evidence completeness is not proven by this read model. Full cost-per-success, outcome filtering/export, publication and remaining phases stay open. No migration/provider/production operation; goal active.


### F12 campaign business-outcome filters — 2026-10-28

Added campaign-specific outcome query/UI options with default all. Survey uses current session state including no session; marketing reuses the same latest-selected-call revision/confirmation CTE as its metrics, with confirmed interest, unconfirmed interest, not interested, callback, representative, partial, uncertain and no recorded result separated. Incompatible campaign/type returns400 after tenant authorization. The outcome selects target groups before all attempt/target/end-reason, survey/question, marketing and reservation-cost aggregates. Selected targets retain every accepted call in the original date/version/source cohort. Ratios describe that filtered subgroup; missing newer call evidence does not overwrite an older recorded result. Current corrections can change reports.

OpenAPI regenerated. Added unrun validation, campaign-specific option/query UI and survey fixture assertions for matching/nonmatching results, empty costs/questions and incompatible filter no-store response. Source/diff reviewed; tests/typecheck/lint/build/browser deferred by user instruction. PostgreSQL marketing supersession/confirmation/multiple-call and query-plan acceptance remains for final batch; no claim of runtime verification. No schema migration or provider/production operation. Publication, export, broader reports and remaining phases stay open; goal active.


### F12 aggregate export CSV production foundation — 2026-10-28

Added a server-side CSV serializer for the accepted-attempt aggregate report, for use by the pending durable async export worker. Fixed long-form format version1 includes applied filters, accepted-date basis, production purpose, calculation timestamp, denominator/current-state caveats, attempt/end-reason counts, exact USD amounts and reservation status, marketing/survey metrics and bounded selected-version question distributions. Null remains an empty value, known zero remains zero; money is never converted through floating point. Explicit field enumeration excludes accidental additive API fields/raw answers. Existing CSV formula/control neutralization and quoting are reused; UTF-8 BOM and CRLF support spreadsheet opening. Text safety can prefix an apostrophe, including negative-looking cells, and consumers should use the unit column.

Authored unrun CSV parsing tests for precise large amounts, null versus zero, metadata, malicious labels, Unicode/quotes/newlines and exclusion of unexpected sensitive fields. No tests/typecheck/lint/build executed per user request. This is the file-generation layer only: durable async request/worker, tenant and current-permission checks at download, audit, expiry/retention and client status/download UI remain pending. No download endpoint or browser-only shortcut added; F12-T03 is not complete. No schema migration, provider call or production mutation. Goal remains active.


### F12 durable aggregate export request foundation — 2026-10-28

Reuses existing export_jobs/background_jobs instead of adding a competing queue. Added internal authenticated analytics.read request service with strict bounded campaign filters, same-tenant campaign/snapshot/list lookup, campaign/outcome compatibility, UUID idempotency and normalized timezone-equivalent request hashes. A tenant/user advisory lock serializes replay and a three-pending-jobs per-user cap; export row, retry-safe dedicated queue job and content-free audit are atomic. Seven-day request expiry is recorded from DB transaction time. Same key/different parameters conflicts; replay returns the original export public ID without a second audit/job.

Reserved caller-report-export/caller.aggregate-report.v1 from generic job/export creation, generic leasing/recovery and generic completion so unfinished worker paths cannot claim success or bypass future artifact checks. Existing quality-job isolation is retained. Added unrun strict-input/fingerprint tests; source/diff reviewed, no tests/typecheck/lint/build run. Concurrency/rollback/RBAC/queue-boundary integration proof remains for final validation. No schema migration required. This internal service is deliberately not routed until dedicated worker, requester permission revalidation, artifact persistence, download checks, expiry cleanup and client lifecycle are implemented. Metadata expiry is not yet enforced cleanup; no completed export claim. Full F12 and goal remain active; no provider/production operation.


### F12 export preparation and shared report reader — 2026-10-28

Extracted the existing report query into an internal transaction-scoped reader; authenticated HTTP reporting keeps its repeatable-read wrapper and all prior filters/aggregates. Added internal export preparation for a dedicated worker: locks active job/attempt, requires reserved queue/type, locks same-tenant export, validates stored payload/metadata, verifies normalized fingerprint and original requester binding, checks allowed state/CSV/no destination, and rejects expired requests. Revalidates active nondeleted tenant/user/membership and current analytics.read using existing RBAC before calling the shared report reader. Generates explicit-field CSV, rejects output over10MiB, checks expiry and lease again after computation. No session token is persisted in jobs.

Prepared output is returned only to the future trusted worker; it is not marked completed or downloadable. Worker must use repeatable-read, persist artifact plus completion atomically and enforce current permissions again at download. Dedicated leasing/recovery, persistence, expiry cleanup, routes/UI and real concurrency/RBAC/lease acceptance remain pending. Added unrun stored-metadata validation tests; reviewed semantic report diff to confirm no aggregate behavior change. Tests/typecheck/lint/build deferred by user. No migration, provider call or production mutation. Full goal active.


### F12 atomic export artifact persistence — 2026-10-28

Authored migration174 and conservative empty-table-only rollback: bounded10MiB immutable CSV content references same-tenant artifact/export/background job/attempt, with expiry index. Insert guard requires dedicated active job lease/current attempt, exact export payload/requester/expiry binding and matching restricted PostgreSQL artifact owner/storage reference/byte length/SHA256. Updates forbidden; deletion only after expiry. Adds export_jobs(id,tenant_id) uniqueness for composite FK. Migration has NOT been applied; local DB remains173.

API adds trusted in-process completion transaction using shared preparation, repeatable-read,45s statement/5s lock timeouts. Generates restricted artifact metadata plus PostgreSQL content, rechecks active attempt, then marks export/attempt/job successful and records content-free generation audit atomically. Failure rolls back bytes/metadata/completion together. No public route or worker activation yet. PostgreSQL storage keeps bounded aggregate CSV transactional rather than relying on external file writes; no raw conversation export is implemented by this path.

Source/DDL relationships reviewed, but no schema validation or runtime tests run per deferred-validation instruction. Required final tests: lease expiry/replacement, FK cross-tenant rejection, requester mismatch, checksum/size tamper, duplicate completion, rollback after content insert, expired deletion and download authority. Dedicated leasing/recovery, artifact expiration cleanup, permission-checked download and UI remain open. Migration must be backed up/applied locally before worker acceptance. No live provider/production changes; goal active.


### F12 export status, authorized read and content expiry — 2026-10-28

Added requester-only tenant-scoped status/download services under freshly authenticated analytics.read. Status exposes public IDs/applied filters/timestamps and explicit expired/download availability, without internal artifact references or CSV. Download requires completed export, exact tenant/export/artifact owner/storage/type/privacy linkage, available nondeleted artifact, matching future expiry, UTF-8 byte size and SHA256. Records allowed artifact access in the same transaction before returning bytes; this records access, not proven browser delivery. Uses safe UUID-derived filename. Route no-store/attachment headers remain a wiring requirement.

Added trusted bounded tenant cleanup (default25/max100): expired contents selected with FOR UPDATE SKIP LOCKED, bytes deleted, artifact tombstoned and content-free expiry audit atomically written. Completed generation summary is retained; expired status is derived independently of cleanup timing. Content shared lock during download coordinates with cleanup. Added unrun Unicode byte-length/hash/tamper/null/empty integrity tests. Source reviewed, no runtime tests/typecheck/lint/build run. Migration174 remains unapplied. Dedicated worker/cleanup scheduling, route contracts/UI, final concurrent expiry/download and authorization acceptance still pending. No endpoint activated or production data touched; goal active.


### F12 dedicated export queue execution — 2026-10-28

Added tenant-scoped dedicated queue claim/recovery/failure/drain services. Claims one available job using FOR UPDATE SKIP LOCKED, creates monotonically numbered attempt and120s lease atomically. Recovers up to25 expired dedicated leases per poll; exhausted jobs enter dead_letter and their bound requester/type-matched export becomes failed. Failed transient generation retries with30s*attempt backoff, up to the existing three-attempt request cap. Explicit PostgreSQL transient error allowlist and5xx retry policy; authorization/invalid/expired/integrity failures terminate. Raw exception text never enters job/export summaries.

Drain performs bounded expiry cleanup, claims one job, invokes atomic completion and records sanitized retry/terminal result. Active attempt checks prevent stale workers from changing replaced/succeeded jobs, including lost completion acknowledgements; next poll recovers expired ownership. Added unrun retry-classification tests. Source flow reviewed; no tests/typecheck/lint/build run. Dedicated signed runtime authorization/route, worker polling config/health, public endpoint/client contracts and DB concurrency/crash acceptance still pending. Migration174 remains unapplied, so this drain is not activated. Full goal active; no provider or production execution.


### F12 signed export runtime and worker polling — 2026-10-28

Connected dedicated drain through strict empty-body1KiB/no-store signed runtime endpoint with new explicit runtime.reports.export scope. Tenant derives only from runtime authentication; scope intentionally authorizes tenant-wide aggregate processing across environments. Added default-off CALLER_REPORT_EXPORTS_ENABLED worker monitor with5s idle/1s processed polling,130s request timeout (other worker calls retain10s), bounded in-flight freshness and export counters in health output. Existing global worker flag still gates execution. No provider credentials/calls involved.

Added runtime OpenAPI path and regenerated document, unrun worker timeout/metrics/health-boundary tests and docs/report-export-worker-runbook.md covering scope, migration prerequisites, retry/expiry behavior, health limitations and backup retention. Source/diffs reviewed; tests/typecheck/lint/build remain deferred. Migration174 is still unapplied and worker not enabled. Public create/status/download endpoints and client workflow remain pending, as do real signed authorization, queue concurrency/crash and DB acceptance. Goal active.


### F12 public export endpoint contracts — 2026-10-28

Wired POST /api/v1/report-exports (strict4KiB request,202 queued/replayed), GET /api/v1/report-exports/:public_id status and GET .../download. Uses existing authenticated analytics.read services; status/download require exact requester+tenant. Rejects extra query options. All responses use no-store; CSV uses text/csv UTF8, safe UUID-derived attachment filename and nosniff. No artifact URLs/contents in status. OpenAPI fully describes filters, idempotency, pending limit, expiry, null values and generation-time semantics; generated document refreshed.

Added unrun unauthenticated/no-store checks for all three routes to existing survey integration fixture. Source/diff reviewed, no tests/typecheck/lint/build executed. Worker and migration174 activation prerequisites remain; migration is still unapplied. Client workflow, full concurrent/replay/revocation/download/expiry acceptance and the rest of goal are open. Public request acceptance is not proof of successful worker generation. No production/provider operation; goal active.


### F12 tenant aggregate export panel — 2026-10-28

Added RTK create/status/download endpoints and export panel within the existing analytics.read campaign report screen. Request freezes applied date/version/source/outcome filters and UUID idempotency key; retry after uncertain failure reuses that request even if current filters changed. Actor-scoped status cache,5s pending polling, terminal/error stop, manual refresh, explicit expiry/status, terminal new-export action and safe CSV Blob download with cache reset/URL revocation. Current report availability gates creation. Status errors suppress cached download availability; server always reauthorizes download. Component stays mounted during report refetch, so job state is not lost on date/filter requests. Parent campaign/actor keys isolate work; unmount suppresses late downloads/state updates.

Added unrun UI tests for unchanged retry key/filters, requester-scoped polling, stale-status access denial and unavailable-report gating. Existing report tests isolate export hooks. Source reviewed; no tests/typecheck/lint/build/browser run. Panel job ID currently lives in component memory; navigating away does not cancel server work, and durable history/resume discovery remains pending. Migration174 still unapplied and worker disabled; no claim of live end-to-end success. Runbook updated. Full goal remains active.


### F12 local export storage migration applied — 2026-10-28

Verified target identity haisly_caller at127.0.0.1:5432 and recorded migration173 before mutation. Took a full custom-format pg_dump under a private0700 directory/0600 file: /private/tmp/caller-export-174.hRRfzS/haisly_caller_before_174.dump. Applied migration174 and schema_migrations insert in one transaction; PostgreSQL reported table/index/function/trigger creation and the committed174 version row. Local development DB is now174. No production connection or worker activation.

Added deferred schema-validator assertions for174 table, enabled BEFORE ROW insert/update/delete guard bound to the expected function, four validated composite foreign keys, export composite identity, valid expiry index and10MiB bound. These assertions have NOT been executed; migration success is not proof of trigger behavior, authorization, concurrency or application correctness. Tests/typecheck/lint/build/browser/schema validation remain deferred. Runbook reflects local migration state; other databases require their own backup/migration. Export history/resume and end-to-end acceptance remain open along with other phases. Goal active.


### F12 export history and resume discovery — 2026-10-28

Added GET /api/v1/report-exports history with strict campaign UUID, optional public before cursor and default10/max50 page size. analytics.read plus tenant/requester/campaign-scoped query and cursor lookup; descending insertion ID keyset avoids offset drift under new requests. Only explicit public status/timestamps/applied filters are returned; expiry derived at read time, no content/storage/download authority. Invalid metadata returns conflict. OpenAPI regenerated.

Client now lazily lists My previous exports with actor-scoped cache, newest/older navigation, reset-to-newest refresh, empty/loading/error states and restored job selection. Selecting history reuses current status/download authorization; restored filters shown separately from current report filters. Navigation does not cancel server work. Stale history is hidden on loading/access errors; active create/download disables selection. Added unrun strict pagination and UI scope/paging/selection/stale-error tests. Source reviewed, no tests/typecheck/lint/build/browser run. Query-plan/load and cross-tenant/requester/campaign cursor fixtures still require final acceptance. Local migration174 applied; worker still not activated. Full goal active.


### F12 deferred PostgreSQL export lifecycle acceptance fixture — 2026-10-28

Extended the existing isolated survey dispatch/report fixture to exercise public export creation/status/history/download and real dedicated queue/atomic generation services. Authored concurrent identical-request deduplication, changed-filter409, queued download refusal, one active claim, duplicate completion refusal, completed status/content availability, CSV headers and parsed attempt/target/pending-cost/filter provenance, one stored content, unexpired retention and immutable-update/delete rejection. Added foreign-tenant status/download/history404 and post-enqueue permission revocation:403 download and generation, terminal failure with no available file, then restored original roles and replayed original request.

This fixture is wired into final integration execution but has NOT been run, per user instruction. It uses the isolated test DB, not local imported data or live providers. Source reviewed; local DB remains174, worker disabled. Still pending: same-tenant other-requester isolation, signed runtime scope acceptance, expiry-time/cleanup races, crash/lease replacement, rollback injection, query-plan/load and UI/browser acceptance. Written assertions are not completion evidence; full goal active.


### F07 verified-test temporal policy foundation — 2026-10-28

Inspected account phone verification: current service creates OTP records but does not deliver SMS in that path; it must not be treated as live test-number ownership certification. Added internal test-call eligibility policy reusing existing calling-window/timezone logic: verified-number required, allowed contact policy, complete same-number history, no active/uncertain call, recipient timezone, tenant-local quota-day match,20 accepted/reserved daily slots,5minutes after previous test end,24hours after production end and inbound-human contact, future-history rejection and platform/country hours. Temporal eligibility always returns dispatch_authorized=false.

Clarified daily quota as tenant-local calendar day in spec; unresolved claims occupy slots until definitive pre-accept rejection. Added unrun boundary/fail-closed/quota/hour tests. This is a pure policy component, not verified-number registration, a durable quota/history reader or live dispatch. Authoritative verification evidence, shared locks/counters, reservation, runtime binding,7day release-hash test/simulation certification and provider acceptance still remain. No OTP sent or real call made; tests/typecheck/lint/build deferred. Goal active.


### F07 owner-only test-number enrollment foundation — 2026-10-28

Authored migration175 for tenant test-number enrollment with canonical E164/country, immutable identity, registering owner, active/revoked lifecycle and revocation actor/reason/time. Active enrollment is explicitly NOT verification. Partial uniqueness prevents duplicate active tenant/number; shared caller-contact tenant lock and DB count guard enforce max10 active registrations. Insert/revocation requires active tenant owner/user/membership; only active-to-revoked updates allowed, historical deletes rejected. Rollback refuses populated history. Migration175 not yet applied; local DB remains174.

Added internal owner-only enrollment service using existing strict phone normalization, shared lock, duplicate replay, cap check and atomic content-free audit. Response exposes masked phone/country/public ID and always unverified/call_available=false. No customer/list insertion, OTP delivery, provider call or self-asserted verification field accepted. Added unrun schema tests rejecting caller-supplied tenant/OTP/verification claims. Source reviewed; tests/typecheck/lint/build/schema validation deferred. Registration API/UI, revocation service, authoritative delivery/ownership proof, quota/dispatch history and release test certification remain pending. Goal active.


### F07 public test-number management API — 2026-10-28

Added owner-only POST/GET /api/v1/test-numbers and POST /api/v1/test-numbers/:public_id/revoke. Enrollment returns201 new/200 replay; list uses tenant-scoped descending public-cursor pagination (default25/max50), active/all history, masked phones and explicit unverified/call_available=false. Revoked cursors remain usable for paging. All responses use no-store; mutation queries/bodies are strict and size-bounded.

Revocation locks the tenant and row, records reason/actor/time and atomic audit, replays identical reason, rejects changed-reason replay and preserves immutable history. Re-enrollment receives a fresh identity, without inherited verification. OpenAPI regenerated; schema tests authored but not run. Migration175 remains unapplied (local DB174); these endpoints require175 before use. No OTP or call sent. Client UI, authoritative ownership proof, durable quota/history and release certification remain pending. Tests/typecheck/lint/build/browser/schema validation remain deferred by user instruction; full goal active.


### F07 tenant test-number settings UI — 2026-10-28

Added owner-only test-number panel to tenant settings and dedicated actor-scoped API hooks. Users can register an international-format number, browse active/all masked registration history with older/newest navigation, and explicitly revoke a selected registration with a trimmed reason. UI states enrollment is unverified and calls unavailable; no verification claims or call buttons. Mutation failures preserve input for retry; concurrent submits blocked, mutation result caches reset, stale list hidden during fetching/errors, actor changes remount the panel and clear form state. TR/EN copy and native labeled controls use existing settings styles.

Authored deferred UI cases for owner gating/no unauthorized query, actor cache scope/remount, pagination/history filtering, stale access-error concealment, enrollment without proof, successful refresh and reason-required failed revocation retry. Tests and browser/typecheck/lint/build have NOT been run, per user instruction. Source-reviewed only. Migration175 is still unapplied; local DB174. Actual number ownership verification, quota/history persistence, provider wiring and release test certification remain open. Goal active.


### F07 local test-number migration applied — 2026-10-28

Read target identity haisly_caller at127.0.0.1:5432 and migration174 before mutation. Took a full custom-format backup under private directory/file permissions: /private/tmp/caller-test-number-175.4aDYGP/haisly_caller_before_175.dump. Applied migration175 and schema_migrations insert in a single transaction; PostgreSQL reported table/index/function/trigger creation and committed175 version row. Local DB now175; production untouched, no OTP/provider requests/calls.

Added deferred schema assertions for enrollment table, enabled BEFORE ROW insert/update/delete guard with expected function, two validated composite actor foreign keys, active tenant/phone unique index including predicate/column identity, history index and active/revoked shape constraint. Assertions not executed. Migration application is not proof of concurrent cap enforcement, revocation/auth behavior or UI correctness. Tests/typecheck/lint/build/browser/schema validation remain deferred; ownership proof, durable test quota/history and release certification remain incomplete. Goal active.


### F07 deferred test-number PostgreSQL acceptance — 2026-10-28

Added isolated _test-only integration fixture discovered by the existing integration glob. Exercises unauthenticated/strict-body rejection, normalized concurrent enrollment replay, tenant-specific same-phone identity and foreign cursor/revoke404, concurrent last-slot cap with replay allowed at cap, list pagination and active/history views, direct-SQL identity/delete/cap guards, trimmed revocation replay/conflict, revoked cursor continuity, fresh unverified re-enrollment, immutable revoked state, one audit per actual change without phone/reason, no customer creation and live role revocation403. Original role status/timestamps restored in finally; server/DB closed.

Fixture authored and source-reviewed only; NOT executed. Corrected fixture table reference to existing customers and preserved required revoked_at role lifecycle timestamp during source review. Local DB remains175. This is not evidence of runtime acceptance or provider verification; final tests/typecheck/lint/build/browser/schema validation remain deferred. Full goal active.


### F07 release-bound test certification policy — 2026-10-28

Added strict internal evidence evaluator for same tenant/environment/release hash, authoritative completed test-purpose call, ownership verification before start and nonrevoked registration, plus one completed caller-publication-v1 simulation suite with all six unique mandatory scenarios passed and external writes stubbed. Both completion times must be within the preceding seven days (exact expiry excluded), nonfuture and not before start. Incomplete history, duplicate evidence identities and malformed input fail closed. Selects newest valid evidence with deterministic tie-breaking and reports the earlier proof expiry; never combines partial suites.

Existing legacy simulation metadata is not treated as trusted publication proof. This pure component has NO public endpoint, durable evidence reader/writer or publication authorization; publication_authorized always false and preflight test gate stays pending. Authoritative provider/ownership provenance, simulation runner, storage and transaction-bound publisher integration remain required. Added unrun cases for time boundaries, scope/hash isolation, purpose/provenance/ownership, suite completeness/stubs, ambiguous records and selection. Tests/typecheck/lint/build deferred. Goal active.


### F07 immutable release simulation result storage foundation — 2026-10-28

Authored migration176 linking immutable simulation results to existing simulation_runs, caller_release_artifacts, background_jobs and job_attempts through tenant composite foreign keys. Unique result per run/job; six distinct mandatory scenario outcomes with strict JSON fields/bounds, fixed suite version, stubbed external writes required and DB-owned completion time. Insert guard locks job before attempt, requires dedicated active lease/current attempt and running pending publish_gate run in release environment, checks payload run/release/suite binding, copies run start and rechecks lease before insert. Update/delete denied; rollback refuses evidence loss. Failed/skipped results are retained but cannot satisfy certification policy.

Added API table type and reserved caller-release-simulation / caller.release-simulate.v1 constants. Generic job creation rejects queue/type, generic claim/recovery excludes queue, generic heartbeat/finish refuses it. Existing mutable simulation metadata remains insufficient for publication. No dedicated producer/runner/persistence service or evidence reader yet; provenance at those future trusted boundaries still required. Migration176 NOT applied; local DB175. Source-reviewed only; tests/typecheck/lint/build/schema verification deferred. Goal active.


### F07 atomic release simulation completion service — 2026-10-28

Added internal completeReleaseSimulation with strict release/run/suite job payload and exactly six unique bounded scenario outcomes, mandatory external-write stub attestation. Locks active dedicated job attempt, validates immutable release hash via existing reader, active tenant/environment, matching running pending publish_gate run/requester, current active membership/user and agents.manage. One transaction inserts immutable result (DB-owned completion), rechecks lease, updates simulation passed/failed, completes attempt/job and writes content-free audit. Failed/skipped suite outcomes are persisted as failed simulation while the processing job succeeds; no automatic test success or publication grant.

This is an internal trusted-runner boundary, not a public self-attestation API. Runner must actually enforce stubs and evaluate pinned release; producer/claim/recovery/runner and evidence reader are still missing. Migration176 still unapplied; local DB175. Added strict payload/output unit cases but did NOT run tests/typecheck/lint/build. Transaction rollback/lease expiry/concurrency integration acceptance remains deferred. Goal active.


### F07 release simulation request producer — 2026-10-28

Added internal authenticated request service accepting only release UUID/idempotency key (canonicalized case). Requires agents.manage and caller.campaigns.read; serializes tenant requests, replays same actor/key job, rejects changed release, re-prepares release and compares immutable hash before new work, caps pending tenant suites at five. Creates existing-schema scenario grouping and queued publish_gate run pinned to agent version/environment, dedicated retry-safe job with strict release/run/suite payload and audit in one transaction. Mutable scenario input/assertions are not the evaluator definition; versioned runner must own all six scenarios and stubs.

Generic simulation event service now refuses runs linked to the reserved release-simulation queue, including uppercase UUID requests, preventing generic runtime credentials from changing their state/events. Added unrun strict request-schema cases. Service remains internal; no public route or worker activation before claim/recovery and real evaluator implementation. Migration176 unapplied/local DB175. Source-reviewed, tests/typecheck/lint/build deferred. Goal active.


### F07 release simulation queue claim/recovery — 2026-10-28

Added dedicated tenant-scoped claim/failure primitives using job row locks and SKIP LOCKED, bounded25 expired-lease recovery, five-minute leases and monotonic attempt identities. Checks strict job/run binding and queued/running pending publish_gate/requester before claim; invalid binding dead-letters. Claim sets run start for the current attempt. Retry-safe transient failures return run to queued with cleared stale times and30s-per-attempt backoff; nonretryable/exhausted/unsafe work closes job and run with fixed sanitized failure codes. Existing complete service rechecks active lease so stale workers cannot persist after replacement. No generic worker access and no automatic publication.

Added unrun retry classification cases. Extended unapplied migration176 with partial unique tenant/run job index for dedicated queue, also supporting generic-event rejection lookup; rollback drops it after evidence guard. Producer's max3 attempts remains. Dedicated evaluator/drain loop/runtime authorization/status UI and concurrency acceptance remain pending. Local DB175/migration176 unapplied. Tests/typecheck/lint/build/schema verification deferred; no worker or external requests started. Goal active.


### F07 pinned simulation evaluator input preparation — 2026-10-29

Added repeatable-read preparation from authoritative active job/run/release/snapshot context. Re-prepares release under existing configuration locks and requires unchanged hash; returns compiled instructions, pinned survey/knowledge references/tool pins and stub_only mode, excluding recipient lists, budgets and live tool transports. Preparation rechecks lease before return. Extracted shared active context/contracts so completion and preparation consistently validate current tenant/environment/requester permissions, job metadata hash, exact snapshot agent version/agent/environment and lease/run state. Completion retains atomic result/job/run/audit writes.

Source reviewed; no model/provider request or test execution. This prepares inputs, not an evaluator or proof of successful simulations. Pinned knowledge reference retrieval, concrete runner/stub enforcement, drain/runtime/UI and final integration acceptance remain pending. Migration176 unapplied/local DB175. Tests/typecheck/lint/build deferred. Goal active.


### F07 local simulation evidence migration applied — 2026-10-29

Verified local haisly_caller identity127.0.0.1:5432 at migration175. Took full custom pg_dump with private directory/file permissions: /private/tmp/caller-simulation-176.Rnr1hj/haisly_caller_before_176.dump. Before first application, strengthened176 insert guard to require job metadata release_hash, identical nonnull requester and exact snapshot-pinned agent version/agent/environment. Applied176 plus schema_migrations insert atomically; PostgreSQL reported table/index/function/trigger creation and committed176 version. Local DB now176; no production or provider connection.

Authored deferred schema checks for result table, enabled BEFORE ROW insert/update/delete guard, four validated tenant composite foreign keys, dedicated job partial uniqueness and history index. These checks are NOT run. Successful DDL is not behavior/authorization/concurrency acceptance. Tests/typecheck/lint/build/browser/schema verification remain deferred; concrete simulation evaluator/drain runtime/UI and wider project phases remain incomplete. Goal active.


### F07 durable release simulation evidence reader — 2026-10-29

Added internal repeatable-read transaction reader for immutable simulation results joined through tenant composite identities to release/environment/run/job/attempt. Reads only same environment/release hash and recent seven-day window using DB transaction time, allowing identical-hash evidence reuse across operational-only snapshots. Validates strict job binding/suite/output, result receipt identity/passed flag, release hash metadata and succeeded current job attempt. Inconsistent provenance conflicts rather than silently becoming proof; legacy simulation status/summary is never used as certification.

Reader returns certification-compatible scenario evidence and checked time, with explicit incomplete history when1000-row bound is exceeded. It does not invent completed verified test calls or grant publication. Concrete evaluator, runtime/UI, authoritative test-call provenance and transaction-bound final publisher remain pending. Source reviewed; no tests/typecheck/lint/build run. Local DB176. Goal active.


### F07 deferred release simulation lifecycle integration fixture — 2026-10-29

Added isolated _test-only PostgreSQL integration fixture with registered owner and compiled immutable release. Exercises concurrent request deduplication/conflicting replay, single winner under concurrent claims, pinned input preparation, atomic completion and duplicate rejection, durable evidence/receipt reads and immutable deletion refusal. Expires a live lease, reclaims with a new attempt, rejects stale completion, persists a failed mandatory scenario and verifies failed run/gate, then ensures terminal infrastructure failure creates no certification evidence. Successful simulated output still leaves completed_verified_test_required when real call proof is absent.

Fixture uses explicit synthetic evaluator output only to exercise persistence/queue policy; it is NOT real model/provider acceptance. Authored and source-reviewed, NOT executed per user instruction. Final execution must cover this along with cross-tenant/scope, rollback injection and UI/runtime acceptance. Local DB176; actual evaluator/drain/runtime/UI remains pending. Goal active.


### F07 ElevenLabs current simulation invocation reader — 2026-10-29

Checked official docs: legacy simulate-conversation is deprecated; current flow uses agent-testing/create, agents/:id/run-tests and test-invocations/:id. Sources: https://elevenlabs.io/docs/api-reference/tests/run-tests and https://elevenlabs.io/docs/api-reference/tests/test-invocations/get and https://elevenlabs.io/docs/eleven-agents/customization/agent-testing . System/workflow tools are not mocked by provider test mocking; provider pass alone cannot attest external-write isolation.

Added fixed-origin GET-only invocation reader with existing2MiB bounded JSON helper,10s timeout, no redirects/retries, sanitized failures and credential guard. Requires explicit invocation/agent/branch/version and six unique scenario/test bindings; checks every run identity, simulation type, non-draft and single repeat. Returns only statuses/condition observations; strips transcript/rationale/user metadata. Pending/cancelled/unknown remain explicit; publication_authorized=false, no external_writes_stubbed claim. Added unrun parser and transport cases. No secret read, live API request, test creation or execution occurred; only public documentation fetched. Trusted test definitions/config overrides/system-tool isolation, durable invocation binding/submission reconciliation and worker remain open. Tests/typecheck/lint/build deferred. Goal active.


### F07 release-bound simulation definitions — 2026-10-29

Added server-owned versioned definitions for all six mandatory scenarios: refusal, tenant-wide opt-out, uncertain answer, unsupported information, injected tool failure and transfer/follow-up. Each specifies persona, success criteria and required independent runner observation. Preparation includes these definitions with a deterministic hash binding both rubric and release hash. Definitions explicitly require synthetic state, isolated system/workflow tools and pinned knowledge; missing observations cannot pass. Execution remains unauthorized. These are internal evaluator contracts, not submitted provider test payloads or completed isolation evidence.

Added unrun tests for release binding, complete scenario coverage and mutation isolation. No tests/typecheck/lint/build or live provider requests were run. No schema/client behavior change; DB remains176. Provider configuration compilation, persisted definition/invocation binding, isolated execution and authoritative completion mapping remain pending. Staging/SIP/test line unavailable as confirmed by user; offline development continues. Goal active.


### F07 in-memory simulation tool sandbox — 2026-10-29

Added a per-scenario in-memory tool harness accepting server-owned static fixtures and existing Zod input/output contracts. No live handler, database or network transport is supplied. Unknown tools/invalid arguments fail closed, tool_error injects opt-out failure, fixtures and returned observations are detached from caller mutations. Maximum32 calls and32 registered tools,64KiB per fixture; observations retain only registered tool/operation/outcome without arguments or recipient data. Rejection and limit exhaustion remain explicit and cannot be mistaken for successful tool evidence.

Authored unrun tests for injected failure, invalid/unknown calls, bounded execution, mutation isolation and invalid/duplicate registration. Harness is an internal building block, NOT proof a provider run routes all tools through it. Provider system/workflow interception, real tool-contract fixture mapping, observation evaluation and durable runtime binding remain pending. No tests/typecheck/lint/build/provider calls run. DB176 unchanged; no client behavior change. Goal active.


### F07 simulation criterion and observation evaluation — 2026-10-29

Added strict internal scenario evidence evaluation bound to release and definition hashes. Requires complete unique criterion indices, completed execution, loaded pinned knowledge and independently attested tool interception. Rejects mismatched scope and malformed/ambiguous evidence as skipped; positive model judgments cannot override rejected tools, exhausted tool budgets, fabricated customer intent or bypassed error injection. Refusal, opt-out, error and transfer scenarios require corresponding sandbox observations. Always publication_authorized=false.

Authored unrun evaluator cases for missing observations, hash mismatch, isolation/knowledge gaps, duplicate/unknown criteria, policy violations and error injection. No tests/typecheck/lint/build/provider calls run. This remains an internal evaluator, not a public self-attestation route: trusted runner wiring, independent flag provenance, durable evidence linkage and provider execution remain pending. DB176 unchanged; client behavior unchanged. Goal active.


### F07 bounded simulation worker orchestration — 2026-10-29

Connected dedicated queue claim, pinned preparation, six sequential scenario executions, strict evidence binding/evaluation and atomic completion through an internal one-item worker. No executor means disabled without claiming work. Four-minute abort budget stays below five-minute lease; cancellation/late responses cannot write results. Every scenario requires positive independently sourced isolation evidence before external_writes_stubbed can be persisted. Failed criteria persist as failed certification, not infrastructure failure.

Before entering an executor, worker durably disables retry_safe under active lease lock so crash/lease recovery cannot blindly repeat uncertain provider work. Preparation-only transient errors retain existing bounded retries; executor errors are terminal, and uncertain completion/lease loss returns unresolved for recovery. Added unrun lifecycle fixture coverage for disabled executor, all-six failed criteria completion and terminal executor failure without extra proof. No tests/typecheck/lint/build/provider requests run. No concrete provider executor, runtime activation, durable provider submission reconciliation or live acceptance yet; no customer calls enabled. DB176 unchanged, client unchanged. Goal active.


### F07 tenant-authorized release simulation status reader — 2026-10-29

Added repeatable-read polling service requiring agents.manage and caller.campaigns.read. Release and dedicated job/run are tenant-bound; payload/hash/requester identity must match. Completed status requires immutable result, current succeeded attempt and matching receipt/passed flag. Returns explicit safe projection: status, attempts, recovery-pending, retry time, timestamps and six scenario outcomes; only allowlisted infrastructure error codes, no prompt/provider body/arbitrary metadata. Always publication_authorized=false; historical status does not grant seven-day certification.

Extended unrun lifecycle fixture with completed status projection and unknown job rejection. No endpoint/OpenAPI/client polling UI wired yet; reader is the service boundary for that next slice. No tests/typecheck/lint/build/provider calls run. DB176 unchanged. Goal active.


### F07 release simulation status HTTP contract and client query — 2026-10-29

Exposed GET /api/v1/caller-releases/:release_public_id/simulations/:job_public_id through shared controller validation/context and existing authorized status service. Strict UUID params and empty query; no-store on success/errors. Added complete OpenAPI response/error contract and regenerated openapi.json (generation only, no validation). Client has typed RTK query with viewerScope in cache identity and zero unused retention; no request/execute mutation enabled.

Extended unrun integration fixture for successful HTTP projection, anonymous401, cross-tenant404, invalid query400 and cache headers. No tests/typecheck/lint/build/browser/provider calls run. Status panel and campaign navigation remain pending; provider executor unavailable and no real calls enabled. DB176 unchanged. Goal active.


### F07 release simulation status page — 2026-10-29

Added protected deep-link page /app/caller-releases/:releaseId/simulations/:jobId requiring agents.manage and caller.campaigns.read. TR/EN labels show attempt/recovery/retry status, six scenario results and explicit notice that simulation success alone does not authorize publication. Invalid UUIDs do not query; tenant/user/release/job keys remount the panel. Active work polls every5seconds only in visible tab; completion/access errors stop polling, and access errors hide stale results. Added route/path helper and page title mapping.

Authored unrun UI cases for scoped query, outcome/publication wording, stale-result suppression, visible-tab polling and stopping on completion. No tests/typecheck/lint/build/browser/provider calls run. Page currently reachable via deep link; campaign test-history discovery/navigation and actual simulation request activation remain pending. No schema/API behavior changes this slice; DB176. Goal active.


### F07 campaign simulation history navigation — 2026-10-29

Added tenant/campaign-scoped descending job-keyset history service and GET /api/v1/release-simulations, requiring agents.manage plus caller.campaigns.read, strict query and no-store. Joins dedicated jobs through pinned releases/snapshots; validates payload/hash and scopes cursors to same campaign. OpenAPI regenerated. Client history query includes actor scope; saved campaign panel opens history on demand with newest/older navigation and direct links to simulation status. Errors/loading hide stale links; no launch mutation enabled.

Authored unrun HTTP history pagination/cross-tenant tests and UI link/cursor/access-loss cases. No tests/typecheck/lint/build/browser/provider calls run. DB176 unchanged. Concrete provider executor, invocation reconciliation and test initiation remain pending. Goal active.


### F07 lease-bound pinned knowledge access for simulation executors — 2026-10-29

Preparation now resolves sealed snapshot knowledge pins before evaluator execution. Worker supplies a server-bound knowledge search/fragment capability tied to tenant, job, attempt and immutable release identity. Adapter inputs cannot override snapshot/tenant; each repeatable-read operation reauthorizes active requester/context, checks release hash, reuses existing sealed-version/checksum/source-availability gates and rechecks lease after content read. Abort and a64-read suite budget prevent stale/unbounded access; existing search timeout and bounded4,000-character fragments remain enforced. No transport/credentials exposed.

Extended unrun lifecycle fixture with empty pinned manifest search, foreign-version/snapshot override rejection, abort rejection and rejection after job completion. No tests/typecheck/lint/build/provider requests run. This supplies pinned access, not proof that an evaluator actually grounded all claims; concrete provider executor and independently verified knowledge evidence remain pending. DB176/client unchanged. Goal active.


### F07 immutable simulation definition binding — 2026-10-29

Migration177 adds nullable historical definition_hash to immutable results and an insert guard requiring a non-null hash matching the locked job metadata. New requests pin the current definition hash, active context rejects changed/legacy definitions, completion requires the executor's captured hash, and publication evidence reads only the current definition hash. Historical unbound results remain unchanged and cannot certify current definitions. Rollback refuses to discard bound evidence. Added unrun integration rejection for wrong completion hash.

Local haisly_caller migration177 applied transactionally after private custom-format backup /private/tmp/caller-simulation-177.OeqOe6/haisly_caller_before_177.dump; committed version row read. This is migration application evidence, not behavioral/schema validation. No tests/typecheck/lint/build/provider calls run. Client historical status remains informational; concrete provider executor and final publisher remain pending. Goal active.


### F10 transfer destination validation and eligibility — 2026-10-29

Compared legacy handoff request/presence/queue services with F10: existing records are not real SIP transfer proof and do not supply atomic destination/capacity policy. Added strict administrator destination contracts for E.164 and restricted SIP/SIPS user@host[:port] (no password/header/query/parameter injection), runtime selection accepts only stored destination UUID. Added team IANA timezone, bounded weekly windows/holidays and capacity contract.

Internal eligibility checks tenant/environment, active call, human request, no pending transfer, verified active destination/team, SIP REFER plus authoritative success event capability, reserved transfer budget and complete occupied-capacity evidence. Team opening hours intentionally do not inherit outbound09–20 clamp; exclusive closing boundary and holiday rules apply.30-second answer timeout; transfer_authorized=false until atomic reservation/provider execution exists. Authored unrun scope/capacity/capability/hour/holiday/verification/injection tests. No tests/typecheck/lint/build/live provider calls run. F10-T01 remains partial: durable target configuration/API/UI and atomic capacity claims next; staging unavailable. F07 concrete executor remains pending. DB177 unchanged. Goal active.


### F10 durable transfer configuration schema — 2026-10-29

Migration178 adds one versioned transfer team policy per tenant/environment/team (IANA zone, bounded hours JSON, capacity) and named phone/SIP allowlist destinations bound through composite tenant foreign keys. Active destination duplicates within policy are rejected; history index, immutable identity/scope, automatic version increment and archive-instead-of-delete guards added. API Kysely types wired. Configuration intentionally contains no ownership/provider verification authority; runtime cannot treat enrollment as verified. Rollback refuses existing records. Added unrun schema guard assertions.

Local haisly_caller migration178 applied in one transaction after private custom-format backup /private/tmp/caller-transfer-178.mepqLh/haisly_caller_before_178.dump; version row confirmed. No schema validation/tests/typecheck/lint/build/provider calls run. Full field/API validation remains required (DB checks are defense in depth, not full policy validation). Management API/UI, verification and atomic transfer capacity claims remain pending. Goal active.


### F10 transfer team policy management service — 2026-10-29

Added create/get/list/update service requiring both agents.manage and users.manage, reusing tenant mutation receipts, optimistic version checks and atomic audits. Creation resolves same-tenant team/environment and locks active scope; unique DB policy per environment/team prevents duplicates. Updates preserve scope, reject exhausted/stale versions and let operators archive policy even after team/environment deactivation. Tenant/team-scoped bounded history cursor rejects foreign cursors. Responses validate stored schedule and always transfer_authorized=false. Audit entity maps to caller_transfer_team_policy without schedule/target payload.

Authored unrun strict-contract cases rejecting runtime authority/tenant overrides, scope edits, empty updates and excessive pages. No tests/typecheck/lint/build/provider calls run. HTTP contract, destination CRUD, management UI and transactional integration verification remain pending. Local DB178 unchanged. Goal active.


### F10 allowlisted transfer destination management service — 2026-10-29

Added destination create/list/update services requiring agents.manage and users.manage, tenant mutation serialization/receipts and optimistic version checks. Targets resolve an existing same-tenant team policy and active team/environment; archived parents prevent creation/reactivation while archival remains possible. Tenant/policy-scoped keyset listing includes archived history. SIP host casing and numeric port canonicalized while preserving case-sensitive user. Strict payload excludes ownership/dispatch authority and scope changes. Audit stores only version/archive state, not target address. All responses remain verification_status=unverified and transfer_authorized=false.

Shared active-team/environment lock helper reused by policy and destination services. Authored unrun normalization/authority/scope/page contracts. No tests/typecheck/lint/build/provider calls run. Management HTTP/UI, transaction integration tests and authoritative target verification remain pending. Local DB178 unchanged. Goal active.
