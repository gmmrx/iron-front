# Türk piyadesi — resim referansından hacimli 3D prototip

Kaynak: [001 Türk piyadesi paftası](../../references/ww2/001_turkish_infantry_1939/turnaround_v01.png).

## Dosyalar

- `turkish_infantry_v01.blend`: düzenlenebilir mesh, UV'ler, paketlenmiş dokular ve render stüdyosu.
- `turkish_infantry_v01.glb`: stüdyo hariç hacimli model ve gömülü dokular.
- `textures/turkish_infantry_basecolor_2k.png`: 2048×2048 renk atlası.
- `textures/turkish_infantry_normal_2k.png`: 2048×2048 normal atlası; malzeme mikrodetayından bake edildi, taranmış yüksek poligon detayı değil.
- `textures/turkish_infantry_roughness_2k.png`: 2048×2048 pürüzlülük atlası.
- `textures/reference_albedo.png`: orijinal referansın kopyası.
- `preview_front.png`, `preview_three_quarter.png`, `preview_rear.png`: gerçek Blender/Cycles renderları. Imagegen ile yapılmadı.
- `model_stats.json`: gerçek mesh istatistikleri ve sınırlar.

## Nasıl üretildi?

Otomatik image-to-3D servisi veya fotogrametri kullanılmadı. Ön görünüşün silueti ve ortak ekipman bilgisi esas alınarak Blender betiğiyle 3D hacimler kuruldu; görünmeyen derinlik elle belirlendi. Yüz ve bazı kıyafet alanlarında paftanın renkleri UV projeksiyonuyla kullanıldı. Kemer, cepler, askılar, matara, kep, dolaklar, bot ve eller gerçek geometri; kıyafet/deri malzemeleri ayrıca oluşturuldu. Taşınabilir 2K atlaslara bake edilip GLB içine gömüldü.

2K atlas, kaynak yüz görüntüsüne yeni ayrıntı eklemez. Kaynak paftadaki ön yüz birkaç düzine piksel genişliğinde olduğundan yakın plan keskinliği sınırlıdır; bazı albedo alanları kaynak ışık/gölgelerini içerir.

## Henüz üretim modeli değil

- Tarihsel üniforma doğrulaması ve sanatçı temizliği bekliyor.
- Görünen cep/kıyafet oranları ve yüz benzerliği yaklaşık; birebir tarama değil.
- Yalnızca asker ve üzerindeki teçhizat üretildi; tüfek bu prototipe dahil değil.
- A-pozu statik; rig ve animasyon yok.
- Yeniden topoloji, LOD ve harita ölçeğinde performans optimizasyonu yapılmadı.
- Mevcut oyun askerleri değiştirilmedi; bu dizin `.gdignore` ile çalışma arşivi olarak ayrıldı.

## Tekrar üretim

Proje kökünden:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/prototype_turkish_infantry.py
```

Betik yalnızca bu prototip klasöründeki kendi çıktılarının üzerine yazar; oyun assetlerine dokunmaz.
