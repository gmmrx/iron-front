# Zombi modu — 14 Teknik plan: mod altyapısı üzerinde uygulama

> **Özet.** Bu belge 01–13'teki tasarımı **bu depoda kurulan oyun modu altyapısına** (`GameModes`, `ModeRules`, `data/modes/<id>/`,
> yama birleştirme, `own/` klasörü, kayıt sürümü 2) bağlar: hangi dosya nereye yazılır, hangi motor kancası gerekir, kod nasıl
> bölünür, kayıt ve belirlenimcilik nasıl korunur, testler nerede durur.
> - **Dosya yerleşimi kesinleşti:** manifest `data/modes/zombie/mode.json`; temel veride karşılığı olanlar `common/*.patch.json`;
>   karşılığı olmayanlar (salgın, türler, bilim, doktrin, yapay zekâ, ses, varlık listeleri…) **`own/*.json`**; kod
>   `game/modes/zombie/`. Öteki belgelerdeki `data/modes/zombie/<ad>.json` yolları `own/<ad>.json` olarak düzeltildi.
> - **Motor kancaları:** 02–13'te önerilen 58 kanca birleştirilince **48 tekil kanca** kalıyor (H01–H48). **8'i zorunlu** (A kademesi):
>   bunlar olmadan mod oynanamaz. 26'sı önemli (B), 13'ü cila (C), 1'i görsel (G, insan onayı). Hepsi içerikten bağımsızdır, WWII'de
>   etkisizdir; her birinin yedek planı kaynak belgede yazılıdır.
> - **Bulgu:** `ModeRules.on_day` bugün yapay zekâdan **sonra** çalışıyor (sinyal bağlanma sırası: Politics → … → AI → Game).
>   Salgın adımının ekonomiden ve yapay zekâdan önce koşması gerekir (03 §2, 10 §2) → yeni zorunlu kanca **H01 `on_day_begin`**.
> - **Kod:** `rules.gd` yalnız yönetir; dokuz alt sistem ayrı sınıftır (salgın, sürü YZ, devlet YZ, bilim, ekonomi, askerî, siyaset,
>   arayüz, ses). Durum dizileri `PackedFloat64Array`; kayıtta base64 ikili (03 §11.4: JSON ondalığı kayıplı).
> - **WWII'nin birebir aynılığı** her kanca PR'ında bu depodaki yöntemle kanıtlanır: aynı tohumla 400 günlük anlık görüntü, main ile
>   karşılaştırma (mod altyapısı PR'ında 3.669 alanın hepsi aynı çıktı).
> - **Uygulama sırası:** 7 teknik aşama (§8); proje yol haritası, iş tahmini ve varlık sırası 16_yol_haritasi.md'dedir.

---

## 1. Mod altyapısı bugün ne sağlıyor? (kod okundu)

| Yetenek | Nerede | Zombi modu için kullanımı |
|---|---|---|
| Kayıt ve manifest | `data/modes/modes.json`, `data/modes/<id>/mode.json`, `game/core/game_modes.gd` | `zombie` kaydı, başlangıç/bitiş, varsayılan oyuncu, öne çıkanlar, büyük güçler, başlangıç teknolojileri, AI takvimi (hepsi kapalı) |
| Veri katmanı: tam dosya / yama | `GameModes.load_json`, `merge` (`null` siler, `id`li dizide `_delete`, sıra korunur) | Olaylar, programlar, teknolojiler, yasalar, binalar, ekipman, birimler, ülkeler |
| Modun kendi verisi | `data/modes/<id>/own/*.json`, `GameModes.load_own(name)` | Salgın parametreleri, türler, suşlar, bilim, doktrin, ekonomi, askerî, siyaset, YZ, ses, varlık listeleri |
| Başlangıç katmanı | `scenario.json` (`owners`, `capitals`, `vp`) | Gerekmez (1936 sınırları aynen); ileride "kıta senaryoları" için |
| Kural betiği | `game/core/mode_rules.gd` → `game/modes/zombie/rules.gd` | Kancalar: `on_new_game`, `on_game_started`, `on_day`, `on_hour`, `on_month`, `check_end`, `score`, `to_save`/`from_save`, `effect_keys`/`apply_effect`/`describe_effect`, `condition_keys`/`check_condition` |
| Mod değiştirme | `Game.switch_mode(id)`: veri yeniden yüklenir, önbellekler temizlenir, kural kurulur, yeni oyun | Menüde "Zombi İstilası" seçimi |
| Kayıt sürümü 2 | `game.gd`: `mode`, `mode_state` (kural betiğinin `to_save` çıktısı); kayıt kendi modunu kurar; bozuk/bilinmeyen modlu kayıt durum değiştirmeden reddedilir | Salgın durumu `mode_state`'e yazılır (§5) |
| Açılış | `--game_mode=zombie`; `GameClock._ready` başlangıç tarihini moddan kurar | Geliştirme ve test |
| Testler | `tests/test_modes.gd` (her modun sözleşmesi), `tests/test_mode_<id>.gd` (`test_data` denetimlerini modun verisiyle koşar), `country_check --game_mode=<id>`, `tools/run_tests.sh` (her modu koşar) | §7 |
| Araç | `tools/new_mode.py` (iskelet, `--check`, `--copy`, `--blank`, `--remove`) | `python3 tools/new_mode.py zombie --name-en "Zombie Outbreak" --name-tr "Zombi İstilası"` |
| Belirlenimcilik kanıtı | Tohumlu anlık görüntü karşılaştırması (`tests/snapshot.gd`) | Her kanca PR'ında WWII birebir aynı |

**Altyapının sınırları** (docs/modlar/README.md "Bilinen sınırlar"): harita ortak; moda özel panel ve harita modu yok; motor
dosyaları mod için değiştirilmez (gerekirse insan onayıyla, içerikten bağımsız kanca olarak). Bu belgedeki kancalar bu sınırları
genişletmek içindir.

---

## 2. Dosya yerleşimi (kesin)

### 2.1 Veri

```
data/modes/modes.json                          "modes": ["ww2", "_template", "zombie"]
data/modes/zombie/
  mode.json                                    manifest (§2.2)
  common/
    events.patch.json                          WWII olayları null (--blank) + zm olayları (02 §3.4, 04 §9, 05 §10, 08 §13, 09 §7)
    focuses.patch.json                         WWII ağaçları null (--blank) + Kriz Doktrini ağacı (06 §4); _generic kalır
    technologies.patch.json                    13 temel teknoloji _delete + 50 yeni (05 §3, 06 §3)
    laws.patch.json                            5 yeni grup (09 §3) + Gıda Politikası (07 §3.7)
    spirits.patch.json                         kademe durumları, kabine uzmanları (06 §4.9), doktrin durumları
    buildings.patch.json                       8 bilim binası (05 §4), Kordon Hattı (08 §5.2), kamp; "resources" 7 öğe (gıda eklenir)
    equipment.patch.json                       serum, aşı, tıbbi malzeme, mühimmat, alev, taşıyıcı, köpek, aydınlatma
    units.patch.json                           8 tabur/bölük (08 §3), şablonlar (tam dizi: id'siz dizi yamada tamamen değişir)
    countries.patch.json                       UND (Boşlar) + uyuyan ülke havuzu (09 §5.2, S5)
  own/
    rules.json          02 §10   evreler, zafer/yenilgi, zorluk tabloları, puan
    epidemic.json       03 §14   bölmeler, iklim, yayılma, gözetim, sürü doğumu, adım ayarları
    hollow_types.json   04 §12   9 tablo (T01–T09)
    strains.json        04 §12   5 suş (T10–T14), evrim ağacı, keşif
    science.json        05 §12.3 bina şartları, kadro, numune, kaza, serum/aşı dağıtımı, işbirliği
    doctrine.json       06 §6    doktrin puanı kazanımları, karargâh emirleri, ağaç yerleşimi
    economy.json        07 §14   işgücü kademeleri, gıda, karaborsa, kamplar, taşıma
    military.json       08 §16   kordon, tahkimat, mühimmat, ordu içi bulaş, moral
    politics.json       09 §10.3 kriz terimleri, tutumlar, çöküş makinesi, diplomasi değerleri, Konsey, olay dağıtıcısı
    ai.json             10 §12   sürü YZ, devlet YZ eşikleri, zorluk
    audio.json          13 §9    efekt kaydı, müzik tablosu, ambiyans
    assets.json         12 §9    harita/uyarı/zorluk/efekt varlıklarının üretim komutları (yalnız araç okur)
```

`own/` dosyaları mod altyapısının doğrulamasından geçer (JSON geçerli, yalnız `.json`), ama "temel veride karşılığı var mı" denetimi
yapılmaz. 02 §10 (`rules.json`) ve 03 §14 (`epidemic.json`) aynı anahtarları (`disease`, `mobility`, `horde`) önermişti: **kesin karar**
— salgın parametreleri yalnız `epidemic.json`'da, zorluk çarpanları `rules.json` → `difficulty`'de; `epidemic.gd` önce epidemic.json'u,
sonra seçili zorluğun üstüne yazdığı anahtarları uygular.

### 2.2 Manifest (`mode.json`)

```json
{
 "id": "zombie",
 "hidden": true,
 "name": {"en": "Zombie Outbreak", "tr": "Zombi İstilası"},
 "description": {"en": "1936: an unknown fever spreads from a harbour. Govern a nation through the outbreak.",
                 "tr": "1936: bilinmeyen bir ateş bir limandan yayılıyor. Bir ulusu salgının içinden geçir."},
 "subtitle": {"en": "1936 — 1940  ·  ZOMBIE OUTBREAK", "tr": "1936 — 1940  ·  ZOMBİ İSTİLASI"},
 "welcome": {"en": "Government of %s: the first reports are only rumours. Open the Outbreak panel (E).",
             "tr": "%s hükümeti: ilk haberler henüz söylenti. Salgın panelini aç (E)."},
 "end_text": {"en": "1 January 1940: your nation endured.", "tr": "1 Ocak 1940: ulusun ayakta kaldı."},
 "start_date": "1936-01-01",
 "end_date": "1940-01-01",
 "default_player": "TUR",
 "featured": ["TUR", "ENG", "FRA", "GER", "SOV", "USA", "POL", "ROM"],
 "playable": "all",
 "menu_focus": "TUR",
 "ai": {"rearm_year": 0, "cautious_until": "", "phoney_war_days": 0, "major_hold_fire_days": 0},
 "combat": {"phoney_war_days": 0},
 "rules": "res://game/modes/zombie/rules.gd"
}
```

- `hidden: true` mod oynanabilir olana dek kalır (menüde görünmez, CI yine test eder; `_template` gibi).
- Oyuncu yalnız 80 oynanabilir ülke; `UND` ve uyuyan ülkeler `playable` dışıdır (`World.is_playable` haritada eyaleti olmayanı zaten
  dışlar; `UND`'nin başta eyaleti yoktur).
- `majors` WWII değerinde kalır (araştırma yuvası ve yapay zekâ büyük güç dalları için); salgında "büyük güç" yalnız kapasite anlamındadır.

### 2.3 Kod

```
game/modes/zombie/
  rules.gd              ModeRules alt sınıfı: kancaları alt sistemlere dağıtır, to_save/from_save, check_end, score
  epidemic.gd           03: bölmeler, günlük adım, akışlar, gözetim, sürü doğumu, KSE, evre
  hash.gd               03 §11.2: durumsuz sayaç karması (statik)
  horde_ai.gd           10 §3: yerel puan, çekim alanı Φ, emir bütçesi
  state_ai.gd           10 §4: devlet YZ salgın katmanı (Y1/Y2 kancalarından çağrılır)
  science.gd            05: binalar, kadro, numune, kaza, serum/aşı dağıtımı
  economy_zm.gd         07: işgücü, gıda, karaborsa, kamp, taşıma
  military_zm.gd        08: kordon, mühimmat, ordu içi bulaş, moral, kent kuralı
  politics_zm.gd        09: kriz terimleri, tutumlar, çöküş, diplomasi, Konsey, olay dağıtıcısı
  effects.gd            yeni etki/şart anahtarları (apply/describe/check), rules.gd'den çağrılır (CLAUDE.md kural 2)
  ui/outbreak_panel.gd  11 §4: altı sekme (yalnız panel_layout yardımcıları)
  ui/setup_screen.gd    11 §9: zorluk ve özel ayarlar
tests/
  test_mode_zombie.gd   iskelet (tools/new_mode.py yazar): test_data denetimleri + duman testi
  test_zm_epidemic.gd · test_zm_types.gd · test_zm_science.gd · test_zm_doctrine.gd · test_zm_economy.gd
  test_zm_military.gd · test_zm_politics.gd · test_zm_ai.gd · test_zm_ui.gd
game/dev/zm_balance.gd  10 §8: oyuncusuz dünya, 1.461 gün, 14 kontrol
```

`.gd` dosyaları `data/` altında yüklenmez (klasör motor için gizli); bu yüzden kod `game/modes/zombie/` altındadır (mod rehberi kuralı).

---

## 3. Motor kancaları (birleşik liste)

### 3.1 Kademeler

| Kademe | Anlamı | Sayı |
|---|---|---|
| **A — zorunlu** | Yapılmazsa mod oynanamaz ya da temel bir kuralı bozulur | 8 |
| **B — önemli** | Yedek planı var ama tasarımın bir sütununu zayıflatır | 26 |
| **C — cila** | Okunabilirlik, yapay zekâ çeşitliliği, arayüz kolaylığı | 13 |
| **G — görsel** | Gölgelendirici/render değişikliği; insan gözüyle iki hedefte onay (CLAUDE.md kural 5) | 1 |

### 3.2 Liste

"Kaynak" sütunu, kancanın önerildiği belge ve orijinal kimliği. Birden çok belge aynı kancayı önerdiyse birleştirildi.

| # | Kanca | Yer | Kademe | Kaynak |
|---|---|---|---|---|
| H01 | `ModeRules.on_day_begin()`: `World._on_day_passed` içinde `daily_update.emit()`'ten **önce** | `world.gd` | **A** | Bu belge (§3.3) |
| H02 | Savaş kaydında `"kind": "outbreak"`; `at_war`, `any_war`, `war_state_support`, `_elections`, YZ savaş denetimleri saymaz; `are_enemies` ve teslim denetimi sayar | `diplomacy.gd`, `politics.gd`, `ai.gd` | **A** | 09 S1 = 08 K10 = 10 Y6 |
| H03 | `ModeRules.on_capitulate(c) -> bool` (`true` → motorun teslim işlemi çalışmaz) | `diplomacy.gd` | **A** | 09 S4 |
| H04 | `ModeRules.front_provinces(a)` ve `Army.cordon` (kayda girer) | `military.gd`, `army.gd`, `game.gd` | **A** | 08 K4 |
| H05 | `ModeRules.state_productive(st) -> bool` + `Economy.fit_lines(c)` | `economy.gd` | **A** | 07 M1, M1b |
| H06 | `ModeRules.panels()` (panel betiği, kısayol, ikon) | `hud.gd`, `main.gd` | **A** | 11 U2 |
| H07 | `ModeRules.on_hits(d, hits, loss, pid)` (ısırık payı, ordu içi bulaş) | `military.gd` (`_apply_hits` sonrası) | **A** | 04 `bite` = 08 K3 |
| H08 | `ModeRules.combat_mod(d, pid, attacker) -> float` (arazi tablosu, gece, engel, alev, mühimmat, önder etkisi) | `military.gd` (`attack_mod`, `defend_mod`) | **A** | 04 `und_attack_mod`, `aura` = 08 K2 |
| H09 | `ModeRules.terrain_of(pid) -> String` (kent kuralı) | `military.gd` | B | 08 K5 (B1 bulgusu) |
| H10 | `ModeRules.supply_sources(c) -> Array` (kuşatma) | `military.gd` (`_compute_supply`) | B | 08 K6 |
| H11 | `ModeRules.org_cap(d) -> float` (yorgunluk) | `military.gd` (`_recover`) | B | 08 K7 |
| H12 | `ModeRules.air_bonus(...) -> float` (`UND`'ye karşı hava üstünlüğü yok) | `air.gd` (`bonus`) | B | 08 K8 (B4) |
| H13 | `ModeRules.on_division_destroyed(d, cause)` | `military.gd` | B | 08 K9 |
| H14 | Tabur verisinde `extra` sözlüğü | `military.gd` (`stats`) | B | 08 K1 |
| H15 | `ModeRules.can_move(d) -> bool` (Kışlayan kışın yürümez) | `military.gd` (`_move_all`) | B | 04 `torpid` |
| H16 | `ModeRules.unit_visible(d, viewer) -> bool` (gizli türler) | `unit_layer.gd`, YZ tehdit hesabı | B | 04 `hidden_from` = 11 U4 |
| H17 | `ModeRules.extra_resource_need(c)` | `economy.gd` (`resource_need`) | B | 07 M2 |
| H18 | `ModeRules.export_cap(c, res, offered)` | `economy.gd` (`_run_trade`) | B | 07 M2b |
| H19 | `ModeRules.import_factor(c, from)` | `economy.gd`, `military.gd` (`_fuel`), ticaret paneli | B | 07 M3 |
| H20 | Bina şartları: `requires_tech`, `requires_building`, `min_population`, `category_min` | `economy.gd` (`can_build`) | B | 05 §1.3 |
| H21 | Program düğümünde `points` + `Country.doctrine_points` + `doctrine_points` etkisi + `focus_title` | `politics.gd`, `country.gd`, `game.gd`, `focus_panel.gd` | B | 06 M1 |
| H22 | Kararda `currency` (`pp` / `command_power`) ve `available` | `politics.gd`, `politics_panel.gd` | B | 06 M2 |
| H23 | Kategoriye özgü araştırma hızı `research_speed_<cat>` | `research.gd` | B | 06 M4 |
| H24 | Yasa `requires` bilinmeyen anahtarı → mod şartı | `economy.gd` (`law_block_reason`) | B | 09 S2 |
| H25 | Yasada `cost`, grupta `relax_cost` | `economy.gd`, `politics_panel.gd` | B | 09 S3 |
| H26 | Uyuyan ülkeler: `"dormant": true`, `World.activate_country`, `deactivate_country`, `Military.transfer_divisions` | `world.gd`, `military.gd`, `game.gd` | B | 09 S5 |
| H27 | Bekleyen olaya `args`; metin `String.format(args)` | `politics.gd`, `event_popup.gd` | B | 09 S7 |
| H28 | `ModeRules.ai_strategic(c)` | `ai.gd` (`_strategic` sonu) | B | 10 Y1 |
| H29 | `ModeRules.ai_military(c) -> bool` | `ai.gd` (`_military` başı) | B | 10 Y2 |
| H30 | Manifest `ai.laws = "rules"` → `_laws` atlanır | `ai.gd` | B | 10 Y4 |
| H31 | `ModeRules.can_declare(a, b) -> bool` | `ai.gd`, `diplomacy.gd` | B | 10 Y5 |
| H32 | `ModeRules.topbar_cells()` | `top_bar.gd` | B | 11 U1 |
| H33 | `ModeRules.alerts(c)` | `alert_bar.gd` (`_collect`) | B | 11 U3 |
| H34 | `ModeRules.setup_screen() -> Control` | `main.gd` (`_enter_setup` öncesi) | B | 11 U6 |
| H35 | `ModeRules.music_table()`, `music_state()`, `music_hold_days` | `audio.gd` | C | 13 A1 |
| H36 | `ModeRules.sounds()` | `audio.gd` | C | 13 A2 |
| H37 | `ModeRules.ambience(camera_pid, zoom)` | `audio.gd` | C | 13 A3 |
| H38 | `ModeRules.game_over_rows()` | `game_over.gd` | C | 11 U5 |
| H39 | `ModeRules.map_icons()` | `map_icon_layer.gd` | C | 11 U7 = 05 §1.3-2 |
| H40 | Danışmanda `available` | `politics.gd` | C | 06 M3 |
| H41 | Manifest `ai.research_priority` | `ai.gd` (`_research`) | C | 06 M5 = 10 Y3 |
| H42 | Program düğümünde `ai_mult` (olaylara da) | `ai.gd` (`_focus`), `politics.gd` | C | 06 M6, 10 §5 |
| H43 | Ulusal durumda `group` (Hükümet panelinde özet) | `politics_panel.gd` | C | 06 M7 |
| H44 | `ModeRules.describe_mod(key, v)`, `describe_condition(key, v)` | `politics.gd`, `mode_rules.gd` | C | 06 M8 |
| H45 | `ModeRules.diplomacy_actions(me, t)`, `do_diplomacy_action(id, me, t)` | `diplomacy_panel.gd` | C | 09 S6 |
| H46 | Şablon düzenleyicide `max_per_template` | `game/ui` şablon ekranı | C | 08 K11 |
| H47 | Bekleyen olayın gün sayacı ve isteğe bağlı `pending_cost` | `politics.gd`, `event_popup.gd` | C | 10 §14-7 (öneri) |
| H48 | `MapMode.OUTBREAK` + `epi_tex` (ısı haritası) | `map_view_3d.gd`, `map3d.gdshader`, `map_mode_bar.gd` | **G** | 03 §13.3 B, 11 §2.4 |

58 öneri (04: 6, 05: 2, 06: 8, 07: 5, 08: 11, 09: 7, 10: 6, 11: 7, 13: 3, 03 ısı haritası: 1, 10 §14-7: 1, bu belge: 1) şöyle 48'e iner:
04 `bite` = 08 K3; 04 `und_attack_mod` ve `aura` = 08 K2; 04 `hidden_from` = 11 U4; 08 K10 = 09 S1 = 10 Y6; 06 M5 = 10 Y3; 05 harita
ikonu = 11 U7; 07 M1 ve M1b tek kanca (H05); 04 `noise_pull` motor kancası değildir, sürü yapay zekâsının (mod kodu) içindedir (10 §3.2).

### 3.3 Neden H01 zorunlu?

`World.daily_update` sinyaline bağlanma sırası autoload sırasıyla aynıdır: Politics, Research, Economy, Diplomacy, Military, Navy,
Air, **AI**, **Game**. `Game._on_day` → `rules.on_day()` en sonda çalışır. Salgın adımı `on_day`'de koşarsa:

- Ekonomi o günün üretimini **dünkü** işgücüyle ve düşmüş eyaletlerle hesaplar (bir gün gecikme, 07'nin sayısal örneği kayar).
- Yapay zekâ dünkü bildirilen veriyle karar verir (kabul edilebilir) ama sürü doğumu ve cephe eyaletleri ertesi güne kalır; 10 §2'deki
  "sürü YZ salgından sonra, devlet YZ sürüden sonra" sırası bozulur.
- Oyun sonu denetimi aynı gün düşen başkenti görmez.

`on_day_begin` sinyal sırasına bağımlı olmadan bu sırayı garanti eder. Maliyeti 3 satırdır:
`if Game.rules: Game.rules.on_day_begin()` (`World._on_day_passed` içinde, `daily_update.emit()`'ten önce; `Game` autoload'una
World'den erişim zaten var). WWII'de `rules == null`, birebir aynı.

### 3.4 Kanca PR'larının kuralı

1. Her kanca **içerikten bağımsızdır**: kancada "zombie", "UND", "salgın" geçmez; genel ad ve genel anlam taşır.
2. Her kanca PR'ı WWII birebir aynılığını kanıtlar: aynı tohumla 400 günlük anlık görüntü main ile karşılaştırılır (mod altyapısı
   PR'ında kullanılan yöntem; yalnız yeni alan adları farklı olabilir).
3. Her kanca bir test getirir: `_template` moduna küçük bir örnek kullanım eklenir (ör. `on_day_begin` bir sayacı artırır) ve
   `test_mode_template.gd` bunu denetler. Böylece kanca, zombi modu yazılmadan önce CI'da yaşar.
4. Kancalar `docs/modlar/README.md`'deki kanca tablosuna ve `game/core/mode_rules.gd` belgelemesine eklenir (vibecoder'lar için).
5. Gruplar hâlinde PR (öneri): **PR-K1** A kademesi (H01–H08), **PR-K2** ekonomi+siyaset B (H17–H27), **PR-K3** askerî+YZ B (H09–H16,
   H28–H31), **PR-K4** arayüz ve ses (H32–H39), **PR-K5** C cilası, **PR-G** ısı haritası (insan onayı).

---

## 4. Mimari

### 4.1 `rules.gd`: yönetici

```gdscript
extends ModeRules
## Zombi modu: kancaları alt sistemlere dağıtır. Sayılar own/*.json'dan (CLAUDE.md kural 2).

var epi: Epidemic          # epidemic.gd
var horde: HordeAI         # horde_ai.gd
var state_ai: StateAI      # state_ai.gd
var sci: Science
var eco: EconomyZM
var mil: MilitaryZM
var pol: PoliticsZM
var cfg := {}              # own/*.json birleşik

func on_new_game() -> void:
	cfg = _load_cfg()                      # GameModes.load_own(...) × 12
	epi = Epidemic.new(cfg); horde = HordeAI.new(cfg, epi); ...

func on_day_begin() -> void:               # H01: ekonomiden ve YZ'den önce
	epi.step_day()                         # 03 §2 adım 1–7
	horde.plan_day()                       # 10 §3: Φ + emirler
	eco.apply_day(epi)                     # işgücü, gıda (H05 sonuçları)

func on_day() -> void:                     # YZ'den sonra
	sci.day(); pol.day(); mil.day()        # dağıtım, kriz terimleri, bulaş seyri

func check_end() -> Dictionary:
	return pol.check_end(epi)              # 02 §4

func to_save() -> Dictionary:
	return {"v": 1, "epi": epi.to_save(), "sci": sci.to_save(), ...}
```

Alt sistemler `RefCounted` sınıflardır (`class_name` kullanılmaz: mod kodu genel sınıf ad alanını kirletmesin; `preload` ile).

### 4.2 Durum dizileri

| Veri | Biçim | Boyut |
|---|---|---|
| Eyalet bölmeleri (S, E, F, H, R, V, Vb, D + N⁰) | 9 × `PackedFloat64Array(1652)` | 119 KB |
| Bildirilen veri halkası (14 gün) | `PackedFloat32Array(1652 × 14)` | 92 KB |
| Deniz varış halkası (295 liman × 32 gün × 3) | `PackedFloat32Array` | 113 KB |
| Sürü yardımcı alanları (ses, iz) | `PackedByteArray(9827)` × 2 | 20 KB |
| Yolcu ve yürüyüş bağlantıları | `PackedInt32Array` + `PackedFloat32Array` | ~120 KB (yüklemede kurulur, kayda girmez) |

Toplam < 1 MB (03 §12.4 ile uyumlu).

### 4.3 Motor nesnelerine alan eklemek mi, mod durumunda tutmak mı?

08 §2.3 ve 04 §2.5 iki yol önerdi. **Karar:** motor sınıflarına yalnız kancanın zorunlu kıldığı alanlar eklenir (`Army.cordon`, H04;
`Country.doctrine_points`, H21). Tümen başına mühimmat, bulaş, moral; eyalet başına kuşatma, suş payı gibi alanlar **mod durumunda**
(`div_id → {...}`, `state_id → {...}`) tutulur ve `to_save`'e yazılır. Gerekçe: WWII'nin kayıt biçimi ve `snapshot.gd` alan listesi
değişmez; mod silinirse motor temiz kalır. Yok edilen tümenin kaydı H13 ile silinir.

---

## 5. Kayıt

| Konu | Karar |
|---|---|
| Nerede | `mode_state` (kayıt sürümü 2; `rules.to_save()` çıktısı) |
| Büyük diziler | base64 ikili: `Marshalls.raw_to_base64(arr.to_byte_array())`. 03 §11.4'te ölçüldü: JSON ondalığı `float64`'ü kaybettiriyor; ikili yol birebir |
| Büyük tamsayılar | Metin (`str(x)`); mod altyapısının `ModeRules` notu |
| Sürüm | `mode_state.v`; eski mod kaydı açılırken eksik alan varsayılanla doldurulur |
| Boyut | ~0,5–0,7 MB base64 (bölmeler + halkalar); temel kayıt ~1–2 MB. Web'de `user://` IndexedDB'ye yazılır; sınır sorun değil |
| Test | `test_zm_save.gd`: 200 gün → kaydet → yükle → anlık görüntü + mod durumu aynı (mevcut `test_save_load.gd` kalıbı) |

---

## 6. Belirlenimcilik

| Kural | Uygulama |
|---|---|
| Salgın ve sürü YZ global üreteci kullanmaz | `hash.gd` (03 §11.2): `(tohum, gün, akış, a, b)` → [0,1) |
| Dünya tohumu | Yeni oyunda `randi()`'den (mevcut `seed()` testleri kapsar); kayda yazılır; özel ayarda elle girilebilir |
| Çift tampon | Eyalet adımı gün başı dizilerinden okur, ayrı diziye yazar; akışlar sabit bağlantı sırasıyla toplanır (03 §2) |
| Kayıt sonrası | Salgın ve sürüler kayıttan birebir devam eder; devlet YZ temel oyunla aynı sınırda (global üreteç kayda yazılmıyor, 10 §11) |
| Test | `test_zm_determinism.gd`: aynı tohum → 120 gün → aynı dünya (mevcut `test_determinism.gd` kalıbı, mod ile) |

---

## 7. Test planı (birleşik)

| Katman | Dosya | Kapsam | Kaynak |
|---|---|---|---|
| Mod sözleşmesi | `tests/test_modes.gd` (mevcut) | Manifest, dosyalar, motor olayları, `_generic`, yasa grupları, ekipman, başlangıç teknolojileri, senaryo | Altyapı |
| Veri bütünlüğü | `tests/test_mode_zombie.gd` | `test_data`'nın 13 denetimi zombi verisiyle (etki sözlüğü, çeviri, başvurular) | Altyapı |
| Salgın | `test_zm_epidemic.gd` | 02 §2.3 tablosunu ±1 günle üretir; sönme; akış; iklim | 03 §15 |
| Türler | `test_zm_types.gd` | Motor taklidi sonuçları (siperli tümen 3 sürüyü tutar), evrim | 04 §12 |
| Bilim | `test_zm_science.gd` | Bina şartları, kadro, numune, kaza olasılığı, dağıtım | 05 §13.1 |
| Doktrin | `test_zm_doctrine.gd` | DP kazanımı, dışlama, AI kök dağılımı | 06 §8 |
| Ekonomi | `test_zm_economy.gd` | İşgücü kademesi, gıda açığı, ithalat çarpanı, Romanya örneği | 07 §17 |
| Askerî | `test_zm_military.gd` | Kordon, ordu içi bulaş, mühimmat, kuşatma | 08 §18 |
| Siyaset | `test_zm_politics.gd` | Kriz terimleri, çöküş makinesi, Konsey | 09 §13.2 |
| Yapay zekâ | `test_zm_ai.gd` | Φ, emir bütçesi, hile yok, tutum seçimi | 10 §13 |
| Arayüz | `test_zm_ui.gd` | Panel kurulur, bilgi sisi, uyarı sınırı | 11 §12 |
| Kayıt ve belirlenimcilik | `test_zm_save.gd`, `test_zm_determinism.gd` | §5, §6 | Bu belge |
| Oyuncu adına iş yok | `country_check.gd -- --game_mode=zombie --days=60` | Kolaylıklar kapalı, oyuncu ülkesinde hiçbir otomatik karar | 02 §7.3, 08 §15, 11 §12 |
| Denge | `game/dev/zm_balance.gd` + `tools/balance_parallel.sh` | 14 kontrol, 6 koşu, her biri ≥ 5/6 | 10 §8 |
| Performans | `game/dev/sim.gd --game_mode=zombie` | `epidemic`, `und_field`, `und_ai`, `ai_zm` profil anahtarları; temel oyunun ≤ ×1,3'ü | 03 §12, 10 §10 |

`tools/run_tests.sh` bugün her WWII dışı modu `country_check --days=30` ile koşar; zombi modu `hidden: true` iken de koşulur.
`sim.gd` ve `balance_parallel.sh`'nin `--game_mode` alması küçük araç işidir (ww2 dışındaki modda bugün çıkış 2 verirler).

---

## 8. Teknik uygulama sırası

Her aşama ayrı PR; her PR'da tam test paketi, WWII birebir aynılık denetimi ve (oyun mantığı değiştiyse) WWII denge testi.

| Aşama | İçerik | Bağımlılık | Bitti ölçütü |
|---|---|---|---|
| T0 | PR-K1 (A kancaları, H01–H08) + `_template` örnek kullanımları | — | WWII birebir; `_template` testleri kancaları kullanır |
| T1 | İskelet: `tools/new_mode.py zombie`, manifest, `--blank` olaylar/programlar, `UND` ülkesi, `own/epidemic.json`, `epidemic.gd` + `hash.gd` (arayüzsüz) | T0 | `test_zm_epidemic` 02 tablosunu üretir; 1.461 gün hatasız; profil ≤ 12 ms/gün |
| T2 | Sürüler ve kordon: sürü doğumu, `horde_ai.gd`, `military_zm.gd` (kordon, ısırık, kent), `own/hollow_types.json` | T1, PR-K3 | Siperli tümen testi; kordon kurulur; sürü sınırı tutar |
| T3 | Devlet YZ + evreler + oyun sonu: `state_ai.gd`, `rules.json` evreleri, `check_end` | T2 | `zm_balance` kontrol 1–5, 9, 10 |
| T4 | Bilim: `science.gd`, teknoloji ve bina yamaları, serum/aşı | T3, H20, H23 | Kontrol 6–7 |
| T5 | Ekonomi ve siyaset: `economy_zm.gd`, `politics_zm.gd`, yasalar, olaylar, Konsey | T3, PR-K2 | Kontrol 8, 11–13; 07 Romanya örneği ±%5 |
| T6 | Arayüz: Salgın paneli, üst çubuk, uyarılar, kurulum ekranı, rehber | T3, PR-K4 | `test_zm_ui`; country_check yeşil |
| T7 | Ses ve görsel entegrasyonu (dosyalar geldikçe), `hidden: false` | T6 + varlık dalgası 1 | Menüde görünür; kullanıcı onayı |

Aşamaların iş tahmini ve varlık üretim sırası 16_yol_haritasi.md'dedir.

---

## 9. Teknik riskler (özet; ayrıntı 17_ozgunluk_ve_riskler.md)

| Risk | Olasılık | Etki | Azaltma |
|---|---|---|---|
| Sürü sayısı web'de akıcılığı bozar | Orta | Yüksek | Web sınırı 800, eyalet başına 2 (03 §12.2); ekranlı ölçüm (ROADMAP G) |
| A kancalarından biri insan onayı almaz | Düşük | Yüksek | Her birinin yedek planı var (kaynak belgeler); H04 ve H02 yedekleri zayıf → önce bunlar tartışılır |
| Kayıt boyutu web'de yavaşlık | Düşük | Orta | base64 ikili, ~0,6 MB; gerekirse sıkıştırma (`compress`) |
| Temel oyun değişince yama kırılır | Orta | Orta | Yamalar kimlikle çalışır; `test_mode_zombie` her CI koşusunda veriyi denetler |
| Belirlenimcilik kayması (ondalık toplama sırası) | Düşük | Orta | Çift tampon, sabit sıra, `test_zm_determinism` |
| Mod kodu motor iç ayrıntısına bağlanır | Orta | Orta | Yalnız kancalar ve genel API (`World`, `Economy.change_law`, `Military.order_move`…); iç `_` fonksiyon çağrılmaz |

---

## 10. Açık sorular

1. **Kanca PR'larının sırası ve onayı:** A kademesi tek PR mı, ikiye mi bölünsün (akış: H01–H03; askerî: H04, H07, H08)?
2. **`on_day_begin` genel bir çözüm mü olmalı?** Alternatif: `ModeRules.day_order` ile kural betiğinin günlük çağrı noktasını seçmesi.
   Bu belge basit olanı öneriyor (iki sabit nokta: başta ve sonda).
3. **Uyuyan ülke havuzu (H26)** 24 yuva mı (09 §5.2)? Renk dizini sınırı 255; 80 + 24 + `UND` = 105, sorun yok.
4. **`class_name` yasağı** mod kodunda gerekli mi? Ad çakışması riski (`Epidemic`, `Science`) gelecekteki modlar için gerçek; `preload`
   ile sabit yol daha güvenli ama okunaklılık düşer.
5. **Araçlar:** `sim.gd` ve `balance_parallel.sh`'nin `--game_mode` desteği mod altyapısına mı, zombi PR'ına mı girsin? Öneri: altyapıya
   (bütün modlar için).

## 11. Kaynaklar

- Depodaki kod: `game/core/game_modes.gd`, `game/core/mode_rules.gd`, `game/autoload/game.gd` (`switch_mode`, `_on_day`, kayıt),
  `game/autoload/world.gd` (`_on_day_passed`, `daily_update`), `project.godot` (autoload sırası), `game/autoload/economy.gd`
  (`resource_names` ← `buildings.json` `"resources"`, `can_build`), `game/autoload/military.gd` (`front_provinces`, `_compute_supply`,
  `order_move`), `game/autoload/diplomacy.gd` (`capitulate`), `game/autoload/air.gd` (`bonus`), `game/autoload/ai.gd`,
  `tools/new_mode.py`, `tools/run_tests.sh`, `tests/test_modes.gd`, `tests/test_mode_template.gd`, `tests/snapshot.gd`.
- Mod rehberi: `docs/modlar/README.md` (yerleşim, yama kuralları, sözleşme, kancalar), `docs/modlar/ASISTAN.md`.
- Bu klasör: 02 §10, 03 §2 ve §11–§14, 04 §2.5 ve §12, 05 §1.3 ve §12, 06 §2.2 ve §6, 07 §1.4 ve §14, 08 §2.2–§2.3 ve §16,
  09 §1.3–§1.4 ve §10, 10 §9 ve §12, 11 §11, 12 §9, 13 §9.
