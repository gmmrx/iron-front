# Sabit ölçekli şehirler ve boğaz minyatürleri

## Görünüm sözleşmesi

- Şehir modellerinin dünya genişliği kademeye göre 4.0 / 3.5 / 3.0 / 2.6 / 2.2 birimdir. Kamera, odak veya hover modeli yeniden ölçeklemez. Yakınlaşınca perspektif nedeniyle ekranda doğal olarak daha büyük görünür; dünya ölçüsü değişmez.
- Mevcut yakın-zoom görünürlük sınırları korunur. Minyatürler uzak stratejik haritayı doldurmaz; görünürlük sırasında pop/büyüme animasyonu uygulanmaz.
- Her şehrin tek normal harita etiketi vardır. Şehir adı, harf biçimi, Barlow fontu, renk, piksel boyu ve dünya anchor'ı zoom boyunca sabittir. Yakınlaşınca serif fonta/kutulu başlığa geçilmez.
- Boğaz adları da kutusuz, sabit ekran tipografili normal harita etiketleridir. Köprülerin eni, yüksekliği ve konumu kamera uzaklığıyla ölçeklenmez.
- Bütün boğaz geçişleri köprüyle gösterilir. Boğaz katmanına liman, terminal, fener veya sivil vapur yerleştirilmez; bu yorum kullanıcı tarafından reddedildi.
- Arazi düz kalır; modeller gerçek 3D mesh ve native PBR malzemeleridir. Şehir veya boğaz için render edilmiş bir görsel billboard olarak kullanılmaz.
- Şehirlerin gerçek küçük ayak izinde boyalı dağ/eğim, orman ve tarla detayları yumuşatılır. Bunun için terrain dokusunun mevcut alfa kanalı kullanılır; yeni shader sampler eklenmez. RGB arazi ve ham RF yükseklik verisi değişmez, geometri yine sıfır yüksekliktedir.
- Minyatürün altındaki ince, kenarı dağılan toprak parseli ve yerel çıkış yolları kamera ile ölçeklenmez. Sokak çıkışları exported şehir mesh'indeki gerçek normalize uçlara hizalanır; küçük kentlerde iki ana yaklaşım, daha büyüklerinde bir kısa yan sokak vardır. Denize taşan uçlar kesilir, yol sonları yumuşak söner; yükseltilmiş şehir kaidesi yapılmaz.
- Limanlar ayrı kıyı katmanındaki gerçek rıhtım/ambar/vinç mesh'idir; liman billboard'u ve deniz üssü iğne rozeti oluşturulmaz. Model yalnız yakın görünümde belirir, boyu sabittir; savaş sisi, mevcut yapı bilgi kartı ve tıklamayla eyalet seçimi korunur. Boğaz köprü katmanına liman eklenmez.
- Kıyı şehirleri gerçek model dönüşüne uyan dikdörtgen ayak iziyle aranır; tam kuru adaylarda daha sık örnekleme içbükey kıyı köşelerini yakalar. Bu görsel merkez oyun şehrinin koordinatını değiştirmez. Liman genişliği 2.6 dünya birimiyle sabittir.
- Bu değişiklik yalnız görseldir. Şehir koordinatları, boğazların `land_crossing` değerleri, savaş/geçiş kuralları ve UI tasarım dili değiştirilmez.

## Boğazların sanat yönü

Çelik kafes, gerçek kirişler/perçinler ve taş başlıklardan oluşan köprü kiti tüm boğazlara uygulanır. `little_belt_span/end` dosya adları kaynak kitin ismidir; kullanım yalnız Küçük Belt ile sınırlı değildir. Görsel geçişler oyunun istediği harita dilini temsil eder; ayrı ayrı tarihsel yapı rekonstrüksiyonu iddiası yoktur.

Mevcut geçiş verisindeki uçlar kıyı değil, kanal içindeki su pikselleriydi. Köprünün görsel uçları bu yüzden gerçek karşı kıyı örnekleriyle bulunur; oyun verisi değiştirilmez. Başlıkların gerçek mesh izdüşümü karada ve tabanları düz zemindedir; köprü ortası suyu geçer. Güverte yüksekliği başlığın imported AABB tabanından hesaplanır, rastgele yükseltilmez.

İlk üretilen sivil terminal/vapur çalışmaları kaynak dosyalarıyla korunur ama aktif model kütüphanesine alınmaz. Bunlar donanma gemilerinin yerine kullanılmaz. Filo katmanı ayrı `units.glb` savaşgemisi kaynaklarını ve mevcut sayaç görünümünü kullanır; bu düzeltme filo kodunu değiştirmez.

## Kaynaklar ve doğrulama

