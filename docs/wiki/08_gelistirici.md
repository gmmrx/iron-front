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
| `test_land_combat.gd` | Muharebe çarpanları ve hasarı, siper, son askere kadar, geri çekilme, kuşatma, ikmal, ordu → cephe |
| `test_navy_air.gd` | Filo görevi/dönüşü, deniz muharebesi, konvoy baskını, kanatlar, hava üstünlüğü |
| `test_military.gd` | Eğitim süresi (askerlik yasası) |
| `test_save_load.gd` | 200 gün → kaydet → yükle: tüm alanlar aynı (fark eden alan adıyla yazılır) |
| `test_determinism.gd` | Aynı tohumla iki koşu aynı dünya |
| `test_sea_lanes.gd` | Deniz yolları yalnız denizden geçer; her liman–deniz / deniz–deniz komşuluğunun rotası ve rıhtımı var |
| `test_fleet_motion.gd` | Filo görsel konumu (köşe kavisleri, limandan çıkış, seyir) denizde; FleetLayer düzeni karaya taşmaz |
| `test_map_logic.gd` | Tümen yolu sürekliliği, hareket okları, hava durumu, zoom kiplerinde sayaç/bayrak/gizli |

Harita görüntüsü gereken testler `tests/map_probe.gd` ile bölge görüntüsünü (`data/map/provinces.png`) bir kez yükler;
katman testleri ağır dokuları yüklemeyen `ProbeMap` (MapView3D alt sınıfı) kullanır. Deniz yolları değişirse
`python3 tools/build_sea_lanes.py` (~1 dk, `pip install pillow numpy scipy`) ağı yeniden üretir ve kara temasını onarır.

Kayıttan devam eden oyun `World.resume_game(tag)` ile başlar (oyuncunun kayıttaki tercihleri korunur);
`World.start_game(tag)` yalnız yeni oyunda oyuncu varsayılanlarını kurar. Yeni bir ülke/tümen alanı eklerken kayda da ekle:
`test_save_load.gd` kaydedilmeyen alanı adıyla yakalar (her gün yeniden hesaplanan alanlar `tests/snapshot.gd` DERIVED listesinde).

## Geliştirici argümanları (`godot --path . -- ...`)
`--play=TAG`, `--panel=politics|focus|research|diplomacy|trade|construction|production|army|navy|air|logistics`,
`--target=TAG` (diplomasi), `--event=id[,FROM]`, `--select=PID`, `--days=N`, `--dist=N` (kamera), `--demo_order`,
`--demo_fleet`, `--weather=rain|snow`, `--war=A,B`, `--screenshot=dosya.png --wait=N`, `--click=x,y`.
Web renderer'ını masaüstünde denemek için: `godot --path . --rendering-method gl_compatibility -- ...`

## Yeni ikon seti ve lider portreleri
- Prompt listesi: `docs/art/ICON_PROMPTS.md` (`python3 tools/make_icon_prompts.py` ile yeniden üretilir).
- İkonlar `assets/ui/icons_new/<ad>.png` → oyun eski ikonun yerine otomatik kullanır.
- Portreler `assets/portraits/<TAG>.png` (1936 lideri) ve `assets/portraits/<ad_soyad>.png` (olaylarla gelen lider,
  ör. `ismet_inonu.png`) → üst çubukta bayrak yerine, Hükümet ve Diplomasi ekranlarında görünür; yoksa bayrak.

## Veri
İçerik `data/common/*.json` (ülkeler, yasalar, ulusal durumlar ve danışmanlar `spirits.json`, olaylar, devlet programları `focuses.json`, teknolojiler, birimler, binalar, ekipman).
Olay seçeneğine `"require": [koşullar]` eklenirse şart sağlanmadıkça seçenek kilitli görünür; yapay zekâ da seçmez.
