# Faz 4 — Kampanya geliştirme ilerlemesi

## 2026-10-21 — Kampanya taslak backend'i ve kaynak listeler

F04-T01/T02'nin ilk backend dilimi tamamlandı. Migration 092 `caller_campaigns`, `caller_campaign_versions`, `caller_campaign_source_lists` tablolarını ekler. Kampanya adı tenant içinde tekil değildir; tip marketing/survey; taslak içerik boş kalabilir. Davranış (20.000 karakter), konu (50.000), hedef/amaç (2.000), dil (tr/en) ve en fazla 100 tekil kaynak liste saklanır. Sayısal sınırlar içerik/depolama korumasıdır. Tenant bileşik FK'leri kullanıcı, kampanya, sürüm ve liste sınırlarını DB'de de korur. Bir kampanyada tek düzenlenebilir taslak vardır; `revision` içerik sürümü kimliği, kampanyanın `version` alanı eşzamanlı düzenleme sayacıdır.

Bu aşamada DB ve API yalnız draft kabul eder. Yayınlanmış sürümün değişmezliği, tip kilidi, hedef snapshot'ı ve kontrol komutları sonraki F04-T01/T03/T06 dilimlerinde eklenecek; mevcut draft CHECK'leri o zaman kontrollü migration ile genişletilecek. Taslak kaydı yayınlanabilirlik onayı değildir. Agent/ses, takvim, bütçe/kapasite, aksiyon ve anket alanları henüz bu API'de yoktur. Bilinmeyen alanlar reddedilir.

API sözleşmesi:
- `POST /api/v1/campaigns`: isim/tip ile eksik taslak oluşturur; Idempotency-Key zorunlu. Aynı anahtar ve gövde aynı kaydı döndürür.
- `GET /api/v1/campaigns`: tenant kapsamında UUID keyset sayfalama, varsayılan 25/en fazla 100; `after` ve `next_cursor`.
- `GET /api/v1/campaigns/:public_id`: taslak içeriği ve kaynak listelerin güncel isim/arşiv bilgisi. `publication_available: false`.
- `PUT /api/v1/campaigns/:public_id/draft`: belgenin tamamını değiştirir; Idempotency-Key ve tırnaklı If-Match zorunlu. Gönderilmeyen opsiyonel içerik boş/default, listeler boş olur. PATCH değildir; client mevcut belgeyi koruyarak göndermelidir. Eski sürüm veya anahtar/gövde uyuşmazlığı 409.

Okuma caller.campaigns.read, yazma caller.campaigns.edit ister; kaynak liste seçilirse ayrıca caller.lists.manage gerekir. Tenantı olmayan/yabancı kaynaklar 404; yeni arşivli kaynak bağlama 409. Daha önce bağlanmış liste arşivlenirse mevcut taslakta kalabilir; içerik düzenlemesini kilitlemez, okuma arşiv durumunu gösterir. Ortak kişi/liste mutation kilidi, liste arşivleme/silme ile kampanya kaynak seçimini sıralar. Liste silme isteği bağlı kampanya taslağı varsa arşivlemeye dönüşür; `used_in_campaign` taslak bağını da gösterir. Kaynak üyelerden hedef, iş veya çağrı oluşturulmaz. İlk hedef snapshot'ı yalnız gelecekteki yayın komutunda oluşturulacak.

Audit olayları caller_campaign olarak sınıflandırılır; sürüm/tip/kaynak sayısı içerir, davranış/konu metni audit'e kopyalanmaz. Mutasyon receipt mevcut ortak sözleşme ile yanıtı saklar. Yanıtlar no-store. Draft okuması repeatable-read snapshot kullanır. OpenAPI güncellendi. Client uygulama kodu bu dilimde değişmedi; henüz kampanya ekranı yok.

Doğrulama: API verify:ci 124/124, 0 atlama; type/lint/build/OpenAPI. Hedefli testte onay anahtarı replay, gövde uyuşmazlığı, tenant izolasyonu/bileşik FK, yetki iptali sonrası replay reddi, aynı isim, sayfalama, eksik taslak, strict alan/limit denetimi, tip değişimi, arşivli kaynak ve liste silme davranışı, eski sürüm ve iki eşzamanlı yazardan yalnız birinin başarısı doğrulandı. DB running/published durumlarını reddeder, publish route yok, background job sayısı 0. İkinci izole DB'de 092 upgrade/boş rollback/reapply ve 92 migrationlı schema kontrolü geçti. Kayıtlı kampanya varken rollback'in reddi ayrıca doğrulandı. Bağımlılık değişmedi; yeni npm audit veya client testi çalıştırılmadı.

