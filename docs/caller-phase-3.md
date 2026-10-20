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