- Şehirler: `tools/blender/build_mini_cities.py`, `assets/models/mini_city/`, `art/source/mini_city/library.blend`.
- Boğazlar: `tools/blender/build_strait_assets.py`, `assets/models/strait/`, `art/source/strait/`.
- Yerel şehir zemini/sokakları: `game/map/city_ground.gd`, `assets/shaders/city_ground.gdshader`. Mevcut toprak ve döşeme dokuları iki ortak malzemede paylaşılır; küçük mesh yalnız şehir ilk yakında görünürken kurulur, zoom sırasında tekrar üretilmez.
- Liman: `game/map/port_models.gd`, `game/map/port_layer.gd`; mevcut `buildings.glb:port_0` tesisinin native albedo/normal/UV malzemeleri korunur. Kaynak çalışmadaki sivil gemi yüzeyleri ve geniş gömülü taban canlı tesise alınmaz. Rıhtım ve ambar gerçek karada, dar iskele gerçek denizde örneklenir. İç kesimde etiketlenmiş beş limanın görsel tesisi en yakın uygun kıyıyı kullanır; kaynak şehir/eyalet ve oyun mantığı değişmez.
- Şehirlerin mevcut albedo/normal atlasları köprü kitinde de kullanılır. Kiriş, kafes, perçin, korkuluk ve başlıklar geometri olarak modellenir; native glTF malzemeleri korunur.
- `tests/test_map_pins.gd`: dünya ölçüsü, zoom/hover/focus/görünürlük sabitliği ve yerle temas.
- `tests/test_map_label_stability.gd`: tek kutusuz etiket ve zoom/hover boyunca değişmeyen şehir tipografisi.
- `tests/test_mini_city_assets.gd`: sekiz şehir mesh'i, UV/normal/vertex tint, paylaşılan kaynaklar ve geometri bütçesi.
- `tests/test_strait_models.gd`: boğaz köprü mesh'leri, bütün geçişlerde köprü, sivil model bulunmaması, sabit yerleşim/etiketler ve gerçek kıyıya/zemine temas.
- `tests/test_flat_map.gd`: düz zeminin mevcut sözleşmesi.
- `tests/test_city_terrain_sites.gd`: RGB/RF korunması, tek toplu upload, maske taşıma/silme, kıyı, sarmalama ve farklı doku çözünürlüğü.
- `tests/test_city_ground.gd`: paylaşılan malzemeler, küçük sabit ayak izi, kıyıda kuru geometri ve modelle birlikte görünürlük.
- `tests/test_port_models.gd`: native tesis yüzeyleri, gerçek kuru rıhtım/ıslak iskele, aktif liman eyaletleri, fog ve mevcut harbor sözleşmesi.
- `tools/preview_map_landmarks.gd`: gerçek oyun aydınlatmasıyla Ankara'yı 350/150/90/55; beş boğazı 100/55 kamera mesafesinde çeker. Model transform'u ile yazı/font/renk/anchor değişmezliğini karşılaştırır. 650 mesafede şehirlerin gizli olduğunu doğrular. `--bridges-only` şehir çekimlerini atlar; her 11 geçişte köprü ve sıfır sivil model bulunduğunu kontrol eder.

`--settlements-only`, boğaz çekimlerini atlayıp şehir zemini, sokaklar ve fiziksel limanları İstanbul/Londra/Tokyo'da 100/55 mesafede kontrol eder. Şehir modeli, yerel zemin, liman transform'ları ve etiket biçimi zoom boyunca karşılaştırılır. Maskenin RGBA alfa kanalı yaklaşık 44 MB mipli GPU belleği ekler; commit sonrası büyük CPU resim kopyası tutulmaz. Yeni zemin mesh'leri şehir başına iki yüzeydir; ortak dokular/malzemeler ayrı kopyalanmaz.

Önizlemeler `art/previews/landmarks/{forward_plus,gl_compatibility}/` altında saklanır. Compatibility kontrolü, ayrı web prototipinin veya tarayıcı performansının test edildiği anlamına gelmez. “AAA” için tek bir görsel yeterli kabul edilmez; gerçek harita okunabilirliği, ölçek, geometri, malzeme ve iki render yolu ayrı kontrol edilir.

Godot'un mevcut kapanış Resource/ObjectDB tanıları bu testlerin assertion hatası olarak değerlendirilmez; ayrı yaşam döngüsü temizliği konusudur. Sabit şehir ölçeği ve tipografisi korunur.

Köprü-only düzeltmesinin 4 regresyon testi geçti: native bridge assetleri, 11 gerçek karşı kıyı geçişi, 22 karada/zeminde köprü başlığı, yalnız 2 bridge mesh kaynağı yüklenmesi, liman/feribot bulunmaması ve normal sabit etiketler.

Şehir zemin/liman güncellemesinde 42 ilgili test geçti (pin etkileşimi 13, şehir etiketi 2, mini-city asset 3, şehir zemini 3, arazi parsel maskesi 4, düz harita 4, liman/kıyı/fiziksel seçim 6, render LOD 3, boğaz köprüleri 4). Aktif limanlar 301/301; 94 büyük kıyı kentindeki tüm native bina/çatı vertexleri karada doğrulandı. Headless LOD testinin gerçek GPU yüzey kontrolü için ayrıca renderer gerektirdiği uyarısı korunur. Forward+ ve Compatibility gerçek harita çekimleri zoom/model/zemin/etiket/fiziksel liman seçimi kontrollerinden geçer.
