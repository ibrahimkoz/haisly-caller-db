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
