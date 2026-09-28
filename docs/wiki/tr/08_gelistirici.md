[English](../08_developer.md) · **Türkçe**

# Geliştirici notları

## Testler
Hepsi ekransız çalışır ve sorun bulunca 1 ile çıkar. Pull request'lerde ve main'e push'ta GitHub Actions
(`.github/workflows/tests.yml`) `tools/run_tests.sh`'ı koşar; denge testi aynı iş akışında yalnız elle tetiklenir.

| Komut | Ne yapar |
|---|---|
| `GODOT=godot tools/run_tests.sh` | İçe aktarma + `tests/run.gd` + `country_check` (60 gün); adım adım ve toplam sonuç |
| `godot --headless --path . -s tests/run.gd [-- --file=test_data] [--filter=hatay]` | Test paketi: `tests/test_*.gd` içindeki her `test_*` fonksiyonu temiz bir oyunla koşar |
| `godot --headless --path . -s game/dev/country_check.gd -- --days=150` | 80 ülkenin her biriyle oyunu başlatır; oyuncu eylemlerinin oyunu etkilediğini ve oyuncu adına otomatik iş yapılmadığını ölçer |
| `godot --headless --path . -s game/dev/gov_check.gd -- --player=TUR` | 1936 etkin istikrar/iç cephe, tarihli olaylar, seçimler |
| `godot --headless --path . -s game/dev/war_check.gd -- --player=GER --target=DEN --army [--start=19390828 --save=x \| --load=x] [--observe] [--prof]` | Oyuncu savaşı: savaş ilanı, bütün tümenler tek orduda hedefin cephesinde (ya da hepsi `--goal=Şehir`'e), 5 günde bir rapor (alınan bölge, boşta/saldıran tümen, teslim, ms/gün); `--observe` yalnız yapay zekâyı izler; `--prof` sistem başına süreyi yazar |
| `tools/balance_parallel.sh 6` | 1936–1942 tarihî akış denge testi (12 kontrol; her biri en az 5/6, değilse çıkış 1) |
| `godot --headless --path . -s game/dev/playtest.gd` | Türkiye → Irak savaşı, emirler, teslim, kayıt/yükleme |

### Test yazmak
`tests/test_<konu>.gd` dosyası `extends "res://tests/test_case.gd"` ile başlar; `test_` ile başlayan her fonksiyon
bir testtir. Koşucu her testten önce `Game.new_game()` + `World.start_game(player_tag())` çağırır (varsayılan TUR;
dosyada `player_tag()` ezilerek değişir). Doğrulamalar: `check`, `eq`, `near`, `gt`, `ge`, `lt`, `none` (liste boş
olmalı), `fail`, `warn` (kırmızı yapmaz); yardımcılar: `days(n)`, `player()`, `country(tag)`, `read_json(yol)`.
Test sırasında basılan motor/betik hatası (`push_error`, SCRIPT ERROR) da testi kırmızı yapar.
Veri testleri (`tests/test_data.gd`) motorun tanıdığı etki ve koşul anahtarlarını `politics.gd`'den okur; yeni etki
eklenince `apply_effects` ve `describe_effects`'e eklenmediyse test kırmızı olur.

| Dosya | Kapsam |
|---|---|
| `test_data.gd` | Veri başvuruları, etki sözlüğü, çeviri tablosu |
| `test_economy.gd` | İnşaat, bina yuvası, kamu inşaat tabanı, üretim verimliliği, kaynak açığı, tüketim malı |
| `test_trade.gd` | Elle anlaşma, ödeme sınırı, düşmanla ticaret yok (oyuncu ve AI), otomatik ticaret, konvoy |
| `test_politics.gd` | İstikrar/iç cephe formülleri, yasa şartları, danışman, karar, süreli ulusal durum, seçim, tarihli olay, kilitli seçenek |
| `test_diplomacy.gd` | Gerekçe, kriz endeksi eşikleri, savaşa katılım, teslim ilerlemesi ve sınırı, eyalet devri, beyaz barış |
| `test_history.gd` | Tarih çizelgesi: yapay zekâ tarihî adımları atar, oyuncunun ülkesi atmaz, koşulu tutmayan adım atlanır, serbest tarihten önce kendi savaşı ve saldırı çağrısına katılım yok |
| `test_land_combat.gd` | Muharebe çarpanları ve hasarı, siper, son askere kadar, geri çekilme, kuşatma, ikmal, ordu → cephe |
| `test_commanders.gd` | Komutan kadroları, atama/terfi/yeni general bedelleri, muharebe katkısı, tecrübe, oyuncuya kendiliğinden atama yok, doğrudan emir |
| `test_navy_air.gd` | Filo görevi/dönüşü, deniz muharebesi, konvoy baskını, kanatlar, hava üstünlüğü |
| `test_military.gd` | Eğitim süresi (askerlik yasası); tahmini varış gerçek yürüyüşle uyuşur |
| `test_save_load.gd` | 200 gün → kaydet → yükle: tüm alanlar aynı (fark eden alan adıyla yazılır) |
| `test_determinism.gd` | Aynı tohumla iki koşu aynı dünya |
| `test_sea_lanes.gd` | Deniz yolları yalnız denizden geçer; her liman–deniz / deniz–deniz komşuluğunun rotası ve rıhtımı var |
| `test_fleet_motion.gd` | Filo görsel konumu (köşe kavisleri, limandan çıkış, seyir) denizde; FleetLayer düzeni karaya taşmaz |
| `test_map_logic.gd` | Tümen yolu sürekliliği, hareket okları, hava durumu, zoom kiplerinde sayaç/bayrak/gizli |
| `test_open_game.gd` | Bitiş tarihi yok; oyuncunun tarafı dışında ülke kalmayınca zafer, ülke yok olunca yenilgi, teslim olup toprağı kalan oyuncu sürer; iyileştirme seviyeleri (dal bitince açılır, maliyet artar, kazanç azalır, kayıtta kalır, yapay zekâ da araştırır, yeni oyunda sıfırlanır) |
| `test_world_events.gd` | Dünya olayları kaydı (savaş, program, seçim), haber akışında yalnız oyuncunun işleri ve büyük güçlerin savaşları, yabancı savaş ve ilhaklara cevap (bedel, şart, etki, tek cevap, süre), demokrasilerin oyuncunun saldırısını kınaması, menü süzgeçleri |
| `test_map_pins.gd` | Yapı rozetleri (orta uzaklıkta ikon, yakında iğne), fare altındaki rozetin seçimi, büyümesi, yapı kartı, yapı seslerinin tanımı, ordu sayacında komutan portresi, muharebe durum okları, soluk yol önizlemesi |

Harita görüntüsü gereken testler `tests/map_probe.gd` ile bölge görüntüsünü (`data/map/provinces.png`) bir kez yükler;
katman testleri ağır dokuları yüklemeyen `ProbeMap` (MapView3D alt sınıfı) kullanır. Deniz yolları değişirse
`python3 tools/build_sea_lanes.py` (~1 dk, `pip install pillow numpy scipy`) ağı yeniden üretir ve kara temasını onarır.

Kayıttan devam eden oyun `World.resume_game(tag)` ile başlar (oyuncunun kayıttaki tercihleri korunur);
`World.start_game(tag)` yalnız yeni oyunda oyuncu varsayılanlarını kurar. Yeni bir ülke/tümen alanı eklerken kayda da ekle:
`test_save_load.gd` kaydedilmeyen alanı adıyla yakalar (her gün yeniden hesaplanan alanlar `tests/snapshot.gd` DERIVED listesinde).

## Geliştirici argümanları (`godot --path . -- ...`)
`--play=TAG`, `--panel=politics|focus|research|diplomacy|trade|construction|production|army|navy|air|logistics`,
`--target=TAG` (diplomasi), `--event=id[,FROM]`, `--select=PID`, `--days=N`, `--dist=N` (kamera), `--demo_order`,
`--demo_fleet`, `--weather=rain|snow`, `--war=A,B`, `--screenshot=dosya.png --wait=N`, `--click=x,y`,
`--pause_menu`, `--settings` (oyun içi ayarlar), `--menu_settings` (ana menü ayarları), `--lang_test=en|tr`,
`--gameover=win|lose`, `--politics_of=TAG` (başka ülkenin siyaseti), `--ctrl_hover=x,y` (ülke kartı),
`--hover_at=x,y` (ekran konumundaki bölge kartı), `--army=TAG [--army_select --army_cmd]` (bütün tümenler TAG'e karşı tek
ordu), `--army_demo=TAG [--army_sel=a:1|g:1] [--sel_demo]` (örnek komuta zinciri / karışık seçim),
`--split_demo=UZAKLIK` (aynı bölgede başka sayacın yanında komutanlı yeni ordu), `--hover_building` (ekranın ortasına en
yakın yapı rozetinin üstüne gel).
Web renderer'ını masaüstünde denemek için: `godot --path . --rendering-method gl_compatibility -- ...`

## 3B varlıklar (Blender, ekransız)
Harita iğne tasarımını kullanır (`game/map/pin_layer.gd`); şehir, sanayi ve tümen modelleri kapalıdır
(`city_layer_3d.gd`, `industry_layer.gd`, `unit_models.gd` içinde `SHOW_MODELS`), yalnız tek küçük uçak modeli çizilir
(`AirLayer.SINGLE_MODEL`). Aşağıdaki model hattı ileride kullanılmak üzere duruyor.
```
python3 tools/blender/make_textures.py && python3 tools/blender/make_industry_textures.py   # döşenebilir dokular
Blender --background --factory-startup --python tools/blender/build_cities.py   -- [--render KLASÖR] [--only city_west_capital]
Blender --background --factory-startup --python tools/blender/build_industry.py -- [--render KLASÖR] [--only ind_dockyard]
```
- **Şehirler** (`city_<stil>_<boyut>.gltf`): `build_buildings.py`'nin ayrıntılı bina kitinden (denizlikler, kornişler,
  balkonlar, dükkân vitrinleri) kurulur: ortada meydan ve simge yapı, avlulu bloklar, dışta bahçeli evler. Zemin
  malzemeleri oyunda kenardan dağılır (`conform.gdshader`, `fade_edge`); şehir araziye kaynaşır.
