# FPS incelemesi ve ilk optimizasyonlar — 1 Ekim 2026

## Kapsam ve ölçüm sınırları

Godot istemcisi ve web prototipindeki etkin çizim/simülasyon yolları incelendi.
Çalışma ağacında eşzamanlı geliştirme var: aşağıdaki ilk ölçümler önceki kod
anlık görüntüsüne aittir; sonraki değişikliklere otomatik olarak atfedilemez.
Görsel dil, ikon boyları, asker görünürlüğü ve keşif kuralları korunmalıdır.

İlk inceleme: Apple M1 Max, Türkiye, oyun duraklatılmış, kamera mesafesi 4200,
5 saniyelik kısa örnekler:

| Koşul | Ortalama FPS | p95 kare süresi |
| --- | ---: | ---: |
| İlk mevcut durum | 75,1 | 15,5 ms |
| Savaş sisi kapalı (--nofog) | 90,2 | 13,0 ms |
| Etiketler kapalı | 74,0 | 15,6 ms |
| SSAO, glow ve gölgeler birlikte kapalı | 80,8 | 14,6 ms |

Bunlar garanti edilen kazanç yüzdeleri değildir. --nofog görünür birlik sayısını
da değiştirir, yalnız bulutun GPU maliyetini ölçmez. Metal GPU zamanlayıcısının
0,00 ms raporu gerçek sıfır maliyet anlamına gelmez. Etiketleri kapatmak draw
call sayısını 367'den 221'e düşürdü, fakat bu örnekte FPS'i iyileştirmedi.

## Bulguların tamamı

### 1. Hacimli bulut — uygulandı: uzak örnekleme bütçesi

- İlk durum: tam çözünürlükte 28 masaüstü / 20 Compatibility-web adımı.
  Yoğunluk + aydınlatma, adım başına en çok sekiz 3B gürültü örneği kullanıyor.
  Keşfedilmemiş alanın tamamını örten ince tabaka da bu maliyeti taşıyor.
- Yapılan: yakın/iç görünüm aynı bütçede; ışının buluta giriş uzaklığı 700–2800
  arasında arttıkça bütçe kademeli olarak 12'ye düşüyor. Uzun, yatay ışınlarda
  dilimlenmeyi önlemek için eski üst bütçeye kadar örnek sayısı korunuyor.
- Godot ve Three.js aynı yaklaşımı kullanır. Yoğunluk alanı, rastgele şekiller,
  alfa sınırı ve keşfedilmeyen her yerde ince bulut bulunması değişmedi.
- Yarım çözünürlüklü ayrı bulut geçişi bu turda uygulanmadı; derinlik ve keşif
  kenarlarının doğru birleştirilmesi gereken ayrı bir ikinci aşama.
- Dosyalar: assets/shaders/fog_volume.gdshader, web/src/cloud-volume.ts.

### 2. Uzak arazi ağı — uygulandı

- İlk durum: bütün zoom seviyelerinde 4 birim aralıklı ağ. 1024×1024 parça
  131.072 üçgen; ilk bölgesel ölçümde toplam yaklaşık 3,5 milyon primitive.
- Yapılan: 4 / 8 / 16 / 32 birim aralık; 1200 / 2400 / 4000 mesafe eşikleri.
  Bir tam parçanın üçgen sayıları: 131.072 / 32.768 / 8.192 / 2.048.
- Yakın detay değişmedi. Geri geçişte %10 histerezis, sınırda sürekli
  açılıp kapanmayı önler. Bütün parçalar aynı seviyeyi kullanır; doğu-batı
  sarmalama kopyaları da birlikte güncellenir, komşu kenarlar uyumludur.
- Aynı boydaki parçalar aynı mesh kaynaklarını paylaşır; her karede mesh
  üretilmez. CPU yükseklik sorguları, yapı konumları ve seçim mantığı değişmez.
- Yol katmanının yükseklik örnekleme aralığı etkin arazi LOD'unu takip eder.
- Web prototipi zaten düz harita kullanıyor; oraya gereksiz arazi LOD'u eklenmedi.
- Dosyalar: game/map/terrain_grid.gd, game/map/map_view_3d.gd.

### 3. Asker, tank ve uçak LOD — mevcut çalışma korundu, eksikler tamamlandı

- İlk incelemede asker/tank bölme yolu içe aktarılan LOD'ları kaybediyordu.
  Kaynak modeller yaklaşık 52.135 / 50.695 üçgendi.
- Bu uygulama turunun başında kod yeniden okundu: eşzamanlı geliştirmede
  UnitFigures içine LOD aktarımı zaten eklenmişti. Bu çalışma yeniden yazılmadı.
