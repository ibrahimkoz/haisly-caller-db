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

### 2026-10-27 — Kalıcı teknik tekrar kapısı

- `readTechnicalRetryDecision` tenant kilidi altında son provider acceptance'tan sonraki en fazla4 kesin pre-accept rejected intent'i ve trigger-owned geçiş zamanlarını okur. Canceled hazırlıklar ret serisini sıfırlamaz; accepted deneme yeni seri sınırıdır.
- İlk ret sonrası1dk, ikinci sonrası5dk, üçüncü sonrası15dk; dördüncü ret üç teknik tekrarın tüketildiğini gösterir ve review döner. Retler iş deneme sayacını artırmaz. Baseline/eksik/future kanıt zamanı güvenli tekrar zamanı sayılmaz, review gerektirir.
- Atomik prepare yeni rezervden önce bu kapıyı kontrol eder; bekleyen veya tükenmiş teknik tekrar yeni maliyet rezervi/intent oluşturmaz. Aynı mevcut key replay mevcut intent'i döndürür, provider'a yeniden gönderim değildir. Belirsiz/açık numara koruması önce uygulanır.
- Sınır süreleri ve limit için unit senaryoları; DB geçiş zamanına bağlı bekleme, pre-accept sayaç koruması ve rezerv yaratmama için integration senaryosu eklendi. Kullanıcı talimatıyla çalıştırılmadı; DB migration gerekmedi.
- Operatör inceleme görevi/bildirimi ve manuel yetkili retry kararı henüz bağlı değil. Zaman/ülke/iş sonucu, kapasite, final release ve gerçek provider gate'leri ayrıca açık; Faz8/goal aktif.

### 2026-10-27 — Teknik tekrar durumunun API ve operasyon görünümü

- Hedef dispatch history yanıtına checked_at ve technical_retry özeti eklendi. Durum tüm hedef geçmişinden hesaplanır; eski gönderim sayfasına geçmek bekleme/inceleme kararını değiştirmez. technical_retries_used bu ret serisinde kesin retle sonuçlanmış tekrar sayısıdır; hazırlanmış veya devam eden tekrar bu sayıya dahil değildir.
- UI için repeatable-read observational teknik karar okuyucusu ayrıldı; tenant yazma kilidi tutmaz. Mutasyon/prepare tarafı aynı kilitli okuyucuyu kullanmaya devam eder. UI snapshot'ı işlem yetkisi değildir.
- Client en erken UTC tekrar zamanını, retle sonuçlanan tekrar sayısını ve inceleme nedenini gösterir. Açılmış geçmiş uygulama odaktayken10sn aralıkla yenilenir; arka plan yenilemede mevcut görünüm silinmez. ready yalnız teknik beklemenin kalkmasıdır; diğer gate'lerin yerine geçmez.
- API pagination'dan bağımsız özet senaryosu ve client bekleme/inceleme açıklaması testleri yazıldı; kullanıcı talimatıyla çalıştırılmadı. OpenAPI üretildi. DB migration gerekmedi.
- Operatör görev/bildirim ve yetkili inceleme çözüm komutu, provider doğrulaması, tam dispatch/yayın ve diğer faz işleri açık; goal aktif.

### 2026-10-27 — Belirsiz gönderim ve rezervin atomik güncellenmesi

- Internal `markDispatchUncertain`, submitting→uncertain geçişini ve bağlı maliyet rezervinin held→uncertain güncellemesini aynı transaction içinde yapar. Mevcut tenant/account kilit sırasını korur; timeout ret olarak yorumlanmaz ve para serbest bırakılmaz.
- Aynı kanıt replay rezerv versiyonunu veya geçiş geçmişini tekrar artırmaz; farklı kanıt mevcut sonucu değiştiremez. Transaction rollback her iki durumu ve geçmişi geri alır.
- Entegrasyon senaryolarına rollback, aynı/farklı kanıt replay ve bakiye/rezerv korunması eklendi. Belirsiz rezervi doğrudan release etmenin mevcut DB100 guard'ında reddedilmesi beklentisi güncellendi. Testler kullanıcı talimatıyla çalıştırılmadı.
- DB migration ve client sözleşme değişikliği gerekmedi. Bu servis henüz gerçek sağlayıcı timeout akışına bağlı değil; provider reconciliation/worker, tam yayın ve Faz4–13 kalan işleri açık. Goal aktif.

### 2026-10-27 — Sağlayıcı olay tekilleştirme ve geç kabul koruması

