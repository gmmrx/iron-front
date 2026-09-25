# Iron Front (çalışma adı)

Godot 4.7 ile 2. Dünya Savaşı büyük strateji türünün en iyileri ölçeğinde büyük strateji oyunu. **Tarayıcıda oyna:** https://gmmrx.github.io/iron-front/ (masaüstü Chrome/Firefox, ~370 MB indirir; her push'ta GitHub Actions ile yeniden yayınlanır)

Yol haritası: [ROADMAP.md](ROADMAP.md) · Tanıtım videosu: [docs/media/iron_front_demo_2026-09-25.mp4](docs/media/iron_front_demo_2026-09-25.mp4) (klipler: `docs/media/clips/`)

## Çalıştırma
Godot 4.7 ile projeyi açın ve F5'e basın. Ya da:
```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Kontroller
| Tuş / fare | İşlev |
|---|---|
| WASD / ok tuşları / ekran kenarı, orta tık sürükle, trackpad kaydırma | Kamera |
| Tekerlek / pinch | Yakınlaştır |
| Sol tık | Eyalet/bölge ya da tümen sayacı seç (Shift: ekle) |
| Sol sürükle | Kutu ile tümen seç |
| Sağ tık | Seçili tümenlere hareket / saldırı emri (seçim yoksa: seçimi kaldır) |
| Boşluk · 1–5 · + / - | Duraklat · oyun hızı |
| Q / F / I / O / R / T / Y / U | Siyaset / Odak ağacı / Araştırma / Diplomasi / Ticaret / İnşaat / Üretim / Ordu |
| F1 F2 F3 | Siyasi / Arazi / Eyalet haritası |
| Home | Başkente dön |
| Esc | Seçimi kaldır → panelleri kapat → menü (kaydet/yükle/ayarlar) |
| F5 | Hızlı kayıt |

## Nasıl oynanır (kısa)
1. Ülkeni seç → **Odak (F)** ağacından bir odak, **Araştırma (I)**'dan teknolojiler seç.
2. **İnşaat (T)**: fabrika kur. **Üretim (Y)**: askeri fabrikaları ekipmana ata. **Ordu (U)**: tümen konuşlandır.
3. Bir ülkeye tıkla → **Diplomasi**: savaş gerekçesi hazırla (30 gün), savaş ilan et.
4. Tümenleri seç (tıkla / sürükle), sağ tıkla düşman bölgesine gönder. Zafer puanlı şehirleri al; düşman teslim olunca işgal ettiğin eyaletler senin olur.
5. Oyun 1 Ocak 1948'de biter (ya da teslim olursan).

## Test / geliştirici
```
Godot --headless --path . -s game/dev/sim.gd -- --days=1500            # AI dünyası, tarihî akış + profil
Godot --headless --path . -s game/dev/playtest.gd                      # oyuncu akışı + kaydet/yükle testi
Godot --path . -- --play=TUR --days=400 --panel=army --screenshot=o.png
```

## Haritayı yeniden üretme
```
pip install numpy scipy pillow
python3 tools/fetch_data.py     # verileri tools/cache/ içine indirir (bir kez)
python3 tools/generate_map.py   # ~80 sn
```
Kaynak veriler (`tools/cache/`, git'te yok):
- `ne_10m_admin_1.geojson` — github.com/nvkelso/natural-earth-vector (geojson/ne_10m_admin_1_states_provinces.geojson)
- `HYP_50M_SR_W.tif`, `SR_50M.tif` — naciscdn.org/naturalearth/50m/raster/

1936 sınırları `tools/generate_map.py` içindeki `ADM0_OWNER` ve `REGION_OWNER` tablolarıyla tanımlanır.

## Geliştirici argümanları
```
Godot --path . -- --play=TUR --screenshot=out.png --focus=1800,1800 --dist=600 --select=1500 --mode=1 --run
Godot --path . -- --setup          # doğrudan ülke seçimi
# video (Godot film yazıcısı; pencere en üstte olmalı, yoksa örtülü kareler çizilmez):
Godot --path . --always-on-top --write-movie out.avi --fixed-fps 30 -- --play=DEN --war=GER,DEN --focus_battle=200 --speed=1 --film=4.5 --dolly=230,105
#   --film=sn  [--dolly=uzak,yakın] [--pan=dx,dz] [--track] [--hide_ui]; sahneler: --focus_air, --focus_fleet=sea --track, --army=POL --army_mode=attack, --panel=focus
```

## Assetler (Blender)
```
python3 tools/blender/make_textures.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_assets.py -- --render /tmp/renders
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_buildings.py -- --render /tmp/buildings --save-blend tools/blender/scenes/city_asset_library.blend
```
