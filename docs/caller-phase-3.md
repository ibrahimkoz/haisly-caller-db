# Caller Faz 3 — Dosya aktarımı

## 20 Ekim 2026 — Ayrıştırma ve özel depolama temeli

F03-T01 kısmi uygulandı. API içinde `contact-import` servis katmanı, typed dosya/hücre/satır sözleşmeleri ve ayrı parser süreci eklendi. Henüz upload endpoint'i, DB import-job/row modeli, kuyruk bağlantısı veya client import ekranı yoktur. Kullanıcı bu dilimle henüz toplu aktarım başlatamaz; kişi/izin/DNC kayıtlarına hiçbir yazma yapılmaz. DB migrationı yok; yerel şema 087 seviyesindedir.

### Dosya sınırları ve davranış

- XLSX: imza ve uzantı/MIME kontrolünden sonra ZIP girdileri sırayla ve dosya çıkarmadan okunur. Hem bildirilen hem gerçek açılım sayılır; toplam 100 MiB, 2048 girdi sınırı vardır. Şifreli, makrolu, embedded/ActiveX, dış bağlantılı, yinelenen veya traversal içeren girdiler reddedilir. Binary ZIP parçaları da muhafazakâr olarak reddedilir.
- XLS: yalnız OLE/BIFF8 kapsayıcı kabul edilir; `.xls` diye adlandırılmış HTML/XML kabul edilmez. SheetJS macro/CFB bilgileri kontrol edilir. Şifreli veya ayrıştırılamayan workbook güvenli hata kodu döndürür.
- CSV: fatal UTF-8 çözümleme, opsiyonel BOM, varsayılan virgül; servis çağrısında açık noktalı virgül/tab seçimi. Tırnaklı ayraç ve çok satırlı hücre desteklenir. Hatalı tırnak/binary veri reddedilir. Kayıt numarası fiziksel metin satırı değil mantıksal CSV kayıt sırasıdır.
- Ortak limitler: 10 MiB giriş, başlık + 50.000 veri satırı, 64 kolon, 500.000 hücre, hücre başına 4096 karakter, CSV kaydı 64 KiB. Bu ek kaynak limitleri yükleme/eşleme ekranında açıklanmalıdır. Çok sayfalı workbook sessizce ilk sayfaya indirgenmez; tek tablo içeren dosya istenir. Boş ve aşırı büyük seyrek tablolar reddedilir.
- Formül hücresi çalıştırılmaz; cached sonucu da kullanılmaz, hücre `formula` hatası taşır. Metin içindeki spreadsheet expression başlangıçları da işaretlenir; `+90...` gibi telefon metinleri korunur. Hyperlink/uygunsuz hücre türleri hata taşır. Önizleme/aktarımı uygulayan sonraki katman bu hataları satır hatasına dönüştürmelidir. Header doğrulaması, telefon normalizasyonu ve kolon eşlemesi bu parserın sorumluluğu değildir.
- Ayrı Node süreci: 15 saniye duvar saati, 256 MiB V8 heap, API süreci başına en fazla iki parser. Hata/timeout sonucu generic kod; stderr ve ortam sırları aktarılmaz. Bu bir OS sandbox/RSS sınırı değildir; gerçek worker dağıtımında OS/container bellek sınırı ve kuyruk kapasitesi ayrıca uygulanmalıdır. Kaynak TS ve derlenmiş JS girişleri desteklenir; build parser worker çıktısını üretir.

### Saklama sözleşmesi

`ImportFileStore` 32 baytlık deployment anahtarı ve uygulamaya ait mutlak özel dizin ister. Dosyalar AES-256-GCM ile şifrelenir; tenant, rastgele UUID ve son kullanım zamanı authenticated data'ya bağlıdır. Dosya adı kullanıcıdan alınmaz. Dizinler 0700, dosyalar 0600; mevcut gevşek izinli dizin, tenant dizini veya dosya symlink'i reddedilir. Depolama kökünün üst dizinleri güvenilir deployment alanı olmalıdır; bu dizin hiçbir static/public mount altına konulmamalıdır. Hash ve son kullanım zamanı döner; ham dosya veya key loglanmaz.