- DB113 tenant+provider account+event key tekil, immutable `caller_dispatch_event_receipts` tablosunu ekler. Receipt aynı tenant/provider/intent ve sonuç versiyonuna bağlıdır; dispatch/history değişimiyle aynı transaction'da yazılır. Ham webhook veya telefon kopyası saklanmaz. Yerel DB özel izinli dump sonrası113'e yükseltildi; restore/rollback doğrulaması yapılmadı. Veri oluşmuşsa rollback reddedilir.
- Internal `recordDispatchEvent` güvenilir adapterdan normalized accepted/ended/rejected olayını alır; tenant/account/intent kilit sırasını korur. Aynı key+hash kalıcı sonucu replay eder; başka hedef veya değişmiş veriyle key kullanımı reddedilir. Tarih ofsetleri hash öncesi UTC'ye normalize edilir.
- Bitişten sonra ulaşan kabul yalnız provider call ref ve kabul anı aynıysa late olarak kaydedilir; terminal durum, deneme ve maliyet değişmez. Aynı sonuç farklı event key ile observed receipt üretir. Çelişen sonuçlar hata döndürür; sessiz overwrite veya tekrar gönderim yapılmaz. Maliyet settlement ayrı doğrulanmış kanıt gerektirir.
- Transition validation ortak validation katmanına taşındı. Unit negatif sözleşme ve integration paralel replay, rollback, geç olay, değişmiş sonuç/key, yanlış provider/target, receipt immutability ve maliyet/sayaç korunması senaryoları eklendi. Schema validator genişletildi. Kullanıcı talimatıyla test/typecheck/lint/build/schema/browser çalıştırılmadı.
- Client/public API değişmedi. Gerçek provider imza doğrulama, güvenilir correlation ve event-key üretimi, reddedilmiş çelişkileri inceleme kuyruğuna alma, polling/reconciliation worker ve kalan Faz4–13 işleri açık. Bu internal servisin varlığı gerçek webhook kabul kanıtı değildir; goal aktif.

### 2026-10-27 — Sağlayıcı sonucu ve maliyet mutabakatının atomik uygulanması

- Internal `reconcileDispatchObservation` doğrulanmış provider event ve opsiyonel nihai maliyeti aynı transaction içinde uygular. Nihai maliyet yalnız ended/rejected gözlemiyle kabul edilir. Sağlayıcı ağ sorgusu transaction dışında yapılmalıdır; bu servis çağrı başlatmaz.
- Terminal olayın maliyeti yoksa held rezerv uncertain olur ve tutar korunur. Aynı event daha sonra final cost ile replay edilebilir; receipt tekrar oluşmaz, finansal sonuç bir kez kapanır. Sonraki eksik maliyetli bildirim settled rezervi açmaz. Değişmiş nihai maliyet mevcut audited adjustment akışını gerektirir.
- Entegrasyon koduna bilinmeyen ret maliyeti, geç gelen doğrulanmış sıfır maliyet, olay replay'inden bağımsız maliyet tamamlanması, maliyet hatasında event/history rollback, tekrar settlement ve aktif olayla maliyet kapatma reddi eklendi. Testler kullanıcı talimatıyla çalıştırılmadı.
- Mevcut worker yalnız lease-fenced API adımları çalıştırıyor. Güvenilir provider status/cost adapterı ve lease-fenced reconciliation endpoint/handler henüz yok; sahte sonuçla job başarıya çekilmedi. Kalıcı kuyruk/crash recovery bağlantısı, tam dispatch ve diğer fazlar açık. Yeni migration/client sözleşmesi yok; goal aktif.

### 2026-10-27 — Gönderim geçmişinde ayrı maliyet durumu

- Target dispatch history, aynı tenant/rezerv ilişkisi üzerinden `cost_state` (held/uncertain/settled/released) döndürür. Çağrı terminal durumu ile maliyetin kesinleşmesi ayrıdır. Mevcut yetkiler, repeatable-read, no-store ve cursor kapsamı korunur; parasal tutar, rezerv ID veya özel kanıt eklenmedi.
- Client gönderim kartında ayrılmış tutar, maliyet mutabakatı bekleme, nihai kullanım kaydı ve gönderim öncesi iptal sonrası release için ayrı açıklamalar gösterir. Settled, ödeme tahsil edildi veya pozitif ücret oluştu anlamında etiketlenmez; doğrulanmış sıfır kullanım da bu durumdadır.
- OpenAPI üretildi. API integration'a uncertain terminal görünümü, settled/released ve parasal alanların yokluğu; client'a maliyet durum açıklamaları senaryoları eklendi. Test/typecheck/lint/build/browser kullanıcı talimatıyla çalıştırılmadı.
- Migration gerekmedi. Dağıtımda cost_state sağlayan API client'tan önce yayınlanmalıdır. Gerçek reconciliation worker, sağlayıcı doğrulaması ve kalan fazlar açık; bu görünüm tamamlanmış gerçek çağrı kabulü değildir. Goal aktif.

