# Panel metal yüzeyi v1

Yeni yüzey yerleşik imagegen ile üretildi. Dönen gerçek dosya boyutu: **1254×1254** (prompttaki 2048×2048 talebinden farklı; büyütülmedi).

- Kaynak ve oyun dosyası: `assets/ui/materials/panel_gunmetal_v1.png`.
- Uygulama: `game/ui/panel_material_style.gd` — mevcut çerçeve/perçinler ayrı, yeni yüzey sabit 0.75 texel ölçeğinde döşenir. Çok hafif dikey ışık geçişi ayrı çizilir.
- Kapsam: ana `Panel` / `PanelContainer`, `PanelFlat`, başlık/bölüm bantları, buton durumları, kartlar, sekmeler, menü kutuları, ikon yuvaları, bilgi hücreleri ve tooltip zeminleri.
- Kullanıcının devam isteğiyle buton ve başlık zeminleri de aynı malzemeye geçirildi. Durum renkleri/ışık yönleri eski kaynaklardan alınır. İkonlar, yazı tipleri, panel ölçüleri ve içerik payları değiştirilmedi.
- Önizlemeler: `art/previews/panel_material/comparison.png`, gerçek üretim paneli `production.png`.

## Üretim promptu

Use case: stylized-concept. Asset type: seamless tileable production UI background MATERIAL TEXTURE for a serious 1930s grand-strategy game. Generate a flat orthographic scan of immaculate dark gunmetal blackened steel with a very subtle olive-charcoal undertone, matching RGB around (34,37,39). Premium restrained craftsmanship: extremely fine tight satin metal micrograin, sparse microscopic hairline wear, delicate naturally mottled patina without any recognizable stains. Texture should look rich close up yet quiet under dense ivory text. Uniform low-contrast diffuse illumination; no directional highlight, no vignette. Pixel-perfect square 2048x2048 material swatch, edge to edge, seamlessly tileable on all four sides. Absolutely NO frame, border, screws, rivets, ornament, gold strips, objects, UI controls, writing, logos, numbers, scratches longer than a few pixels, large grain, smeared noise, fabric weave, stone, concrete, rust, sci-fi glowing elements, bevel or 3D perspective. This is ONLY the dark interior metal surface, not a panel mockup. Preserve a narrow dark tonal range, subtle detail and crisp material realism. Opaque image.
