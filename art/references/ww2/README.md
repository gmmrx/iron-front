# IRON FRONT — WW2 2D → 3D referans arşivi

Ana belge: [110 prompt](../../../docs/art/3d-model-animation-prompts.md). Ayrıntılı takip: [manifest.json](manifest.json).

## Durum — 2026-09-25

- **16 taslak pafta kaydedildi.** Üretim yöntemi: built-in image_gen. Çıktılar 1536×1024 PNG; 4K hedefi gerçekleşmedi, dosyalar büyütülüp 4K diye sunulmadı.
- Görsel üretimi kullanıcının isteğiyle durduruldu; devam edilirse sıra **018 — Cromwell IV**. Önceki kota engeli kalktı. Şu an çalışma: 001 Türk piyadesinden ayrı bir 3D prototip.
- 002 Alman piyadesi çıktı güvenlik filtresinde reddedildi; görsel yok. Prompt/hata kaydı korunuyor, filtre aşma girişimi yapılmadı.
- 010–012, Britanya temelinin ilk rol örnekleri. Diğer ülkelerin rol varyantları ayrıca üretilecek.
- Hiçbir pafta Blender'a hazır/onaylı teknik çizim değildir. Görsel ve tarihsel düzeltmeler REVIEW dosyalarında. Ayrı yüksek çözünürlüklü açılar ve aksesuar/parça paftaları henüz bekliyor.
- 001–094 model/kit, 095–110 animasyon/efekt briefleridir; kitler ayrı nesnelere açılır. Bu yüzden 110 brief = 110 tekil model değildir.
- Mevcut oyun modelleri ve kod değiştirilmedi; .gdignore bu çalışma arşivini Godot içe aktarımından ayırır.
- Otomatik arka plan devam görevi kurulmadı. Alternatif CLI/API yöntemi OPENAI_API_KEY ve kullanıcının açık isteğini gerektirir; kullanılmadı.

## Görseller

| ID | Konu | Pafta | Kontrol notları |
| --- | --- | --- | --- |
| 001 | Türk piyadesi | [Görsel](001_turkish_infantry_1939/turnaround_v01.png) | [İnceleme](001_turkish_infantry_1939/REVIEW.md) |
| 003 | Sovyet piyadesi | [Görsel](003_soviet_infantry_1941/turnaround_v01.png) | [İnceleme](003_soviet_infantry_1941/REVIEW.md) |
| 004 | Britanya piyadesi | [Görsel](004_british_infantry_1940/turnaround_v01.png) | [İnceleme](004_british_infantry_1940/REVIEW.md) |
| 005 | ABD piyadesi | [Görsel](005_us_infantry_1944/turnaround_v01.png) | [İnceleme](005_us_infantry_1944/REVIEW.md) |
| 006 | Fransız piyadesi | [Görsel](006_french_infantry_1940/turnaround_v01.png) | [İnceleme](006_french_infantry_1940/REVIEW.md) |
| 007 | İtalyan piyadesi | [Görsel](007_italian_infantry_1940/turnaround_v01.png) | [İnceleme](007_italian_infantry_1940/REVIEW.md) |
| 008 | Japon piyadesi | [Görsel](008_japanese_infantry_1941/turnaround_v01.png) | [İnceleme](008_japanese_infantry_1941/REVIEW.md) |
| 009 | Çin Milliyetçi piyadesi | [Görsel](009_chinese_infantry_1937/turnaround_v01.png) | [İnceleme](009_chinese_infantry_1937/REVIEW.md) |
| 010 | Makineli tüfekçi (ENG) | [Görsel](010_british_machine_gunner_1940/turnaround_v01.png) | [İnceleme](010_british_machine_gunner_1940/REVIEW.md) |
| 011 | Topçu mürettebatı (ENG) | [Görsel](011_british_artillery_crew_1940/turnaround_v01.png) | [İnceleme](011_british_artillery_crew_1940/REVIEW.md) |
| 012 | Subay / birlik komutanı (ENG) | [Görsel](012_british_field_officer_1940/turnaround_v01.png) | [İnceleme](012_british_field_officer_1940/REVIEW.md) |
| 013 | Panzer II Ausf. C | [Görsel](013_panzer_ii_ausf_c/turnaround_v01.png) | [İnceleme](013_panzer_ii_ausf_c/REVIEW.md) |
| 014 | Panzer IV Ausf. G | [Görsel](014_panzer_iv_ausf_g/turnaround_v01.png) | [İnceleme](014_panzer_iv_ausf_g/REVIEW.md) |
| 015 | T-26 | [Görsel](015_t26_1939/turnaround_v01.png) | [İnceleme](015_t26_1939/REVIEW.md) |
| 016 | T-34/76 Model 1942 | [Görsel](016_t34_76_1942/turnaround_v01.png) | [İnceleme](016_t34_76_1942/REVIEW.md) |
| 017 | Light Tank Mk VI B | [Görsel](017_light_tank_mk_vib/turnaround_v01.png) | [İnceleme](017_light_tank_mk_vib/REVIEW.md) |

## Blender öncesi zorunlu kontrol

1. Ülke, yıl, üretim alt varyantı, kıyafet/silah/araç ayrıntıları tarihsel kaynakla doğrulanır.
2. Çapraz görünüşlerde oran, parça sayısı, cep/kayış/kapak yerleşimi ve sağ/sol mekanizmalar eşleştirilir.
3. Perspektifli üst/alt açılar ve kısalan/kırpılan namlular gerçek ortografik görünüşlerle düzeltilir; mevcut paftalardan ölçü alınmaz.
4. Seçilen tasarımın her açısı ve aksesuarları ayrı yüksek çözünürlüklü dosya olarak üretilir.
5. Blender'da gerçek ölçü, topoloji, UV/PBR, ayrı hareketli parçalar, rig ve LOD hazırlanır; ancak sonra animasyon paftaları/klipleri uygulanır.

## Dosya düzeni

- `NNN_slug/turnaround_v01.png`: modelin ilk çok açılı taslağı.
- `prompt_v01.md`: gerçekten gönderilen tam prompt; varsa referans görüntü yolu.
- `REVIEW.md`: inceleme bulguları ve eksikler.
- Düzeltme `v02` olarak kaydedilir; eski çıktılar silinmez.