Yedi gün sonra okuma reddedilir. Fiziksel silme/retention job'u F03-T04'te yapılacaktır; bu temel tek başına silme yapmaz. Depolama servisi tenant yetkilendirmesi yerine geçmez: upload/download/import endpoint'leri server-side tenant ve izin, audit, idempotency, kullanıcı/tenant kota ve rate-limit kontrolü yapmalıdır. Upload route açılmadan önce anahtar/dizin konfigürasyonu, dosya DB kaydı, atomik sahiplik, orphan temizliği ve kapasite politikası bağlanmalıdır. Ayrıştırıcı ve depolama hazır olması üretime açılma onayı değildir.

Makro/aktif içerik engelleme ve ayrı süreç antivirüs taramasının eşdeğeri değildir. Ham dosyayı çalıştıran veya public olarak sunan bir yol eklenmedi. Dosyaların tarama/depolama politikası worker entegrasyonunda yeniden kontrol edilir.

### Bağımlılık kararı

SheetJS CE 0.20.3 resmî HTTPS tarball'ından sabitlendi; package-lock integrity kaydı içerir. Npm registry'deki eski `xlsx` dağıtımı kullanılmadı. csv-parse 7.0.3 ve yauzl 3.4.0 exact sürümleri, @types/yauzl 3.4.0 eklendi. Kurulum scriptleri kapalı çalıştırıldı. 20 Ekim 2026 npm audit tüm seviyelerde 0 bulgu. Bu sonuç tarama anındaki bilinen bulgularla sınırlıdır; CDN paketleri için üreticinin duyuruları ayrıca incelendi: CVE-2023-30533 ve CVE-2024-22363 eski sürümleri kapsar.

