# Yapı piktogramları — açık altın v2

Referans: kullanıcının 28 Eylül 2026, 22:07:32 ekran görüntüsündeki dört yapı rozeti.

Yalnızca iç piktogramlar yeniden çizildi. Düz renk: `#F1DFA5`. Şeffaf zemin, negatif boşluklu pencereler, gölgesiz ve dokusuz silüetler. Çerçeve ve sayılar görsellere gömülmedi.

- `civilian_factory`: üç bacalı sivil fabrika.
- `military_factory`: iki ana bacalı askerî fabrika.
- `anti_air`: referanstaki simetrik uçaksavar silüeti ve kaidesi.
- `naval_base`: halka, gövde ve iki simetrik kolu olan çapa.

Her ikonun ölçeklenebilir SVG kaynağı ve şeffaf 1024×1024 PNG çıktısı vardır. SVG tuvali 256×256'dır.

**Henüz haritaya bağlanmadı.** Mevcut oyun dosyaları, ikon boyutları, levha boyutları, ölçek katsayıları ve konumlar değiştirilmedi. Yeni görseller ayrı klasörde onay için hazırdır.

Üretim yöntemi: mevcut SVG piktogram ailesine uygun vektör çizimi; PNG'ler Godot SVG rasterizer ile çıkarıldı. Görsel üretim modeli kullanılmadı.

Tekrar dışa aktarma ve büyük/küçük boy önizlemesi: `Godot --path . --script tools/preview_building_glyphs.gd --quit-after 120`.
