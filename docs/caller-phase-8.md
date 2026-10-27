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

### 2026-10-27 — Atomik maliyet rezervi + gönderim hazırlığı

- Internal `prepareProductionIntent` eklendi. Caller-contact advisory → billing account → campaign/target kilit sırası; seçili snapshot ve güncel kişi kimliği, DNC/izin/numara durumu, açık tenant+numara niyeti, snapshot arayan numarası ve tenant provider kaydı kontrol edilir.
- Production rezervi ve intent aynı transaction'da oluşturulur; sonradan hata/rollback ikisini geri alır. Aynı key/hash mevcut intent'i güncel durumuyla döndürür; değişen payload409. Replay yeni provider gönderimi yetkisi değildir. Bütçe blocked sonucunun pause/bildirimlerinin korunması için caller transaction'ı commit etmelidir.
- Durum geçişleri aynı tenant/account kilit sırasına alındı. Bu dilim yeni DB migration gerektirmedi;109 kullanılır.
- PostgreSQL test helper gerçek izole tenant/contact/list/campaign/snapshot/provider fixture'ları, bakiye/bütçe ve tarifeyle hazırlık rollback, paralel aynı-key replay, farklı-key açık numara engeli, rezervi erken bırakma reddi, uncertain→kör retry reddi, paralel acceptance tek sayım, terminal geç olay reddi ve sıfır-maliyet final/replay senaryolarını içerir. Billing integration testine bağlandı; kullanıcı talimatıyla çalıştırılmadı.
- Hazırlık fonksiyonu HTTP veya worker'a açılmadı; `dispatch_authorized:false`. Final release/test/numara sahipliği/ülke-zaman policy ve kota gate'leri hazırlık çağrısından önce transaction içinde bağlanmalı. Telefon-provider kod eşleşmesi gerçek sahiplik/account bağlantısı kanıtı değildir. Provider ağ çağrısı yoktur.
- Sırada güvenilir call-history sorgusu ve policy/kota/store bağlantısı, calls/session kaydı, gönderim öncesi son kontrol, provider adapter/reconciliation ve açık diğer fazlar var. F08 ve goal aktif; doğrulama tamamlandı iddiası yok.

### 2026-10-27 — Production gönderim geçmişinden zamanlama girdileri

- `readProductionDispatchHistory` aynı tenant advisory kilidi altında server clock, açık prepared/submitting/uncertain/accepted niyeti ve zamanlama için yeterli kabul/bitiş kayıtlarını DB'den okur. Son iki acceptance + aynı/diğer kampanyanın son ended kaydı birleşip public ID ile tekilleştirilir; en fazla4 accepted satır belleğe alınır.
- Cooldown son kabul zamanından tahmin edilmez; ayrı ended_at sıralaması, daha önce başlamış uzun görüşmenin daha geç bitmesini korur. Kampanya kimliği temporal engine'e internal numeric ID'nin string biçimiyle tutarlı aktarılır; public endpoint değildir.
- DB110 telefon ve telefon+kampanya ended_at indeksleri özel yerel dump sonrası uygulandı. Schema kontrolü yazıldı; execution plan/performans ve restore/rollback kabulü henüz yapılmadı.
- Prepared/accepted/ended history, no-answer dahil bitiş, tekilleştirme ve başka numara ayrımı senaryoları mevcut dispatch integration helper'a eklendi; kullanıcı talimatıyla çalıştırılmadı.
- Dönen kaynak açıkça production_dispatch_intents ve requires_additional_call_history=true. Test/legacy outbound ve inbound insan görüşmesi geçmişi, global aktif çağrı kilidi henüz birleşmedi. Bu parçanın boş sonucu tam çağrı geçmişi yok sayılmaz; dispatcher canlı kararına bağlanmadı. Policy store, kota ve kalan yayın/runtime bağımlılıkları açık; F08 ve goal aktif.

### 2026-10-27 — Gönderilmiş çağrı rezerv koruması ve atomik hazırlık iptali

- İncelemede109 açık-intent guard'ının ended/rejected gönderim için `releaseUnsubmittedCallCost` yolunu tek başına kapatmadığı görüldü. Servis artık bağlı intent varsa yalnız canceled durumuna izin verir; gönderilmiş/bitmiş çağrı doğrulanmış nihai maliyet ile settle edilmelidir.
- DB111 deferred constraint trigger aynı sınırı doğrudan reservation update'inde de uygular. Önceden çelişkili released kayıt varsa migration durur; yerel özel dump sonrası111 başarıyla uygulandı. Rollback dispatch geçmişi varsa korumayı kaldırmaz.
- Internal `cancelPreparedIntent` prepared→canceled geçişi ve reserve release'i aynı transaction'da yapar. Aynı kanıt replay olur; uncertain/accepted/ended için iptal/hangup varsayımı üretmez.
- Entegrasyon senaryolarına cancellation rollback, tekrar iptal/release, ended çağrıyı API ve doğrudan DB ile yanlış release etme reddi ve terminal cancel reddi eklendi. Schema kontrolü yazıldı; kullanıcı talimatıyla test/typecheck/lint/build/DB doğrulaması çalıştırılmadı.
- Provider final maliyet kanıtı, reconciliation UI/işçisi ve gerçek hangup işlemleri hâlâ açık. Bunlar local hazırlık iptalinden ayrıdır. Faz8/goal aktif; final kabul yapılmadı.

### 2026-10-27 — Değiştirilemez gönderim geçiş geçmişi ve hedef görünümü

- DB112 trigger-owned caller_dispatch_transitions eklendi: intent/version tekil; prepared ve her gerçek durum geçişi aynı transaction'da kaydolur. Doğrudan insert/update/delete reddedilir. Migration öncesi kayıt varsa yalnız bilinen mevcut durum baseline olarak işaretlenir; sahte geçmiş üretilmez. Yerel özel dump sonrası112 uygulandı (backfill0 satır).
- `GET /campaigns/:public_id/targets/:target_public_id/attempts` tenant/campaign/target kapsamı ve read+contact/list yetkileriyle sayfalı dispatch/geçiş geçmişi verir. Cursor yalnız aynı hedefe ait olabilir; newest-ID sırası, repeatable-read ve no-store. Provider/kanıt/numara/internal ID/rezerv bilgileri dönmez.
- Client hedef kartına gönderim geçmişi aç/yenile ve eski kayıt sayfalaması eklendi. Kabul edilmiş deneme sayısı, teknik gönderim kayıtlarından ayrı; durumlar, UTC zamanları, bağlantı sonucu ve eksik geçmiş baseline açıklaması görünür.
- Entegrasyon senaryolarına rollback geçmişi, cancellation/acceptance replay tekilliği, tüm geçiş sırası, kanıtın korunması, doğrudan insert/update/delete reddi ve API auth/cursor/alan gizleme eklendi. OpenAPI üretildi; test/typecheck/lint/build/DB/browser kontrolleri kullanıcı talimatıyla final aşamasında.
- Bu teknik durum geçmişi provider olayının gerçekliğini doğrulamaz; webhook imzası/event dedup, actor audit bağlantısı ve gerçek sağlayıcı davranışı açık. Worker, tam yayın ve kalan Faz4–13 işleri devam ediyor; goal tamamlanmadı.
