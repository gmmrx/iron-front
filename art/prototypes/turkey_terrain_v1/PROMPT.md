# Türkiye arazi denemesi — v1

Üretim: yerleşik `image_gen` aracı; `geography-guide.png` coğrafya referansı.
Kaynak görsel: `generated-terrain.png`. Teknik oyun paketi ayrı RGBA dosyasındadır.
Bu bir tarihî hava fotoğrafı veya ölçülmüş 1936 arazi kullanımı verisi değildir; oyunun coğrafyasına kayıtlı, dönem için sanat yönetimi uygulanmış görseldir.

## Coğrafya ve dönem kaynakları

- [Meteoroloji Genel Müdürlüğü — Climate of Turkey](https://www.mgm.gov.tr/FILES/genel/makale/31_climateofturkey.pdf): Karadeniz, Akdeniz ve İç Anadolu iklim ayrımı için.
- [DSİ — Atatürk Barajı](https://www.dsi.gov.tr/Haber/Detay/13076): modern baraj göllerini dönem görseline eklememe kararı için; su tutulması 1990.
- Kesin kıyı/oyun maskesi: projenin Miller izdüşümlü province ve terrain verisi. Referans render dikdörtgeni `[8748, 3072, 1024, 512]`, kuzey üstte.

## Tam üretim promptu

Use case: historical-scene / style-transfer.
Asset type: production terrain albedo / painted geographical ground texture for a WWII grand strategy game, Turkey and immediately surrounding land circa 1936–1945.
Input Image 1 is the EXACT geography and camera/projection guide. Replace its crude terrain rendering with exceptionally detailed, restrained photorealistic cartographic terrain artwork. Preserve the precise image-edge crop, north-up 90-degree overhead orthographic viewpoint, all sea coastlines, islands, Marmara, Bosporus, Dardanelles, Lake Van and Lake Tuz positions and shapes. Match every coast pixel location and the same 2:1 canvas; do not reframe or move geographic features. Use the highest available landscape resolution, ideally 4096 by 2048 or higher.
All black internal province/state boundary lines MUST disappear completely. They are game UI, not roads. No labels, names, borders, text, legends, grids, frames, logos or interface. No clouds, haze, bloom, depth of field or vignettes.
Land should look like an exquisitely resolved natural aerial terrain mosaic with fine dendritic erosion, layered limestone ridges, narrow stream valleys, small irregular dry agricultural parcels on valley floors, sparse olive landscapes along the Aegean, scrub and pale rock on Mediterranean hills, deep natural mixed forest in the narrow humid Black Sea belt and especially northeast, olive-grey and tawny Central Anatolian steppe plateaus with broad quiet basins, rugged grey-brown eastern highlands, restrained seasonal snow only on highest peaks, dry ochre southeastern plains. Turkey is not a sand-dune desert. Preserve the major mountain-chain positions in the guide but substantially soften their harsh exaggerated black shadows. Fine surface detail must be sharp everywhere and have realistic hierarchy: vast plains with restrained detail, organically branching ravines on slopes, no equally noisy texture blanket. Natural rich colours: moss green, muted olive, wheat, warm limestone, slate; sea quiet deep muted blue-green with a very narrow natural shore transition, no white coastline strokes.
1930s–1940s rural land use only. Do not bake in cities, buildings, military units, bridges or ports: the game places real 3D objects separately. No modern highways, airport runways, giant rectilinear industrial farming, wind turbines, solar farms or modern dam reservoirs (Ataturk, Keban, Karakaya). Rivers should remain thin and geographically plausible. This is a coherent playable terrain texture, not an illustration of a raised miniature, not a folded map, not an oblique diorama, not a game screenshot.
Lighting: neutral evenly lit diffuse daylight with subtle northwest relief shading, enough tonal headroom for real-time game lighting, no deep black mountain crevices. Crisp microdetail without oversharpening or painterly smudges. The result must read beautifully at whole-country scale and when inspecting regional crops. Preserve reference coastline registration above all.

## Yakın yüzey promptu

Use case: historical-scene.
Asset type: seamless tileable top-down aerial terrain detail texture for a high-end WWII grand strategy game, central Anatolian rural steppe circa 1936. Generate one square texture at maximum available native resolution.
A perfectly flat, north-up, 90-degree nadir aerial ground image. An unremarkable two-kilometre-wide area of dry Anatolian rolling countryside: buff limestone soil, muted tawny dry grass, irregular small old agricultural strips, fallow fields, softly branching narrow erosion gullies, occasional sparse low scrub and olive-grey vegetation. Fine physical surface details across the entire frame. Approximately 65 percent naturally weathered dry steppe and 35 percent tiny subdued irregular rural parcels, parcels blending into terrain and following contours. No central focal point and no large hills. Restrained low-contrast light tan, wheat, muted olive, grey limestone; rich detail but no dark black shadows. Completely flat neutral diffuse daylight, no directional baked light. Truly seamless left-to-right and top-to-bottom with matched edge content; no visible tile border, uniform mean brightness, no vignette.
This will be sampled repeatedly at tiny world scale as the close-up microstructure under a country map, so avoid large distinctive landmarks, prominent features, regular checkerboard farming grids and artificial noise. Natural aerial photograph quality, not an oil painting and not a macro photograph of dirt. No water, lakes, large rivers, cities, buildings, vehicles, highways, labels, text, borders, clouds or UI. No modern industrial farming. Crisp surface everywhere, no blur.
