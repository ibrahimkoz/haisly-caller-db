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