- Yeni plane-model.glb artık AirLayer tarafından PlaneModel ile kullanılıyor.
  Gövde LOD'u da zaten aktarılıyordu; önceki rapordaki eski uçak yolu bilgisi
  artık geçerli değil.
- Yapılan: pervanenin de içe aktarılan LOD'ları süzülerek korunuyor; boş
  pervane seviyeleri eklenmiyor. Tankın normalize ölçeği LOD hata mesafelerine
  uygulanıyor. Asker/tank üst ve kaide, uçak gövde ve pervane için gerçek
  RenderingServer yüzeylerini denetleyen regresyon testi eklendi.
- Yakın örgü, texture, bayrak temizliği, animasyon eksenleri ve boyutlar değişmedi.
- Gerçek çizim testi ek bir sorun gösterdi: AirLayer'ın dünya boyutundaki
  MultiMesh sınırı kamerayı içerdiğinden otomatik LOD yakın ve uzakta aynı
  45.057 gövde üçgenini çiziyordu. Batch grupları artık 1080p'ye normalize
  edilmiş kamera mesafesinde 180 / 380 eşikleriyle paylaşılan, içe aktarılmış
  LOD örgülerini seçiyor. Yüksek çözünürlük daha fazla detay tutar.
  Tekil düşen uçak modellerinin otomatik LOD'u korundu.
- Dosyalar: game/map/unit_figures.gd, game/map/plane_model.gd,
  game/map/air_layer.gd, tests/test_render_lod.gd, tools/test_model_lod_render.gd.

### 4. Ayrı hava bulutu katmanı — uygulandı (2 Ekim)

