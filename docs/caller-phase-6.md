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