Yerel DB güncellemesinden önce `backups/haisly-caller-pre-campaign-drafts-2026-10-21/haisly_caller.dump` alındı: 8.693.105 byte, dizin 0700/dosya 0600. pg_restore arşiv listesi doğrulandı; tam restore provası yapılmadı. Dağıtım sırası DB 092 → API → ileride client. Kampanya verisi yoksa API geri alındıktan sonra 092 rollback uygulanabilir. Veri oluştuktan sonra forward fix gerekir: eski API listelerde kampanya ilişkisini tanımadığı için geriye dağıtım liste silme davranışını bozabilir. Worker/üretim/gerçek aramalar etkinleştirilmedi.

Faz 4 tamamlanmadı. Sıradaki dilim kampanya listesi/taslak düzenleme ekranı ve eksik yapılandırma alanları; ardından değişmez yayın adayı, hedef snapshot/fark dahil etme, anket akışı ve test/yayın kapıları. F04-T01–T06 kutuları henüz kapatılmadı.

Yerel uygulama DB doğrulaması tamamlandı: 92 migration, 421 kişi, 588 çağrı, 0 kampanya. Müşteri/çağrı sayıları değişmedi; schema kontrolü geçti.


## 2026-10-27 — Kampanya listesi ve taslak düzenleme client akışı

`/app/campaigns` sayfası ve yetkiye bağlı menü eklendi. Kullanıcı marketing/survey tipi, isim, amaç, davranış/konu talimatları, tr/en görüşme dili ve kaynak listeler ile eksik taslağı kaydedebilir; kayıtları sayfalayabilir ve tekrar açabilir. Liste seçimi en fazla 100 kayıttır; arşivli liste yeni seçilemez, mevcut arşivli kaynak görünür. Arama hedefi veya çağrı oluşturulmaz. Takvim, agent/ses, bütçe/aksiyon ve anket soruları bu ekranın sonraki dilimleridir; yayın kullanılamadığı açıkça belirtilir.

Client katmanları ayrı model/Zod, RTK Query API, alanlar/kaynak seçici ve sayfa bileşenlerinden oluşur. Kaydetme mevcut API'nin tam PUT sözleşmesini kullanır; tüm alanlar ve seçili kaynak ID'leri gönderilir. If-Match düzenlemeye başlanılan sürümden alınır. Ağ/5xx belirsizliğinde gövde, anahtar ve sürüm sabitlenir; form kilitlenir ve aynı istek tekrar denenir. 409'da yazılan metin korunur, yeniden kaydetme kapanır; güncel veriyi yükleyip yerel değişikliklerden vazgeçmek açık onay ister. Başarılı kayıt sonrası kampanya/liste cache'i yenilenir. Otomatik sorgu yenilemesi açık düzenleyicinin metnini değiştirmez.

Salt okunur kullanıcılar kaydetme/oluşturma kontrolünü görmez. Kaynak listeleri değiştirmek için caller.lists.manage gerekir; bu izin yokken liste API'si çağrılmaz ve seçili kaynaklı taslak kaydı backend sözleşmesi gereği kapalıdır. Route/menü caller.campaigns.read ile korunur; backend yetki denetimleri nihai kaynaktır. Değişmiş formu kapatma, route değiştirme ve tarayıcıdan ayrılma korumaları vardır. İçerik yalnız bellekte/formda tutulur, localStorage'a taslak metni yazılmaz.

Doğrulama: tam client paketi 324/324 (79 dosya) geçti. Son eklenen gezinme koruması testi dahil hedefli kampanya paketi 6/6; son TypeScript kontrolü başarılı. Build başarılı, lint 0 hata/mevcut 6 uyarı. Mevcut büyük chunk ve Vite native-config uyarıları sürüyor. Chromium 390/820/1440 px'de 3/3 oluşturma-kaydetme-tekrar açma akışı ve yatay taşma kontrolü geçti; ekran görüntüleri görsel olarak incelendi. Browser testleri API mock kullanır; backend'in gerçek PostgreSQL testleri önceki dilimde 124/124 geçti. Bu dilimde backend/DB davranışı değişmedi, gerçek DB'ye kayıt yazılmadı. Bağımlılık değişmedi; npm audit yeniden çalıştırılmadı.

Dağıtım için DB092 ve kampanya taslak API'si gerekir; ardından client yayınlanır. Client geri alınabilir; kaydedilmiş kampanyalar DB'de kalır. Faz 4 ve F04-T02 bütünü henüz tamamlanmadı. Sırada takvim/deneme/kapasite ve agent yapılandırması, ardından hedef snapshot ve anket akışları var.
