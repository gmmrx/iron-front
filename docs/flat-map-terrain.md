# Düz zemin, ayrıntılı 2D arazi, 3D modeller

Harita zemini her zoom seviyesinde `y = 0` düzlemidir. Dağ, orman, tarla, bozkır, çöl ve kar görüntüsü mevcut arazi/biyom dokuları ve yüzey gölgelemesiyle okunur; dağların gerçek geometri kabartması yoktur.

- Ham yükselti dokusu silinmez: kaya, dağ sırtı gölgesi, biyom ve kar hesapları için saklanır.
- `RELIEF_SCALE` yalnız boyalı yüzey gölgesine aittir. `HEIGHT_SCALE = 0` ve `height_at() = 0` model, yol ve tıklama konumlarını aynı düzlemde tutar.
- İnşaat/şehir/havaalanı yerleşimi arazi resmini düzleştirip detaylarını silmez.
- Asker, tank, uçak, gemi, yapı ve köprülerin 3D varlıkları korunur. Mevcut görünürlük ve zoom eşikleri değiştirilmez; önceden kapalı yapı katmanları bu değişiklikle açılmaz.
- Her harita parçası iki üçgenden oluşur; parça görünürlük elemesi ve doğu-batı sarmalama korunur.
- Yakın siyasi görünümde de mevcut boyalı arazi detayları kullanılır; uzak ülke renkleri ve sınırlar korunur.
- Ayrı Three.js web haritası zaten düz bir düzlem kullanır; bu değişiklik Godot istemcisini de aynı geometrik kurala taşır.

Doğrulama: `tests/test_flat_map.gd`; gerçek shader önizlemesi: `tools/preview_flat_map.gd` (sahnedeki iki örnek figür yalnız kontrol amaçlıdır, oyun durumuna eklenmez).
