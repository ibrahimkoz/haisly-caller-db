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