### 2026-10-27 — Kampanya operasyon özeti

- `GET /campaigns/:public_id/operations`, campaign.read ile tenant kapsamındaki sabit hedef ve tüm dispatch sayaçlarını repeatable-read/no-store döndürür. Hedef toplamı/başlamamış/başlamış ve kabul edilmiş deneme toplamı ayrıdır; dispatch durumları teknik kayıt toplamını parçalar. Biten/rejected ve rezervi hâlâ held/uncertain olan kayıtlar terminal_cost_pending olarak ayrıca sayılır; toplamın üstüne eklenmez.
- Client kayıtlı kampanyada 10sn görünür polling, yenileme, yüklenme/hata, son kontrol zamanı ve ayrı kişi/gönderim/maliyet bekleme açıklamaları gösterir. Başlamamış hedef uygun hedef, provider accepted insan yanıtı olarak etiketlenmez. Kişi/telefon/provider/finansal tutar bu endpoint'te yoktur.
- DB114 tenant+campaign+state INCLUDE(reservation_id) indeksi özel yerel dump sonrası uygulandı. Büyük üretim tablosu için concurrent indeks oluşturma dağıtım notu eklendi; üretim değişmedi. Sorgu planı/ölçek ve restore/rollback kabulü finalde yapılacak.
- API boş durum, auth/tenant izolasyonu, aynı kişinin farklı gönderimleri, settled/released/pending sayımı; client sayaç açıklamaları test kodu eklendi. OpenAPI üretildi. Test/typecheck/lint/build/schema/browser çalıştırılmadı.
- Bu ilk operasyon özeti yayın/dispatch açmaz (`dispatch_available:false`). Ayrıntılı uygunluk/bekleme nedenleri, tenantlar arası kapasite, provider/worker arıza ve görev başarısızlıkları, lifecycle kontrol komutları hâlâ açık. Faz8 ve goal aktif.

### 2026-10-27 — Sağlayıcı devre kesici karar modülü

- Saf provider circuit policy üç ardışık bağlantı hatasında açılır; doğrulanmış erişilebilirlik kapalı durumdaki hata serisini sıfırlar. Açıkken yeni çağrı izni verilmez;1dk sonra tek probe claim edilebilir. Probe yalnız authenticated salt-okunur health/status sorgusudur, müşteri araması değildir.
- Probe30sn lease ile sınırlıdır. Süre aşımı/başarısızlık devreyi açık tutar; orijinal kesinti başlangıcı korunur, sonraki probe1dk bekler. Epoch ve probe token eski/geç başarı veya hatanın yeni devre durumunu değiştirmesini engeller.15dk sürekli kesintide alert_due oluşur; acknowledged işareti yalnız notification outbox ile aynı transaction'da saklanmalıdır.
- Invalid persisted state ve geriye giden saat reddedilir. Eşik, reset, tek probe, yanlış token/epoch, süresi dolan worker, başarısız probe ve15dk bildirim sınırı unit senaryoları yazıldı; kullanıcı talimatıyla çalıştırılmadı.
- Henüz kalıcı provider row/observation dedup, atomik claim, gerçek read-only adapter, worker ve notification outbox bağlantısı yok. Saf modül kendi başına eşzamanlı worker kilidi veya canlı arama koruması değildir; dönen state provider kilidi altında saklanmalıdır. API/client/migration değişmedi. F08-T04 ve goal aktif.

### 2026-10-27 — Kalıcı sağlayıcı devre kesici ve hazırlık kapısı

