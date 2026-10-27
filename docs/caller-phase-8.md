# Faz 8 — Scheduler ve dış arama yürütme

### 2026-10-27 — Arama zamanlama kuralları (F08-T01 kısmi)

- `evaluateTemporalPolicy` tek saf servis olarak eklendi: doğrulanmış kişi saat dilimi veya aynı ülkede tenant saat dilimi; başka ülke + eksik doğrulanmış dilim engellenir. UTC anı Intl/IANA ile yerel gün/dakikaya çevrilir, DST yerel saat üzerinden değerlendirilir.
- Kampanya ve ülke gün/saat/tatil kuralları kesişir; platform 09:00 dahil–20:00 hariç sınırı gevşetilemez. Başlangıç dahil, bitiş hariç; 1–5 deneme ve daha düşük platform sınırı uygulanır.
- Kabul edilmiş çağrının bitişinden aynı kampanyada normal4 saat, başka kampanyada24 saat; bitiş belirsiz/aktif çağrı engeli; kayan24 saatte en fazla2 kabul edilmiş otomatik dış arama; gelen insan görüşmesi sonrası24 saat uygulanır. Pre-accept teknik ret geçmişe iş denemesi olarak verilmez.
- Teyitli aynı-kampanya geri aramada15 dakika alt sınırı ve teyitli zamandan30 dakikalık başlama penceresi vardır. Bu istisna günlük limiti, başka kampanya veya inbound24 saat engelini aşmaz.
- Karar eligible/waiting/blocked, neden ve varsa en erken zaman verir. `dispatch_authorized:false` sabittir: bu sonuç yalnız zaman koşullarını kapsar. Takvim penceresi için ileri uygun an henüz hesaplanmaz; not_before=null ise scheduler yerel pencereyi yeniden değerlendirmelidir.
- Fonksiyon HTTP'ye açılmadı. Güvenilir tamamlanmış tenant+numara geçmişi, policy store, telefon kilidi, DNC/izin, campaign/target state, bütçe/kota, callback teyidi ve DB dispatcher bağlantısı henüz yok. Worker/history sorgusu eklendiğinde ilgili kaynaklardan transaction içinde beslenecek; eksik geçmişle çağrı yetkisi üretilmeyecek.
- DST ilkbahar/sonbahar, sınır saatleri, timezone yokluğu, tatil/gün, kabul sonrası cooldown, belirsizlik, callback, günlük limit ve deneme sınırı test senaryoları yazıldı; kullanıcı talimatıyla çalıştırılmadı. F08 ve goal aktif; bu saf servis scheduler veya gerçek çağrı kabulü değildir.

### 2026-10-27 — Kalıcı gönderim niyeti ve kabul sayacı (F08-T02/T03 kısmi)

- DB109 caller_dispatch_intents: hedef/kimlik/snapshot/numara/provider hesabı/production rezerv bağı, request key/hash, prepared/submitting/uncertain/accepted/ended/rejected/canceled durumları. Aktif niyette tenant+canonical numara tekil; provider ref hesap kapsamında tekil, rezerv tek intent'e bağlı.
- Hedef ve kişi kimliği insert sırasında kilitlenip doğrulanır; held production rezervi zorunlu. Açık gönderim rezervinin serbest bırakılması/settle edilmesi deferred guard ile engellenir. Test çağrıları bu production hedef sayacına bağlanmaz.
- Kabul zamanı ilk kez kaydedildiğinde AFTER trigger hedef denemesini bir kez artırır. Terminal/geçmiş bağları immutable; belirsizden kör tekrar submitting yok. Açık niyet hedef snapshot'ını kilitler; mevcut hedefin unstarted olması tek başına rebind için yeterli değildir.
- Internal transition primitive provider evidence ref, optimistic version, aynı sonuç replay, geri durum ve çelişkili provider ref/zaman reddi ekler. HTTP/worker'a açılmadı; gerçek provider kanıtı doğrulaması bu fonksiyona bağlı değildir.
- Yerel DB özel dump sonrasında109 uygulandı; production etkisi/çağrı yok. Schema ve transition payload senaryoları yazıldı, kullanıcı talimatıyla çalıştırılmadı.
- Hâlâ açık: atomic claim+reserve+intent oluşturma, kabulün calls/session kaydına bağlanması, terminal durum ve maliyet/release birlikte işlenmesi, tam provider webhook kanıtı, rejected teknik retry, inbound kilidi, geçmiş sorgusu/policy bağlama ve PostgreSQL eşzamanlılık/rollback/sayaç entegrasyon senaryoları. API hazır gönderim yapamaz; Faz8/goal tamamlanmadı.