Kaynaklar:
- [SheetJS resmî kurulum](https://docs.sheetjs.com/docs/getting-started/installation/nodejs/)
- [SheetJS güvenlik duyuruları](https://cdn.sheetjs.com/advisories/)
- [ReDoS advisory](https://github.com/advisories/GHSA-5pgg-2g8v-p4x9)
- [yauzl lazy entry ve boyut doğrulaması](https://github.com/thejoshwolfe/yauzl)
- [CSV max record size](https://csv.js.org/parse/options/max_record_size/)

### Sıradaki dilim

Upload/kalıcı job sözleşmesi ve DB modeli; şablon, kolon/ülke eşlemesi, yazmadan önizleme, mükerrer/çakışan satırlar. Ardından kullanıcı onaylı batch worker, sonuç/iptal/yeniden deneme ekranı ve yedi günlük fiziksel temizleme. Mevcut kişi/DNC/izin servislerinin korunması ve tekrar aktarımda tekillik entegrasyon testlerinde doğrulanacak. F03-T01–T04 henüz kapatılmadı.

### Doğrulama

API `verify:ci`: 113 test geçti, 0 atlandı; typecheck, lint, API/worker/parser build ve OpenAPI kontrolleri başarılı. Yeni 14 test CSV/XLS/XLSX, gerçek BIFF formula hücresi, limitler, bozuk/encrypted ZIP, yanıltıcı açılım boyutu, traversal/aktif içerik, şifreli depo, tenant/key/tamper izolasyonu, süre sonu ve symlink reddini kapsar. Derlenmiş JS parser ile CSV smoke testi ayrıca geçti. Testler izole `haisly_caller_phase1_test` DB kullanır; üretim veya yerel iş verisi değiştirilmedi. Npm audit 0 bulgu. DB/client runtime değişmedi; bu repolarda yalnız faz notu eklendi.


## 20 Ekim 2026 — Kalıcı yükleme ve önizleme API'si

F03-T01 yükleme bağlantısı ve F03-T02 önizleme backend'i eklendi. `POST /api/v1/contact-import-previews` JSON içinde base64 dosya, hedef liste public ID'si, MIME/isim, opsiyonel ayraç ve sıfır tabanlı kolon eşlemesi alır. İlk kayıt başlıktır; telefon kolonu zorunlu, ad/soyad/ünvan ve yerel numaralar için varsayılan ülke seçilebilir. Aynı kolon iki alana bağlanamaz. Şablon `GET /api/v1/contact-import-previews/template` ile boş UTF-8 CSV olarak indirilir. Henüz tarayıcı yükleme/eşleme ekranı yoktur.

`GET /api/v1/contact-import-previews/:public_id` 1–100 satır ve `after` kayıt numarasıyla sayfalı sonucu döndürür. Özet geçerli/hatalı/mükerrer sayısını içerir. Formül içeren satırlar eşlenmemiş kolonlarda bile reddedilir. Aynı normalize telefondaki tamamlayıcı boş alanlar ilk temsilci kayıtta birleştirilir; tüm dolu değerler uyuşuyorsa diğer satırlar temsilci satıra bağlanır. Çelişki veya aynı telefon grubunda hatalı satır varsa grup hata olarak ayrılır. Son satırın rastgele üstün gelmesi engellendi.

**Bu önizleme yalnız dosya içi doğrulamadır.** Geçerli satır, yeni kişi veya aramaya uygun kişi anlamına gelmez. Mevcut DB kişisi/kimlik revizyonu, dolu alan güncelleme farkı, legacy numara claim'i, DNC/izin ve liste üyeliği kontrolü onaylı uygulama aşamasında güncel kayıt üzerinden ayrıca yapılacaktır. Bu dilim mevcut kişi, üyelik, izin veya DNC kaydını değiştirmez. Toplu kayıt/iş kuyruğu/iptal ve hata raporu indirme henüz uygulanmadı.

### Kalıcılık ve güvenlik

088 migrationı `contact_import_previews` ve `contact_import_preview_rows` tablolarını ekler. Tenant-list-user composite FK'ları ve satır-parent tenant FK'sı başka tenant kaydının bağlanmasını engeller. Önizleme ve satırları, receipt ve audit aynı DB transaction'ında kaydedilir; satırlar 500'lük insert gruplarıyla yazılır. Gerekli izinler `caller.contacts.manage` ve `caller.lists.manage`; upload body okunmadan auth kontrolü, ardından servis/mutation yetki kontrolü vardır. Arşivlenmiş liste reddedilir; hedef liste transaction içinde yeniden kontrol edilir.

Dosya 10 MiB, JSON gövde 14 MiB ile sınırlı. Upload mevcut hassas endpoint rate-limit mekanizmasına bağlandı. Tenant başına saklanan en fazla 20 önizleme vardır; fiziksel temizleme bağlanana kadar süresi dolan kayıtlar da bu kotaya dahildir. Idempotency payload özeti dosya hash'i/eşleme/hedef/format/ayracı kapsar; eşzamanlı aynı istek bir receipt ve bir önizleme döndürür. Receipt ve audit dosya, telefon veya isim taşımaz. Cevaplar `Cache-Control: no-store`. CORS izinli başlıklarına mevcut mutation sözleşmesinin Idempotency-Key ve If-Match başlıkları eklendi.

Dosya store başarılı, DB işlemi başarısız olursa DB'de referans bulunmadığı doğrulandıktan sonra dosya silinir. Commit sonucu belirsiz/DB erişilemez ise dosya korunur; orphan uzlaştırma ve fiziksel temizleme F03-T04'te tamamlanmalıdır. Önizleme satırları DB'de kişi verisi içerir; süresi dolan okuma reddedilir fakat fiziksel satır/dosya silme job'u henüz yoktur. Genel preview kayıtları kalıcı özet saklama işine F03-T04'te bağlanacak. API'yi üretime açmadan bu operasyonel işleri tamamlamak gerekir.

### Konfigürasyon ve rollout

API için `CONTACT_IMPORT_STORAGE_DIR` mutlak özel dizin ve `CONTACT_IMPORT_ENCRYPTION_KEY` 32 baytlık hex secret gerekir. Biri eksik/geçersizse başlangıç reddedilir; ikisi yoksa upload 503 döndürür. Anahtar depolanan dosyalar boyunca korunmalı; key rotation ayrı planlanmalıdır. Yerel API `.env` dosyasına secret gösterilmeden konfigürasyon eklendi; dosya Git dışında ve 0600. Çalışan süreç konfigürasyonu başlangıçta okur; yeniden başlatma gerekebilir.

Yerel `haisly_caller` 088 seviyesine geçirildi. Önce `backups/haisly-caller-pre-import-preview-2026-10-20/haisly_caller.dump` alındı, arşiv listesi kontrol edildi (tam restore provası değil). Önce/sonra 421 kişi, 588 çağrı, 0 liste üyeliği korunuyor; yerel önizleme sayısı 0. Production inbound sunucuya işlem yapılmadı. 088 boş rollback'i destekler; dolu önizlemeler varken veri kaybını engellemek için rollback reddedilir. API yeni migrationdan sonra dağıtılmalıdır.

### Doğrulama

API tam `verify:ci`: 118 test geçti, 0 atlandı; tip/lint/build/OpenAPI başarılı. Tenant/yetki ayrımı, eşzamanlı replay, farklı payload çakışması, sayfalama, composite FK reddi, süre sonu, audit PII sınırı, mevcut DNC/profil/sürüm ve üyeliklerin değişmemesi doğrulandı. Sıfır izole DB'de 88 migration, boş rollback/reapply, seed/fixture ve şema doğrulaması geçti. Dolu rollback'in reddi ayrı transaction'da doğrulandı. Client runtime değişmedi; arayüz E2E'si bu dilimde kapsam dışı. Sırada kolon eşleme/önizleme arayüzü ve mevcut kayıt farkları; sonra açık onaylı asenkron aktarım var. F03-T01/T02 bütün uçtan uca akış kapanana kadar kısmi, F03-T03/T04 açık.

Son güvenlik taraması: npm audit tüm seviyelerde 0 bulgu. Parser kapasite hatası 429, parser süreç/timeout hatası 503; bozuk dosya/eşleme 400 döndürür. Son hata sınıflandırması sonrası typecheck geçti.


## 20 Ekim 2026 — Dosya yükleme, kolon eşleme ve önizleme ekranı

Liste detayına CSV/XLS/XLSX yükleme, CSV ayraç seçimi, şablon indirme, gerçek dosya başlıklarıyla kolon eşleme ve yerel telefonlar için ISO ülke seçimi eklendi. Telefon zorunlu; isim, soyisim ve ünvan opsiyonel. Aynı kolon birden fazla alana eşlenemez. Dosya boyutu/türü istemcide de kontrol edilir; asıl doğrulama API'dedir.

Yeni `POST /api/v1/contact-import-previews/inspect` dosyayı mevcut izole parser ile okuyup başlıkları ve veri satırı sayısını döndürür; DB veya dosya deposuna kayıt oluşturmaz. Önizleme oluşturmayla aynı yetki, tenant/liste, arşiv, body limiti ve hassas endpoint rate-limit kontrollerine bağlıdır. Başlığı hatalı veya veri satırı olmayan dosyalar reddedilir.

Kullanıcı eşlemeyi onaylayınca kalıcı önizleme hazırlanır. Ekran geçerli/hatalı/mükerrer satır sayılarını, satır hatalarını, temsilci satırı ve erişim bitişini sayfalı gösterir. Dosya içeriği düz metin olarak görüntülenir. Ağ/sunucu hatasında değişmeyen eşleme aynı idempotency anahtarıyla yeniden denenir. Yükleme/hata/boş durumları ve klavye odağı ele alınır; arşivli liste ve eksik yetkiyle yükleme açılmaz.

Bu adım yalnız dosya içi önizlemedir: kişi, liste üyeliği, izin veya DNC değiştirmez ve arama başlatmaz. Mevcut DB kaydıyla farkların gösterimi, kullanıcı onaylı asenkron toplu kayıt, iptal/sonuç ekranları ve fiziksel temizleme sonraki dilimlerdir. F03-T01/T02 kısmi, F03-T03/T04 açık kalır. Yeni migration yoktur; DB 088 seviyesindedir. DB reposunda yalnız faz notu güncellendi.


Doğrulama: API `verify:ci` 118/118 test, tip/lint/build/OpenAPI başarılı. Client 75 dosyada 307/307 test, typecheck/build başarılı; lint 0 hata ve önceden mevcut 6 uyarı. Build mevcut büyük chunk uyarısını veriyor. 390 ve 1440 px Chromium'da aktarım önizlemesi ve mevcut liste üyeliği akışları toplam 4 testle geçti; eşleme/önizleme ekran görüntüleri incelendi. Tarayıcı testleri mock API kullanır; backend davranışı ayrı entegrasyon testlerinde doğrulandı. Yeni bağımlılık eklenmedi. Üretim dağıtımı yapılmadı.


## 20 Ekim 2026 — Önizlemede mevcut kayıt karşılaştırması

F03-T02 kapsamında önizleme satırları tenantın güncel kişi ve liste üyeliği kayıtlarıyla karşılaştırılır. Geçerli temsilci satır için yeni/mevcut kişi veya eski numara eşleşmesi incelemesi ayrımı; mevcut üyelik, arşiv/kimlik incelemesi engelleri ve aranmama bilgisi döner. Hatalı/mükerrer satırlar kişiyle eşleştirilmez. Önizlemenin sayısal özeti dosya doğrulamasını anlatmaya devam eder; aktarılabilir kişi veya arama uygunluğu sayısı değildir.

Dolu alan farklarında mevcut ve gelen değer gösterilir, varsayılan etki mevcut değeri korumaktır. Boş mevcut alanlar için tamamlama önerilir; dosyadaki boş hücre mevcut değeri silmez. Aranmama engeli aktarım onayıyla kaldırılamaz. Dolu alanı değiştirme onayı bu dilimde alınmaz; asenkron aktarımın onay sözleşmesine bağlanacaktır.

`GET /api/v1/contact-import-previews/:public_id` cevabına satır bazında `comparison`, üst seviyede `compared_at` ve `target_list_archived` eklendi. Karşılaştırma her okuma/yenilemede, en fazla 100 satırlık sayfa (bir sonraki sayfa için 1 ek satır) üzerinde yapılır. Metadata/satırlar/kişi/üyelik aynı repeatable-read transaction snapshot'ından okunur. Dönen kişi public ID, version ve identity revision gelecekteki uygulama kontrolüne girdidir; kalıcı onay veya kilit değildir. Uygulama workerı kişi sürümü/kimliği, liste, üyelik ve tercihler dahil tüm kuralları yazma anında yeniden kontrol etmelidir.

Legacy numara kontrolü manuel kişi oluşturma ve önizlemede ortaklaştırıldı: normalize edilmemiş/belirsiz eski telefon claim'i yeni kişi önerisini engeller. Tenant filtreli parametrik EXISTS kontrolleri mevcut telefon indexlerini kullanabilecek biçimdedir; kişi/üyelik eşleşmesi tek sayfalı sorgudadır, uygulama katmanında N+1 sorgu yoktur. Karşılaştırma kaydetme veya kişisel veri kopyasını saklama işlemi yapmaz. Yeni migration yok; yerel DB 088 seviyesinde kalır.

Client mevcut/gelen değerleri, boş alan tamamlama ve dolu alan koruma etkilerini, üyelik ve engel açıklamalarını gösterir. Karşılaştırma yenilenebilir; okuma hatasında eski sonuç gösterilmez. Eski API sürümü comparison alanını göndermiyorsa yeni kişi varsaymak yerine karşılaştırmanın alınamadığı belirtilir. Önce API, ardından client dağıtılabilir; additive sözleşme ve şema değişikliği olmaması geri dönüşü kolaylaştırır. Üretime dağıtım yapılmadı.

F03-T01/T02 bütün aktarım akışı tamamlanana kadar kısmi; F03-T03/T04 açık. Sıradaki dilim ayrı dolu-alan onayıyla kalıcı import işi, batch worker, sürüm/kimlik değişiminde güvenli çatışma davranışı ve sonuç/iptal akışıdır. Fiziksel 7 günlük temizleme ve hata raporu ayrıca tamamlanacaktır.


Doğrulama: API tam `verify:ci` 118/118 test; typecheck/lint/build/OpenAPI başarılı. Mevcut DNC/profilin değişmemesi, tenantlar arasında aynı numaranın karışmaması, üyeliğin yenilemede değişmesi, boş alan tamamlama/dolu alan koruma, boş girdinin dolu alanı silmemesi, legacy claim ve arşiv/kimlik engelleri entegrasyon testinde doğrulandı. Ortak legacy kontrolünün manuel kayıt regresyonları da geçti. Client 76 dosyada 310/310 test, typecheck/build başarılı; lint 0 hata ve mevcut 6 uyarı, build mevcut büyük chunk uyarısı. 390/820/1440 px Chromium'da 3 akış geçti, ekran görüntüleri incelendi; browser API'si mock, backend doğrulaması ayrı test DB'dedir. XSS metni, Türkçe engel açıklamaları ve eski API fallback'i bileşen testinde kapsandı. API/client npm audit 0 bulgu; bağımlılık değişmedi.

Sorgunun eşdeğer SQL şekli test DB'de EXPLAIN ANALYZE ile incelendi: satır PK, canonical telefon ve üyelik indexleri kullanıldı; küçük fixture'da claim tabloları için planner sequential scan seçti. Dört satırlık fixture ölçümü yük/50.000 satır kapasite testi olarak yorumlanmamalı. Yeni query başına iş sayfalıdır; tam ölçek performans kabulü worker/operasyon fazında ayrıca yapılacaktır.


## 20 Ekim 2026 — Onaylı aktarım işi ve batch worker backend'i

F03-T03 backend dilimi: `POST /api/v1/contact-import-previews/:public_id/approve` zorunlu `confirm_valid_rows: true` ve Idempotency-Key ile geçerli temsilci satırları kalıcı işe dönüştürür. Önizleme başına tek iş vardır. Aynı anahtarla eşzamanlı/tekrar istek aynı işi döndürür; başka anahtarla aynı önizlemeyi ikinci kez başlatma 409'dur. Hatalı ve mükerrer satırlar işleme alınmaz, skipped sayısında korunur. Varsayılan davranış boş profil alanlarını doldurmak ve dolu alanları korumaktır; boş gelen hücre hiçbir dolu alanı silmez.

Dolu alan güncellemesi için `overwrites` içinde satır numarası, kişi public ID'si, sürümü, kimlik revizyonu ve seçilen alanlar açıkça gönderilir. Tek istekte en fazla 1.000 overwrite satırı; diğer geçerli satırlar varsayılan koruma politikasıyla işlenir. Eski sürüm/kimlik onayı bütün onay transaction'ını geri alır. Onay anında her satırın kişi kimliği/sürümü snapshot olarak saklanır. İşlenmeden önce kişi değişmişse veya yeni beklenen numara artık başka kayıtta bulunuyorsa satır `contact_changed` olur; sessizce birleştirme/üzerine yazma yapılmaz. Yeniden değerlendirme yeni önizleme ve onay gerektirir.

089 migrationı `contact_import_jobs` ve `contact_import_job_rows` tablolarını, tenant composite FK'larını, tek iş/önizleme ve tek satır/iş kısıtlarını ekler. Onay snapshot'ı ve mevcut background_jobs kuyruğuna ekleme aynı transaction'dadır. Queue `caller-foundation`, tip `contact-import.apply`, en fazla 5 attempt ve retry_safe=true. Queue payload'ı PII taşımaz; iş satırlarında profil kopyası yerine beklenen public ID/sürüm tutulur.

Worker DB'ye doğrudan erişmez. İmzalı runtime isteği ve `runtime.jobs.execute` scope'u ile `/api/internal/v1/background-jobs/:id/attempts/:attempt/contact-import-step` çağırır. API her adımda en fazla 25 satırı tenant mutation kilidi ve aktif lease kontrolü altında işler; satır sonucu, profil/üyelik ve contact_change_events aynı transaction'da yazılır. Lease sonunda da doğrulanır. Eski attempt yazamaz; kayıp cevap/retry tamamlanan satırı tekrar uygulamaz. Heartbeat mevcut lease'i yeniler ve uzun iş sırasında readiness zamanını günceller. Shutdown yeni batch başlamasını durdurur; tamamlanmış batch'ler kalır.

Aktarım anında arşivli liste/kişi, hazır olmayan kimlik, legacy claim, süresi dolan önizleme ve onaylayan kullanıcının aktif üyelik/yetkisi tekrar kontrol edilir. Beklenen iş kuralı sorunları satır conflict kodu olur; DB/altyapı hatası batch'i rollback eder ve mevcut lease/retry mekanizmasına bırakılır. Kişinin DNC, izin, durum ve kimlik revizyonu alanları aktarım tarafından değiştirilmez. Yeni kişi legacy uyumluluk nedeniyle customers.source='manual' ile tutulur; gerçek import kökeni contact_change_events.source='import' ve onay audit'iyle ayrılır. İçe aktarım çağrı veya kampanya hedefi oluşturmaz.

`GET /api/v1/contact-import-jobs/:public_id` sayfalı satır sonuçları, pending/applied/conflict/skipped sayaçları, job state ve ayrı queue_status döndürür. `POST .../:public_id/cancel` If-Match ve idempotency ile kalan işi durdurur; işlenmiş satırlar korunur. Cancelled işte pending sayısı artık çalıştırılmayacak kalan satırlardır. Kuyrukta failed/dead_letter durumu ayrıca görünür; tamamlanmamış iş başarı gibi gösterilmez. İş başlatma ve iptal audit edilir, onay endpoint'i hassas rate-limit kontrolündedir.

**Bu dilimde client runtime değişmedi.** Sonraki dilim onay/alan seçimi, iş ilerleme/iptal/sonuç ve yeniden bulma ekranlarını API'lere bağlayacaktır. Hata raporu, fiziksel 7 günlük temizleme, özetin 1 yıllık saklanması ve 50.000 satırlık uçtan uca performans kabulü henüz tamamlanmadı. F03-T03/T04 açık; Faz 3 bitmiş sayılmaz.

Rollout: DB 089 + 090 → API → yeni worker → client. Eski worker import handler'ını tanımaz; onay endpoint'ini kullanmadan yeni worker dağıtılmalıdır. Worker varsayılan kapalıdır; bu dilimde yerel/üretim workerı etkinleştirilmedi. Çalışan API'nin yeni build'i kullanması için yeniden başlatılması gerekir. Kesinti/geri dönüşte worker durdurulur, tamamlanmış satırlar geri silinmez; pending işlerin lease/durumları incelenir. Dolu iş tablolarında rollback veri kaybını önlemek için reddedilir. Retention işinin pending işleri sonlandırmadan kaynak satırları silmemesi gerekir; eksik kaynak satırları için worker güvenli conflict sonucu üretir.

Yerel haisly_caller migration 089 seviyesine geçirildi. Önce `backups/haisly-caller-pre-import-jobs-2026-10-20/haisly_caller.dump` alındı ve arşiv listesi kontrol edildi (tam restore provası değil). Dosya 0600, dizin 0700. Önce/sonra 421 kişi, 588 çağrı ve 0 liste üyeliği; yerel import job sayısı 0. Üretim inbound sunucusu değiştirilmedi. İkinci izole DB'de upgrade, boş rollback/reapply ve 89 migrationlı schema doğrulaması geçti; dolu rollback reddi ana test DB'de doğrulandı.


Son bütünlük kontrolünde 090 migrationı eklendi: mevcut kişiye ait snapshot'ın public ID/sürüm/kimlik revizyonu alanlarının tamamı zorunlu; SQL CHECK'in NULL/UNKNOWN davranışıyla kısmi kimlik kaydı oluşması engellendi. Önceden uygulanmış 089 dosyası değiştirilmedi. 090 ikinci test DB'de rollback/reapply ile doğrulandı. Yerel DB ve ikinci test DB 090 seviyesinde; kişi/çağrı sayıları değişmedi.

Aktarım önizlemesi/iş geçmişine bağlı listeyi silme isteği, kampanyada kullanılan liste gibi arşivlemeye dönüşür; geçmişi bozan FK hatası veya veri kaybı oluşmaz. Bu davranış API entegrasyon testinde doğrulandı ve ürün notuna işlendi.

Doğrulama: API tam verify:ci 120/120 test, 0 atlama; tip/lint/build/OpenAPI başarılı. Son liste arşivleme değişikliği sonrası 5 hedefli regresyon, ek snapshot/tenant constraint entegrasyonu ve build başarılı. Eşzamanlı onay/replay, stale overwrite reddi, varsayılan koruma/boş alan tamamlama, explicit overwrite, yeni kişi çakışması, DNC'nin korunması, lease kaybı ve eski attempt reddi, kısmi iptal, tekrar batch çağrısı, onaylayan kullanıcının yetki iptali ve worker shutdown/failure davranışı kapsandı. API npm audit 0 bulgu; bağımlılık eklenmedi. Client runtime değişmediği için bu backend diliminde client testleri veya yeni ekran E2E'si çalıştırılmadı. Gerçek müşteri çağrısı ve üretim dağıtımı yapılmadı.


## 2026-10-21 — Aktarım onayı, ilerleme, iptal ve geçmiş arayüzü

Client önizleme akışı kalıcı aktarım API'sine bağlandı. Tüm geçerli satırların işlenmesi ayrı kullanıcı onayı ister; mevcut dolu isim/soyisim/ünvan alanları satır ve alan bazında açık seçim olmadan değiştirilmez. En fazla 1.000 overwrite satırı seçilir; seçimler sayfalar arasında korunur, karşılaştırma yenilendiğinde sıfırlanır. Kişi sürümü ve kimlik revizyonu onayla gönderilir. Belirsiz bağlantı/5xx hatasında aynı gövde ve idempotency anahtarı korunur; seçim değişikliği engellenir. Kesin ret sonrası seçimler yeniden değerlendirilir ve tekrar açık onay gerekir. Eski API sözleşmesinde yazma düğmesi kapalıdır.

İş ekranı 4 saniyelik sorgularla kaydedilen, incelenecek, atlanan ve bekleyen satırları gösterir. Tamamlanan/iptal edilen/dead-letter işler ve okuma hatası otomatik sorgulamayı durdurur; elle yenileme sunulur. Kuyruk hatası tamamlanmış gibi gösterilmez. İptal onayı iş sürümüne bağlıdır; işlem bu sırada ilerlerse 409 sonrası güncel durum ve yeniden onay gerekir. Kaydedilmiş satırlar korunur; cancelled işte pending satırlar işlenmeden kalan olarak gösterilir. Kaydedilen satır sayısı arttığında kişi/liste sorguları geçersizleştirilir. Import arama veya kampanya hedefi oluşturmaz; DNC ve izin alanları değişmez.

Yeni GET /api/v1/contact-import-jobs?list_public_id=...&offset=... uç noktası tenant ve iki yönetim yetkisiyle korunur; 25 işlik sayfalar, newest-first sıra, offset 0–100000 sınırı ve no-store cevabı kullanır. Yeni işler eklendiğinde offset sayfaları kayabilir; kullanıcıya belirtilir. İş geçmişine arşivlenmiş listelerden de erişilir. Önizleme cevabındaki job_public_id yeniden onayı önler ve mevcut işe yönlendirir. Yenileme/liste değişimi sonrası geçmiş sunucudan tekrar okunur; kişisel veri tarayıcı depolamasına yazılmaz. Süresi dolmuş önizlemenin işi geçmiş ekranından açılır.

Vite npm audit bulgusu GHSA-698v-4r3x-3vcv (Windows geliştirme sunucusu launch-editor komut kaçışı, moderate) için Vite 8.3.4 ve lockfile güncellendi. API/client son npm audit 0 bulgu. Yeni DB migrationı yok; şema 090. Yerel/üretim workerı etkinleştirilmedi, üretim dağıtımı veya gerçek müşteri çağrısı yapılmadı. Dağıtım sırası mevcut 089/090 DB → API/yeni worker → client; eski API ile client onay işlemi kapalı kalır. Client geri alınabilir; önceden onaylanmış işler sunucuda kalır, durdurulmaları gerekiyorsa açıkça iptal edilmelidir.

Doğrulama: API tam verify:ci 120/120 test (0 atlama), typecheck/lint/build/OpenAPI başarılı. Ek tenant izolasyonu, boş geçmiş sayfası, geçersiz offset, önizlemeden iş bulma, arşivlenmiş liste geçmişi ve yetki iptali testleri eklendi. Client tam paket 316/316; aktarım işi test dosyası 6/6 (default koruma, explicit overwrite, belirsiz onay replay, stale onay/iptal, geçmiş ve dead-letter). Typecheck/build başarılı; lint mevcut 6 uyarı, 0 hata. 390/820/1440 px Chromium akışı 3/3; ekran görüntüleri incelendi. Browser API mock, backend testleri izole yerel DB ile. Vite güncellemesi mevcut __dirname yapılandırması için gelecekteki native config loader uyarısı verir; mevcut build/dev çalışır. Büyük chunk uyarısı sürer.

F03-T01/T02/T03 kapsamındaki onay/iş takibi UI dilimi tamamlandı; Faz 3 bütünü henüz tamamlanmadı. Sırada hata raporu indirme, fiziksel 7 günlük ham dosya/önizleme temizliği ve 1 yıllık özet saklama, 50.000 satırlık uçtan uca performans kabulü var. F03-T04 ve ilgili bütünlük kabul maddeleri açık kalır.