- **Sanayi** (`industry.gltf`): her inşaat türü için bir model ve şantiye. Hareketli parçalar (vinç kolları, uçaksavar
  topları, rafineri meşalesi) orijini pivotta ayrı mesh'lerdir; `building_part.gdshader` onları GPU'da oynatır (osc / spin
  / flicker), binlerce tesis ucuz kalır. Rig'li sürüm (kemikler + döngülü eylemler) `tools/blender/scenes/industry_rigged.glb`
  ve `industry_library.blend` içinde.
- Şehirler ve sanayi glTF + `.bin` olarak dışa aktarılır ve `assets/models/textures/` klasörünü paylaşır: bir doku modele
  göre çoğalmaz, bir kez paketlenir. Haritada: `game/map/industry_layer.gd` (parseller, seviye başına sayı, şantiyeler),
  `game/map/city_layer_3d.gd` (şehirler).

## Yeni ikon seti ve lider portreleri
- Prompt listesi: `docs/art/ICON_PROMPTS.md` (`python3 tools/make_icon_prompts.py` ile yeniden üretilir).
- İkonlar `assets/ui/icons_new/<ad>.png` → oyun eski ikonun yerine otomatik kullanır. İkon ekledikten sonra
  `python3 tools/make_icon_trims.py` çalıştırın: her ikonun içerik kutusunu `assets/ui/icon_trims.json`'a yazar; arayüz
  saydam kenar boşluğunu kırpar ve ikon yuvasını doldurur (`UiTheme.trimmed`).
