# Geliştirici notları

## Testler
| Komut | Ne yapar |
|---|---|
| `godot --headless --path . -s game/dev/country_check.gd -- --days=150` | 80 ülkenin her biriyle oyunu başlatır; oyuncu eylemlerinin oyunu etkilediğini ve oyuncu adına otomatik iş yapılmadığını ölçer |
| `godot --headless --path . -s game/dev/gov_check.gd -- --player=TUR` | 1936 etkin istikrar/savaş desteği, tarihli olaylar, seçimler |
| `tools/balance_parallel.sh 6` | 1936–1942 tarihî akış denge testi (12 kontrol) |
| `godot --headless --path . -s game/dev/playtest.gd` | Türkiye → Irak savaşı, emirler, teslim, kayıt/yükleme |

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
İçerik `data/common/*.json` (ülkeler, yasalar, ruhlar, olaylar, odaklar, teknolojiler, birimler, binalar, ekipman).
Olay seçeneğine `"require": [koşullar]` eklenirse şart sağlanmadıkça seçenek kilitli görünür; yapay zekâ da seçmez.
