# Bildirim ikonları — yeni UI, 2 Ekim 2026

Üretim: yerleşik imagegen aracı; her ikon ayrı üretilmiş şeffaf PNG.
Referanslar: `assets/ui/sheet/icon_army.png`, `icon_supply.png`.
Siyah zemin ve altın çerçeve yeni UI'ın mevcut `btn_square.png` dosyasından gelir.

Bildirim kutusu 62 px, ikon alanı en çok 54 px: mevcut yerleşim değişmez.
Bütün görseller yalnız AlertBar tarafından kullanılır; diğer menü ikonları değiştirilmez.
Tam çözünürlüklü PNG kaynakları burada saklanır; Godot ithal dokuyu 256 px ile sınırlar
ve mipmap üretir. Böylece küçük boyda keskin kenarlar, yüksek DPI'da yeterli detay
ve düşük GPU bellek maliyeti korunur. Üretimdeki alfa kanalı değiştirilmez.

## Ortak üretim promptu

Use case: stylized-concept. Asset type: production-ready WW2 strategy game notification icon, transparent PNG. Match the reference icons' warm champagne-gold cast-metal relief, strong simple silhouettes, pale gold upper-left highlights, bronze bevels, very dark narrow recessed edges, restrained satin metal. This is part of a coherent icon family shown at 44 pixels within the existing black/gold UI. One single isolated emblem centered on a square canvas, visual bounds occupying 80 percent of canvas with safe transparent margins, not a scene. Genuinely transparent background, no tile, no frame, no pedestal, no lettering, no numbers, no watermark, no glow or colored particles, no elaborate engraving. Low detail broad readable shapes. Reference images show material/style only; do not reproduce their objects unless requested. Subject: 

## Konu promptları / dosyalar

- `event.png`: A closed military dispatch envelope, its folded triangular flap and one small round seal clearly readable. Gold metal envelope emblem, nearly frontal view.
- `research.png`: One upright Erlenmeyer laboratory flask with a short thick neck, broad triangular body and simple liquid meniscus. Gold metal bas-relief icon, frontal view; no bubbles or atom decoration.
- `construction.png`: One substantial engineer's hammer crossed with a large open-ended wrench. Two clean separate gold metal tool silhouettes, compact symmetric diagonal composition.
- `recruit.png`: One WWII infantry helmet, three-quarter side view, with one small raised plus sign at lower right, gold metal emblem. Helmet and plus are distinct and readable; no face.
- `wings.png`: One WWII single-engine propeller fighter airplane viewed from directly above, nose pointing up, broad wings horizontal, unmistakable tail. Gold metal relief; no insignia.
- `supply.png`: One military supply crate in slight three-quarter view, with two broad bands and a simple central latch. Gold metal relief; no lettering, no hazard markings, no gear.
- `motivate.png`: One five-point military service star between two short upward laurel branches. Simple solid star, only three broad leaves on either side, gold metal relief badge with no enclosing circle.
- `manpower.png`: Three simplified human shoulder-and-head bust silhouettes, center larger and forward, two behind, all gold metal relief. Clear negative spaces distinguish three people, no individual faces, no helmets.
- `surrender.png`: One broad heater shield with a single bold diagonal crack dividing its face into two still closely spaced halves. Gold metal relief military crisis emblem. No swords, no flag, no letters.

## Doğrulama

`tests/test_alert_icons.gd`: dosya eşleşmesi, önbellek, alfa, mipmap, boyut, tooltip, önem kaplaması ve tıklama eylemi.
`tools/preview_alert_icons.gd`: gerçek yeni TopBar içinde 62 px ve 2× detay görünümü.

Alttaki önem şeritleri kaldırıldı: kutunun içinde hafif renk kaplaması var.
Kutunun tamamı (ikon ve çerçeve dahil) opacity ile %100 → %45 → %100 hafifçe sönüp yanar:

- Acil: 2,8 saniyede bir.
- Uyarı (araştırma, inşaat, insan gücü): 7 saniyede bir.
- Bilgi (hava görevi, teşvik): 12 saniyede bir.
- Asker alma: 20 saniyede bir.

Her yanıp sönme 0,5 saniye sürer: 0,25 saniyede hafifçe söner ve beklemeden
0,25 saniyede geri gelir. Tamamen kaybolmaz; aralarda tamamen görünürdür.
Parlaklık ve hale animasyonu yoktur; hafif önem rengi sabittir.
Kutunun yerleşimi ve tıklama alanı sönükken de korunur.
Sayaç/açıklama yenilendiğinde animasyon sıfırlanmaz. Animasyon gerçek zamana
bağlıdır, oyun hızıyla hızlanmaz. İkon kaynakları, ölçüler ve eylemler değişmedi.
Gerçek Forward+ arayüz önizlemesi:
`art/previews/alerts_gold/notification_set.png`.
