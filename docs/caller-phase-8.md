# Faz 8 — Scheduler ve dış arama yürütme

### 2026-10-27 — Arama zamanlama kuralları (F08-T01 kısmi)

- `evaluateTemporalPolicy` tek saf servis olarak eklendi: doğrulanmış kişi saat dilimi veya aynı ülkede tenant saat dilimi; başka ülke + eksik doğrulanmış dilim engellenir. UTC anı Intl/IANA ile yerel gün/dakikaya çevrilir, DST yerel saat üzerinden değerlendirilir.
- Kampanya ve ülke gün/saat/tatil kuralları kesişir; platform 09:00 dahil–20:00 hariç sınırı gevşetilemez. Başlangıç dahil, bitiş hariç; 1–5 deneme ve daha düşük platform sınırı uygulanır.
- Kabul edilmiş çağrının bitişinden aynı kampanyada normal4 saat, başka kampanyada24 saat; bitiş belirsiz/aktif çağrı engeli; kayan24 saatte en fazla2 kabul edilmiş otomatik dış arama; gelen insan görüşmesi sonrası24 saat uygulanır. Pre-accept teknik ret geçmişe iş denemesi olarak verilmez.
- Teyitli aynı-kampanya geri aramada15 dakika alt sınırı ve teyitli zamandan30 dakikalık başlama penceresi vardır. Bu istisna günlük limiti, başka kampanya veya inbound24 saat engelini aşmaz.
- Karar eligible/waiting/blocked, neden ve varsa en erken zaman verir. `dispatch_authorized:false` sabittir: bu sonuç yalnız zaman koşullarını kapsar. Takvim penceresi için ileri uygun an henüz hesaplanmaz; not_before=null ise scheduler yerel pencereyi yeniden değerlendirmelidir.
- Fonksiyon HTTP'ye açılmadı. Güvenilir tamamlanmış tenant+numara geçmişi, policy store, telefon kilidi, DNC/izin, campaign/target state, bütçe/kota, callback teyidi ve DB dispatcher bağlantısı henüz yok. Worker/history sorgusu eklendiğinde ilgili kaynaklardan transaction içinde beslenecek; eksik geçmişle çağrı yetkisi üretilmeyecek.
- DST ilkbahar/sonbahar, sınır saatleri, timezone yokluğu, tatil/gün, kabul sonrası cooldown, belirsizlik, callback, günlük limit ve deneme sınırı test senaryoları yazıldı; kullanıcı talimatıyla çalıştırılmadı. F08 ve goal aktif; bu saf servis scheduler veya gerçek çağrı kabulü değildir.
