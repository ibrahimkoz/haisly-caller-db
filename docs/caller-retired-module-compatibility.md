# Caller — Kaldırılmış modüllerin veri uyumluluğu

8 Kasım 2026, R01-T01.

Güncel kapsam ve task takibi API reposundaki `SPEC.md`, `IMPLEMENTATION_PLAN.md` ve `docs/r01-dependency-inventory.md` dosyalarındadır.

Migration 230 HubSpot verisini, 233 genel simülasyon panelinin bağımsız yapılarını, 234 standalone agent/config, bilgi bankası ve guardrail editörü tablolarını, 235 bağımsız kişisel veri yönetimi tablolarını kaldırır. Kampanya yayın senaryoları ve runtime consent/DNC altyapısı korunur.

`calls`, `call_sessions`, `metric_snapshots`, `tenant_tool_bindings`, `tenant_workflow_bindings`, `simulation_scenarios`, `simulation_runs`, `routing_rules` ve `caller_inbound_greeting_pins` içindeki eski numeric agent/config kolonları tarihsel uyumluluk içindir. Silinmiş agent tablosuna FK ile bağlanmazlar. Yeni uygulama yazmaları agent ID kabul etmez; aktif bağlam tenant environment ve kampanya yayınından gelir. Inbound greeting pin oluşturma guard tarafından engellenir.

`agents.manage`, `ai.read` ve `ai.manage` permission kodları ortak runtime/araç/ortam/yayın yetkilerinde kullanıldığı için korunur. Seed açıklamaları güncel kapsamı anlatacak şekilde düzenlenmiştir; kodların kaldırılması veya yeniden adlandırılması ayrı migration gerektirir.

Tarihsel migration/rollback dosyalarındaki eski tablo adları canlı bağımlılık değildir. Geçmiş migration'ları değiştirmek yerine sıralı migration yolu korunur. Yıkıcı kaldırmaları geri almak için uygun uygulama sürümüyle birlikte öncesindeki yedeğe dönülür.