assets/shaders/clouds.gdshader, cloud_amount sıfırken bile gürültü hesaplıyordu.
Yapılan: miktar 0 iken (kamera ~260'tan yakın) bulut düzlemi hiç çizilmiyor
(MapView3D._cloud_mesh.visible). Görünüm aynı: sıfırda alfa zaten 0'dı.
Bu katman savaş sisi hacminden ayrıdır; savaş sisine dokunulmadı.

### 5. SSAO / glow / gölgeler — uygulandı: uzakta adaptif (2 Ekim)

Bireysel ölçüm (East 1941, M1 Max, vsync açık): 600 uzaklıkta gölge kapalı
p50 8,4 → 5,9 ms; üçü birden kapalı 6,5 ms. 4200'de SSAO/gölge payı küçük,
asıl maliyet savaş sisi (--nofog 8,3 → 4,6 ms; bulut alanı, dokunulmadı).
Yapılan: kamera 480'den uzaktayken güneş gölgesi ve SSAO kapanır, 440'ın
altında geri açılır (histerezis; main.gd _update_far_fx). Bu uzaklıkta
gölgeler zaten piksel altı. Glow açık kalır (görünür etkisi var, payı küçük).
Web (Compatibility) yoluna dokunulmaz. --off=ssao/shadow ölçüm bayrakları
adaptif kipi kilitler.

### 6. Hareket / rota okları — uygulandı (2 Ekim)

_draw_arrows seçim varken her karede eğri + şerit + ImmediateMesh kuruyordu.
Yapılan: seçim, rotalar, başlangıç noktaları, zoom, savaş sayısı ve kontrol
sürümünden imza; değişmediyse geçen karenin örgüsü kalır. Duran seçimde
hiç kurulmaz, yürürken başlangıç kaydığı için yine her kare kurulur (rotanın
tamamı başlangıca bağlı: Catmull-Rom ve incelme). Seçimden ölen tümen ayıklama
artık yalnız Military._div_version değişince (her kare O(seçili × tümen) idi).
test_map_logic: değişmeyen seçimde örgü aynı kalır, savaş ilanında kırmızıya döner.

### 7. Panel malzemesi hazırlığı — bekliyor (bu turda yapılmadı)

Arayüz dosyaları başka bir oturumda değişiyordu; çakışmamak için ertelendi.
Sürekli harita FPS'ini değil panel açılışını etkiliyor.


UiTheme.skin / panel_material_style doku get_image-decompress, renk örnekleme
ve gradient hazırlığını tekrarlayabiliyor. Doku örnekleri ve stil şablonları
önbelleğe alınmalı, yalnız mutasyona uğrayan örnekler kopyalanmalı.
Bu daha çok panel açılışı/yenileme takılmasıdır, sürekli harita FPS'i değil.

### 8. Web piksel oranı ve birlik tamponları — bekliyor (bu turda yapılmadı)

Three.js web prototipi ana yol değil; Godot web yapısı ayrı. Ertelendi.


web/src/main.ts DPR üst sınırı 2: DPR 1'e göre dört kat piksel.
web/src/units.ts değişmeyen renkleri her karede oluşturup instance color
tamponunu kirletiyor. Adaptif çözünürlük, renk önbelleği ve yalnız değişen
tamponların yüklenmesi aday. Fog maskesi zaten yalnız kirliyken yenileniyor.

### 9. Simülasyon kare sıçramaları — uygulandı (1–2 Ekim)

GameClock'un 8 ms bütçesi katı tavan değildi: bir saatlik tick bölünemiyordu;
Military._skirmish ayrıca bu bütçenin dışında çalışıyordu. East 1941/SOV,
mesafe 600, hız 5: gece yarısı kareleri 70–150 ms.

Yapılanlar:
- Günlük işler gün dönümünde değil kendi saatinde (GameClock.DAY_STAGE):
  ekonomi 2, araştırma 4, siyaset 6, diplomasi 8, hava 10, deniz 12;
  askeriye: ikmal 14–15, ordular 16, takviye 18, hava/deniz gücü 20.
- Saat iki yarıya bölündü: hour_passed (hareket, muharebe, saatlik ekonomi)
  ve hour_late (AI kararları, günün aşamalı işleri, sonra day/month_passed).
  Oyunda saat birikmiyorsa karede tek yarım saat işlenir (hız 5'te saat
  başına ~8 kare var); geride kalınca bütçeli toplu işleme. Testler ve
  advance_hours iki yarıyı art arda işler, sıra her zaman aynı.
  Duraklatma ve kayıt yarım kalan saati bitirir (GameClock.flush_hour).
- Yan yana ateş (skirmish) saat işi yapılan karede değil, sonraki boş karede
  (GameClock ağaçta Military'den önce işlendiği için eskiden aynı kareye
  biniyordu). Saatler hiç boşluk bırakmazsa iki saat birikince işlenir.
- Country.mod önbelleği (ruhlar/danışmanlar/yasalar/teknoloji imzası).
- Yan yana ateş taramasında cephe ön elemesi (World.control_version'a bağlı
  sınır önbelleği).
- Hava bonusu görev bölgelerine göre gruplandı: önbellek silinince cephedeki
  her (bölge, ülke) için bütün kanatları ölçmek yerine bölgeyi kaplayan
  görev bölgeleri bir kez bulunur (10:00 karesinde ~10 ms → ~4 ms).
- Ticaret: her alıcıda bütün ülkeleri süzüp sıralamak yerine kaynağa göre
  arz edenler listesi ve her adımda en büyüğü (aynı sıra; eşitlikte seçim
  farklı olabilir): 13–18 ms → ~5 ms.
- İkmal ağı oyunda dört dilimde (iki gün × iki saat, ülke indeksine göre):
  her ülke yine iki günde bir yenilenir; tek karede ~15 ms → ~4 ms.

Sonuç (East 1941/SOV, hız 5, 15 sn, M1 Max, vsync 120 Hz):

| Koşu | Önce p95 / p99 / en kötü | Sonra p95 / p99 / en kötü |
| --- | --- | --- |
| Savaş, mesafe 600 | 27,0 / 43,9 / 103,7 ms | 19,6 / 27,8 / 46,2 ms |
| Seçili cephe (150 tümen) | 31,0 / 59,1 / 149,9 ms | 16,9 / 26,4 ms |
| Fare haritada (hover) | 16,9 / 26,0 / 104,1 ms | 10,2 / 13,9 ms |
| Uzak (4200, duraklatılmış) | 15,0 / 19,7 ms, p50 11,5 | 14,1 / 22,1 ms, p50 7,2 |

40 ms üstü kare sayısı savaş koşusunda 11 → 2 (ikisi de simülasyon değil).
Kalan en büyük sabit kalem birlik sayaçlarının izlenmesi (~1 ms/kare).

Ölçüm notu: bazı koşularda ~1,01–1,03 sn'lik tek kare görülüyor; profil
anahtarı yok, oyun duraklatılmışken de oluyor. Pencere örtülüyken Metal'in
çizim yüzeyi beklemesindeki 1 sn zaman aşımına benziyor (ölçüm ortamı);
tabloda en kötü kare bu koşularda yazılmadı. Vsync kapalı ölçüm bu makinede
pencere çizilmediği için kullanılamadı.

### 10. Birlik sayaçlarının yeniden gruplandırılması — ölçüldü, şimdilik yeterli

İlk savaş ölçümünde units_rebuild yaklaşık 17 ms, ur_vote 12 ms.
Yeniden kurulum aralığı oyun hızıyla uzadığından (5×'te ~1 sn) şimdiki savaş
koşusunda 15 saniyede toplam 0,09 sn (çağrı başına ~6 ms). Kirli bölge
yenilemesi bu turda yapılmadı; zoom koşusunda tek tük 9–11 ms'lik kare var.

## Ek talep: zoom-out sınırı — uygulandı

- Godot kamera üst sınırı min(haritaya sığan mesafe, 5200).
- Tekerlek, programatik focus ve pencere oranı değişimi aynı sınırı kullanır.
- Web MapControls üst sınırı 650 (= 5200 / 8).
- Yakınlaştırma sınırı, sürükleme, harita kaydırma ve mevcut sarmalama korundu.
  Yeni bir döndürme kontrolü eklenmedi; bu talep uzaklaşmayı sınırlamak içindi.

## Öncelikli olmayan / etkinliği farklı yollar

- Eski SHOW_MODELS=false yolları ile etkin UnitFigures aynı şey değil.
- Yol katmanı normal siyasi görünümde etkin değil.
- Yeni küçük UI dünya küresi kanıtlanmış darboğaz değil.
- --off=clouds mevcut benchmarkta hacimli savaş sisini izole etmez; ana döngü
  hava bulutu miktarını yeniden yazabilir. Bulut maliyetini bununla ölçmeyin.

## 2 Ekim turunun doğrulaması

- tests/run.gd: 209/209 geçti.
- tools/balance_parallel.sh 6: 12 kontrolün hepsi 6/6.

## Doğrulama

- tests/test_render_lod.gd: gerçek Forward+ renderer ile 3/3 geçti.
  Arazi üçgen bütçesi, kısmi parça kenarları, mesh paylaşımı, histerezis,
  ekran oranları, zoom/focus sınırı, LOD dizin geçerliliği ve batch önbelleği.
- tests/test_fog.gd: 3/3 geçti; gizli düşman, keşif ve yürüyerek keşif korundu.
- Mevcut test_plane_model_parts ve test_figure_split_and_yaw testleri de geçti:
  pervane ekseni, bayrak yüzeyleri, asker/tank ayrımı ve dönüşleri korundu.
- tools/test_cloud_coverage.gd: Forward+ ve Compatibility'de 600 / 4400 /
  160 / 55 yüksekliğinde geçti. Sıfır gürültü alanında bile bilinmeyen yer
  örtülü, keşfedilen yer açık. Uzak örnekleme dalı da kapsandı.
- tools/test_model_lod_render.gd: dünya boyutlu MultiMesh ile gerçek GPU
  çiziminde yakın/uzak gövde üçgeni **45.057 → 11.248**.
- Model yüzey denetimi: asker üst 46.843 → 5.856, kaide 5.292 → 590;
  tank üst 45.141 → 5.706, kaide 5.554 → 486; uçak pervane 3.245 → 462.
  Bunlar her modelin en düşük mevcut LOD'udur, her mesafede seçileceği iddiası değil.
- Gerçek haritada altı kamera önizlemesi oluşturuldu; eski 14000 uzaklık
  isteği artık 5200'e sınırlandı. art/previews/fog_volume/forward_plus/.
- Web TypeScript kontrolü ve Vite üretim build'i geçti; tarayıcıda bulut
  çizimi görüldü. Önceden mevcut 500 kB bundle uyarısı devam ediyor.
- Tam oyun açılışı ve 4200 mesafe kısa koşusu tamamlandı. Bu turdaki ilk
  kontrol Engine.get_frames_drawn için 0 bildirdi; sonraki koşu sırasında
  başka GPU testleri/web önizlemesi de vardı. Bu nedenle karşılaştırılabilir
  FPS kazancı yüzdesi raporlanmıyor. Azalan üçgen sayıları yukarıdaki izole
  çizim testiyle doğrulandı.
- Tam oyun/test kapanışında önceden de bulunan kaynak sızıntısı uyarıları var;
  bu tur onların temizliğini kapsamıyor.
- Editör taraması tamamlandı; web/public ve web/dist içindeki üç harita
  görseli için kopya UID uyarısı var. Web build çıktısı ile kaynak kopyalarının
  Godot tarafından birlikte taranması bu tur değiştirilmedi.

Tekrarlama:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/run.gd -- --file=test_render_lod
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run.gd -- --file=test_fog
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/test_model_lod_render.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/test_cloud_coverage.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility -s tools/test_cloud_coverage.gd
```