- DB115 tenant/provider bağlı circuit state ve immutable connectivity event receipts ekler. State şekli, epoch/sürüm ve zaman monotonluğu DB kontrolündedir. Receipt tenant+provider+event key tekildir; değişmiş kanıtla replay reddedilir. Yerel özel dump sonrası115 uygulandı; rollback kayıt varsa forward-fix ister.
- Internal store tenant dispatch kilidi→provider row→circuit row sırasıyla DB saatinde inspect/expiry, tek probe claim ve observation uygular. Aynı hatanın paralel replay'i sayacı iki kez artırmaz; eski epoch/probe sonucu ignored receipt olarak korunur. Pasif provider yeni istek/probe alamaz; geçmiş sonucu işlenebilir. Ağ çağrısı transaction dışında kalır.
- Production prepare artık provider circuit açık/probing ise reserve/intent oluşturmadan provider_circuit_open döndürür. Bu hazırlık kontrolüdür; gerçek gönderim anındaki tekrar kontrolü ve observation bağlantısı hâlâ gereklidir. Aynı request-key mevcut intent replay'i yeni gönderim izni değildir.
- Integration koduna transaction rollback, parallel duplicate error, üçüncü hatada açılma, reserve yaratmama, stale başarı, iki worker tek probe, iyileşme, farklı event kanıtı ve immutable receipt reddi eklendi. DB schema validator genişletildi. Test/typecheck/lint/build/schema/restore/browser çalıştırılmadı.
- Probe adapter/worker,15dk alert outbox, operasyon ekranı ve gerçek sağlayıcı hatalarının normalizasyonu henüz bağlı değil. Caller active alanı sahiplik/doğrulama kanıtı sayılmıyor. F08-T04 ve goal aktif.

### 2026-10-27 — Uzayan sağlayıcı kesintisi bildirim kaydı

- `notifyProviderOutage`, aynı tenant/provider kilitleri altında DB saatinde15dk kesintiyi tekrar kontrol eder. Aktif owner/admin/operations_manager kullanıcıları tenant+aktif rol/üyelik koşullarıyla tekilleştirir; uygulama içi system/action_required/high bildirimini ve mevcut tercih/abonelik kurallı push outbox'ını aynı transaction'da yazar. Bu fonksiyon ağdan push göndermez.
- Circuit alerted işareti yalnız en az bir alıcıya bildirim kuyruğu yazıldıysa aynı transaction'da güncellenir. Alıcı yoksa yeniden değerlendirme mümkün kalır; rollback bildirim/outbox ve acknowledgement'ı birlikte geri alır. Aktif olmayan provider için yeni bildirim hazırlanmaz.
- Bounded `scanProviderOutages` tenant başına en eski25 (en fazla100) vadesi gelmiş kaydı seçer; her kayıt altında recovery/prior alert tekrar kontrol edilir. Bu scanner henüz worker zamanlayıcısına bağlanmadı; otomatik15dk teslimat kabulü henüz sağlanmadı.
- Test koduna erken bildirim reddi, rollback, iki worker tek bildirim ve tekrar scan'de duplicate olmaması eklendi. Test/typecheck/lint/build çalıştırılmadı. Migration/API/client sözleşmesi değişmedi; mevcut bildirim inbox'ı kullanılır. Provider adapter/probe-worker ve kalan fazlar açık; goal aktif.

### 2026-10-27 — Worker kesinti bildirim zamanlaması ve ortam sınırı

- Yeni `POST /api/internal/v1/provider-circuits/alert-scan` boş strict body, runtime surface token, signed service account ve runtime.jobs.execute ile en fazla25 aday işler. Tenant ve ortam body'den alınmaz; runtime auth'tan gelir. Provider ortamı seçmede ve kilit altında tekrar kontrol edilir; başka ortamın circuit kaydı güncellenmez. Yanıt yalnız examined/notified, no-store.
- Etkin worker, job çalıştırma döngüsünden bağımsız dakikalık provider outage monitor başlatır. Uzun import işleri taramayı bloke etmez. Monitor başarısı/hatası/bildirim sayısı/son başarı metriklerde;120sn başarılı tarama yoksa worker readiness başarısızdır. Shutdown abort beklemeyi sonlandırır; istekler mevcut10sn timeout'u kullanır. Dispatch feature flag açılmadı.
- API/signed tenant-environment ayrımı/scope iptali/strict payload/replay ve monitor shutdown/error metrik senaryoları yazıldı. OpenAPI üretildi. Test/typecheck/lint/build/browser ve canlı worker zamanlama doğrulaması kullanıcı talimatıyla finalde; worker bu tur başlatılmadı, bildirim gönderilmedi.
- Dağıtım sırası API endpoint→worker olmalı; eski API ile yeni worker readiness monitor hatası verir.15dk eşiği sonrası bir sonraki dakikalık turda kayıt hazırlanır; yoğun aday kuyruğu bounded batch ile sonraki turlara kalır. Alıcısız kesintiler bildirilmiş sayılmaz.
- Gerçek provider health/probe adapterı, çağrı dispatcher/reconciliation işçisi, operasyon devre görünümü ve diğer fazlar açık. Bu bildirim zamanlaması telephony sağlayıcı doğrulamasının yerine geçmez; goal aktif.