- Arayüz yazı boyları `UiTheme.fs()` üzerinden geçer (küçük boylar en az 16 olur): 1920×1080 tasarım pencereye ya da
  tarayıcıya küçülünce de yazılar okunur kalır.
- Portreler `assets/portraits/<TAG>.png` (1936 lideri) ve `assets/portraits/<ad_soyad>.png` (olaylarla gelen lider,
  ör. `ismet_inonu.png`) → üst çubukta bayrak yerine, Hükümet ve Diplomasi ekranlarında görünür; yoksa bayrak.

## Veri
İçerik `data/common/*.json` (ülkeler, yasalar, ulusal durumlar ve danışmanlar `spirits.json`, olaylar, devlet programları `focuses.json`, teknolojiler, birimler, binalar, ekipman, komutanlar `commanders.json`, yapay zekânın izlediği tarih çizelgesi `history.json`: tarih,
adımı atan ülke, tamamlanacak odak ya da etkiler, koşullar).
Olay seçeneğine `"require": [koşullar]` eklenirse şart sağlanmadıkça seçenek kilitli görünür; yapay zekâ da seçmez.

## Dil
Oyunun ana dili İngilizcedir; bütün metinler `game/localization/strings.csv` içinde İngilizce ve Türkçe. Kayıtlı ayar yoksa
oyun İngilizce açılır (`GameSettings.DEFAULT_LANG`); Ayarlar → Dil değiştirir ve hatırlar. Belgeler de aynı kuralla:
asıl dosya İngilizce, Türkçesi yanında (`*.tr.md`, `docs/wiki/tr/`).