### 2026-10-27 — ElevenLabs salt-okunur adapter başlangıcı

- Resmî agent GET ve conversation GET sözleşmeleri kontrol edildi: https://elevenlabs.io/docs/api-reference/agents/get ve https://elevenlabs.io/docs/api-reference/conversations/get . Mevcut legacy finalize global config anahtarına bağlı; yeni adapter tenant/provider için çözümlenmiş anahtarı açıkça ister, global fallback yapmaz.
- `createElevenLabsReadClient` sabit https://api.elevenlabs.io origin, GET-only, redirect reddi,10sn timeout,2MiB streaming sınırı ve otomatik retry olmadan agent probe / bound conversation observation sağlar. Yanıt kimlikleri beklenen agent/conversation ile karşılaştırılır; özel konfigürasyon, transcript ve metadata çıktıdan ayıklanır.
- Access denied/not found/rate limit/provider unavailable/invalid response/network/abort ayrıdır; ham provider hata gövdesi ve anahtar hata çıktısına taşınmaz. Conversation failed/done doğrudan SIP end, pre-accept rejection, insan yanıtı veya tüm bacakların nihai maliyeti sayılmaz; final_cost_verified=false kalır.
- Stub transport test kodu tekGET/no retry, yanlış binding, gizli alanların çıkarılması, bilinmeyen status, auth/HTTP ayrımı, bozuk/büyük yanıt, iptal ve path injection reddini kapsar. Test/typecheck/lint/build çalıştırılmadı; gerçek sağlayıcı isteği yapılmadı.
- Yerel .env anahtar değerleri gösterilmeden kontrol edildi; ElevenLabs API key görünmedi, bağlı ElevenLabs aracı yok. Kullanıcıdan staging/SIP/test hattı ve güvenli secret referansı bilgisi istendi. Secret resolver, hesap/hat doğrulaması, SIP adapter, probe worker ve tam outbound correlation hâlâ açık. Diğer bağımsız geliştirmeler devam edebilir; goal aktif.

### 2026-10-27 — Tenant/ortam/hesap bağlı ElevenLabs secret çözümü

- API deployment-owned `CALLER_ELEVENLABS_BINDINGS` JSON yapılandırmasını okuyabilir. Her giriş tenant_public_id, tenant_environment_public_id, provider_account_public_id, provider_account_ref, secret_ref, agent_id ve api_key içerir. UUID scope normalize edilir; tekrar scope, bilinmeyen alan, bozuk kimlik ve256KiB/100 kayıt sınırı aşımı startup'ta sır içermeyen tek hata ile reddedilir. Değer yoksa boş allowlist, outbound anahtar yoktur.
- Resolver aktif tenant+ortam+elevenlabs/api_key provider row'unu scope ile bulur ve tüm referansları server allowlist ile eşleştirir. Tenantın auth_secret_ref değeri dosya/env/vault yolu olarak takip edilmez. Legacy ELEVENLABS_API_KEY fallback yoktur. Dönüşte raw key değil kapalı private read-client ve agent kimliği bulunur; client JSON'a çevrilince key taşınmaz.
- Bu yapılandırma güvenli deployment secret olarak sağlanmalı; repoya veya sohbet mesajına gerçek değer yazılmamalıdır. Mevcut .env değiştirilmedi, key sağlanmadı ve sağlayıcıya istek yapılmadı. Bu ilk resolver küçük deployment allowlist'idir; hesap sahipliği/SIP yetkinlik doğrulaması değildir. Operatörün ayrı SIP kimlik bilgisi bu ElevenLabs anahtarına karıştırılmaz.
- Unit parser ve integration resolver için global fallback reddi, farklı tenant/ortam, secret-ref değişimi, doğru binding ve key serialization kontrolü yazıldı. Test/typecheck/lint/build çalıştırılmadı. Gerçek staging secret, SIP/test hattı için önceki soru bekliyor; bağımsız geliştirmeler devam ediyor. Goal aktif.
