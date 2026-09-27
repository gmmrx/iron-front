# Zombi modu — 15 Kalır / değişir / çıkar matrisi

> **Özet.** Temel oyunun (2. Dünya Savaşı modu) **her sistemi** zombi modunda ne olur? Bu belge kod ve veri dosyalarını tek tek
> sayar ve dört karardan birini verir: **Aynen** (hiç dokunulmaz), **Değişerek** (içerik ya da kanca ile), **Çıkar** (modda yüklenmez
> ya da kapalıdır), **Yeni** (modun eklediği). Her satırda değişikliğin **nasıl** yapıldığı yazar: veri yaması, `own/` verisi, kural
> betiği ya da motor kancası (14_teknik_plan.md'deki H numarası).
> - **Sayım:** 12 autoload'un 2'si aynen, 10'u değişerek (Navy yalnız kural düzeyinde); 14 çekirdek sınıfın 10'u aynen; 20 harita
>   betiğinin 16'sı aynen; 32 arayüz betiğinin 22'si aynen; `data/common`'daki 10 dosyanın 1'i aynen, 9'u yamayla; tarihçe ve harita
>   verisi aynen. Hiçbir sistem tamamen çıkmaz. Çıkan şey **içeriktir**:
>   2. Dünya Savaşı olayları, devlet programları, 13 teknoloji, tarihî yapay zekâ takvimi.
> - **Motor dosyası değişikliği yalnız kancalardır** (14 §3); kancasız değişiklik yok. Bu yüzden WWII modu her adımda birebir aynı kalır.
> - Son bölüm, mod altyapısının zombi modu için sağlaması gerekenleri **bugünkü durumuyla** listeler: 14 madde sağlandı, 9 madde kanca
>   bekliyor.

---

## 1. Okuma anahtarı

| Karar | Anlamı |
|---|---|
| **Aynen** | Kod da veri de değişmez |
| **Değişerek** | Motor aynı; içerik yama ya da `own/` ile değişir, ya da bir kanca (H..) davranışı moda bırakır |
| **Çıkar** | Modda yüklenmez (yama `null`/`_delete`), kapalıdır (manifest değeri 0/""), ya da görünmez |
| **Yeni** | Modun eklediği sistem (kod `game/modes/zombie/`, veri `data/modes/zombie/`) |

"Nasıl" sütununda: **Yama** = `common/<dosya>.patch.json`; **Own** = `own/<dosya>.json`; **Kural** = `game/modes/zombie/rules.gd` ve
alt sınıfları; **Manifest** = `mode.json`; **H..** = 14_teknik_plan.md'deki kanca.

---

## 2. Autoload'lar (`game/autoload/`, 12)

| Sistem | Bugün ne yapar | Karar | Modda | Nasıl | Belge |
|---|---|---|---|---|---|
| `GameClock` | Saatlik tick, hızlar, gün/ay sinyali, açılışta tarih moddan | **Aynen** | Salgın günlük adımı `day_passed`'ten sonra, yapay zekâdan önce | H01 | 02 §1, 14 §3.3 |
| `World` | Eyalet, bölge, şehir, ülke; kontrol dizisi; `transfer_state`; gerginlik; bildirim; günlük sinyal | **Değişerek** | Düşmüş bölge = kontrol `UND`'de; uyuyan ülkeler; `on_day_begin` çağrısı | H01, H26; Yama (countries) | 01 §3c, 09 §5 |
| `Politics` | Olay, program, ulusal durum, danışman, karar, seçim, ideoloji, etki/şart sözlüğü | **Değişerek** | WWII olayları ve programları çıkar; salgın olayları, Kriz Doktrini, kabine uzmanları, kriz tutumları gelir; seçimler salgın savaşını saymaz | Yama (events, focuses, spirits); Kural (olay dağıtıcısı, yeni etki/şartlar); H02, H21, H22, H27, H40, H42–H44, H47 | 06, 09 |
| `Research` | Kategoriler, teknolojiler, yuvalar, yıl cezası, `research_bonus` | **Değişerek** | 8 sekme: 4 tıp/bilim + 4 taşınan; 13 teknoloji silinir, 50 eklenir; kategoriye özgü hız | Yama (technologies); H23 | 05 §3, 06 §3 |
| `Economy` | Fabrika, inşaat, üretim, ticaret, yasalar, kaynaklar, tüketim malı | **Değişerek** | Gıda (7. kaynak), işgücü oranı, düşmüş eyalet üretmez, liman karantinası, yeni yasa grupları, bina şartları | Yama (buildings, laws, equipment); Own (economy); H05, H17–H20, H24, H25 | 07, 09 §3 |
| `Diplomacy` | Savaş, gerekçe, kriz endeksi, çağrı, ittifak, garanti, geçiş, beyaz barış, teslim | **Değişerek** | `UND` ile kalıcı "salgın savaşı" (ayrı tür); teslim yerine çöküş makinesi; ilişki, itibar, şeffaflık, yardım (mod durumunda); devletler arası savaş ayara bağlı | H02, H03, H31, H45; Kural | 09 §5–§6 |
| `Military` | Tümen, şablon, ordu, ordu grubu, komutan, cephe, muharebe, ikmal, hareket | **Değişerek** | Sürüler `UND` tümeni; kordon ordusu; ısırık; arazi/gece/engel çarpanı; kent kuralı; kuşatma; yorgunluk; 8 yeni tabur | Yama (units, equipment); Own (hollow_types, military); H04, H07–H11, H13–H15 | 04, 08 |
| `Navy` | Filolar, görevler, konvoy, deniz muharebesi | **Değişerek** (az) | Boğaz nöbeti, liman devriyesi, deniz tahliyesi yeni görev değildir: mevcut görevler + kural (tahliye kapasitesi) | Kural | 08 §11 |
| `Air` | Kanatlar, görev bölgesi, hava üstünlüğü, yakın destek | **Değişerek** | `UND`'ye karşı hava üstünlüğü terimi yok; yakın destek hedef ayırt edilebilirliğiyle çarpılır | H12 | 08 §10 |
| `AI` | Stratejik (inşaat, üretim, araştırma, program, yasa, danışman) ve operasyonel (tümen, cephe, taarruz, savaş) | **Değişerek** | Tarihî takvim kapalı (manifest); salgın katmanı; sürü YZ; araştırma sırası; yasa politikası moda devredilir | Manifest (`ai.*` = 0); H28–H31, H41, H42; Kural (`horde_ai`, `state_ai`) | 10 |
| `Game` | Yeni oyun, kayıt/yükleme (sürüm 2, `mode_state`), oyun sonu, kural kurulumu | **Aynen** | Kural betiği ve `mode_state` zaten var | — | 14 §1, §5 |
| `Audio` | Efekt kaydı, sıralı bildirim, müzik yönetmeni, stinger | **Değişerek** | Mod efektleri, yedi durumlu müzik, sürü ambiyansı | H35–H37; Own (audio) | 13 |

`Game` ve `GameClock` aynen; `Navy`'nin motor kodu değişmez, yalnız kural betiği onun mevcut görevlerini kullanır.

---

## 3. Çekirdek sınıflar (`game/core/`, 14)

| Sınıf | Karar | Modda | Nasıl |
|---|---|---|---|
| `Country` | **Değişerek** | `doctrine_points` alanı (kayda girer); dayanma iradesi = `war_support` (ad arayüzde değişir) | H21 |
| `StateRegion` | **Aynen** | Salgın bölmeleri eyalet nesnesine değil mod durumuna yazılır (14 §4.3) | — |
| `Province` | **Aynen** | Kent kuralı `terrain_of` kancasıyla, bölge verisi değişmez | H09 |
| `City` | **Aynen** | Zafer puanı çöküş hesabında aynen | — |
| `Division` | **Aynen** | Bulaş, mühimmat, moral mod durumunda | — |
| `Army` | **Değişerek** | `cordon` (eyalet listesi, kayda girer) | H04 |
| `ArmyGroup`, `Commander` | **Aynen** | Komutan özellikleri sürüm 2 (06 §4.10) | — |
| `Fleet`, `AirWing` | **Aynen** | — | — |
| `ProductionLine`, `ConstructionProject` | **Aynen** | Hat kırpma yardımcısı ekonomi tarafında | H05 |
| `GameModes`, `ModeRules` | **Değişerek** | `ModeRules`'a kancalar eklenir (H01–H47) | 14 §3 |

---

## 4. Harita (`game/map/`, 20)

| Betik | Karar | Modda | Belge |
|---|---|---|---|
| `map_view_3d.gd` | **Değişerek** (sürüm 2) | Sürüm 1: aynen (işgal çizgisi, işaret dokusu anlamına uygun işlerde). Sürüm 2: `MapMode.OUTBREAK` (insan onayı) | 11 §2, H48 |
| `map_camera_3d.gd` | **Aynen** | — | — |
| `unit_layer.gd` | **Değişerek** | Gizli türlerin sayacı çizilmez | H16 |
| `unit_models.gd` | **Değişerek** (içerik) | `ROLE_SCALE["hol"]` ve sürü figürleri (dosyalar gelince) | 12 §3.1 |
| `map_icon_layer.gd` | **Değişerek** | Bilim, kamp, kordon kapısı, Konsey ikonları | H39 |
| `city_layer.gd`, `city_layer_3d.gd` | **Aynen** | Terk/yanık hâller sürüm 3 (insan onayı) | 12 §7 |
| `country_labels.gd`, `country_labels_3d.gd` | **Aynen** | `UND` etiketi çizilmez mi? Etiket, ülke eyalet sahibiyse çizilir; `UND` sahip değil, yalnız kontrol eder → çizilmez | 11 §2.1 |
| `front_layer.gd` | **Aynen** | Kordon ordusu cephesi kendiliğinden çizilir (cephe `front_provinces`'tan) | H04 |
| `fleet_layer.gd`, `air_layer.gd`, `route_layer.gd`, `sea_lanes.gd`, `strait_layer.gd` | **Aynen** | — | — |
| `tree_layer.gd`, `weather_layer.gd` | **Aynen** | Hava durumu salgında da çamur/kar etkisi taşır (03 §6) | — |
| `battle_icons.gd`, `battle_audio.gd` | **Aynen** | `UND` muharebeleri aynı ikon ve seslerle | 13 §2 |
| `path_motion.gd` | **Aynen** | — | — |

---

## 5. Arayüz (`game/ui/`, 32)

| Betik | Karar | Modda | Nasıl / Belge |
|---|---|---|---|
| `hud.gd` | **Değişerek** | Salgın paneli (E) ve sol menü düğmesi | H06 |
| `top_bar.gd` | **Değişerek** | KSE, dayanma iradesi, salgın hücresi, gıda | H32; 11 §3 |
| `alert_bar.gd` | **Değişerek** | 28 salgın uyarısı | H33; 11 §5.1 |
| `game_over.gd` | **Değişerek** | Döküm tablosu | H38; 11 §8 |
| `main_menu.gd` | **Aynen** | Mod listesi altyapıda var | — |
| `country_select.gd` | **Aynen** | Öne çıkanlar manifestten | — |
| (yeni) kurulum ekranı | **Yeni** | Zorluk ve özel ayarlar | H34; 11 §9 |
| (yeni) Salgın paneli | **Yeni** | Altı sekme | H06; 11 §4 |
| `focus_panel.gd` | **Değişerek** | Başlık ve DP maliyeti | H21 |
| `politics_panel.gd` | **Değişerek** (az) | Yasa bedeli, doktrin durumları özeti, karar para birimi | H22, H25, H43 |
| `diplomacy_panel.gd` | **Değişerek** | 12 salgın eylemi | H45 (yoksa Salgın paneli "Dünya") |
| `event_popup.gd` | **Değişerek** (az) | Yer tutuculu metin | H27 |
| `research_panel.gd`, `construction_panel.gd`, `production_panel.gd`, `trade_panel.gd`, `army_panel.gd`, `navy_panel.gd`, `air_panel.gd`, `logistics_panel.gd`, `state_panel.gd`, `division_panel.gd` | **Aynen** | Yeni içerik (teknoloji, bina, ekipman, gıda, tabur) kendiliğinden listelenir; ek satırlar ipucunda | 05 §11.2, 07 §15, 08 §14 |
| `map_tooltip.gd` | **Değişerek** (az) | Salgın satırları | 11 §2.6 (kural betiği ipucu sağlayıcısı; H33 ile aynı PR'da) |
| `map_mode_bar.gd` | **Değişerek** (sürüm 2) | Salgın düğmesi | H48 |
| `notification_feed.gd`, `hover_tooltip.gd`, `panel_layout.gd`, `ui_theme.gd`, `resource_icon.gd`, `flag_factory.gd`, `drag_scroll.gd`, `pause_menu.gd`, `settings_panel.gd`, `game_settings.gd` | **Aynen** | — | — |

---

## 6. Veri dosyaları

| Dosya | Karar | Modda | Nasıl |
|---|---|---|---|
| `data/common/countries.json` | **Değişerek** | `UND` (Boşlar) + uyuyan ülke havuzu (24) | Yama; H26 |
| `data/common/events.json` | **Değişerek** | WWII olayları silinir (`--blank`), motor olayları kalır (`call_to_arms`, `white_peace`, `election`, `faction_invite`), 36 + evre/tür/bilim/askerî olayları eklenir | Yama |
| `data/common/focuses.json` | **Değişerek** | Ülke ağaçları silinir, `_generic` kalır, Kriz Doktrini ağacı eklenir | Yama |
| `data/common/technologies.json` | **Değişerek** | 13 silinir, 20 taşınır (yeni sekmelere), 50 eklenir | Yama |
| `data/common/laws.json` | **Değişerek** | Askerlik, ekonomi, ticaret kalır; 6 yeni grup | Yama |
| `data/common/spirits.json` | **Değişerek** | Başlangıç durumları kalır; kademe durumları, uzmanlar, doktrin durumları eklenir | Yama |
| `data/common/buildings.json` | **Değişerek** | 8 bilim binası, Kordon Hattı, kamp; `resources` dizisi 7 öğe (id'siz dizi yamada tamamen yazılır) | Yama |
| `data/common/equipment.json` | **Değişerek** | Serum, aşı, tıbbi malzeme, mühimmat ve askerî ekipman | Yama |
| `data/common/units.json` | **Değişerek** | 8 tabur/bölük, şablonlar (tam dizi) | Yama |
| `data/common/commanders.json` | **Aynen** | 1936 komutanları | — |
| `data/history/states_1936.json` | **Aynen** | 1936 bina ve kaynaklar | — |
| `data/map/*` (bölgeler, eyaletler, şehirler, deniz yolları, boğazlar, dokular) | **Aynen** | Harita ortak (altyapı kuralı) | — |
| (yeni) `data/modes/zombie/own/*.json` (12 dosya) | **Yeni** | Salgın, türler, suşlar, bilim, doktrin, ekonomi, askerî, siyaset, YZ, ses, varlıklar, kurallar | 14 §2.1 |

**Silinen içerik (özet):** 2. Dünya Savaşı olayları (tarihli ve zincirli), ülke program ağaçları, 13 teknoloji, yapay zekânın tarihî
takvimi (yeniden silahlanma yılı, temkin tarihi, garip savaş, büyük güç ateşkesi). **Silinmeyen:** 1936 liderleri, partiler, ideolojiler,
yasalar, fabrikalar, ordular, filolar, kanatlar, komutanlar, ittifaklar ve garantiler (salgın bunlarla başlayan bir dünyaya gelir).

---

## 7. Varlıklar (`assets/`)

| Klasör | Karar | Modda |
|---|---|---|
| `terrain/`, `shaders/`, `fonts/`, `branding/` | **Aynen** | Gölgelendirici yalnız sürüm 2 ısı haritasında (H48, insan onayı) |
| `models/` | **Değişerek** (ek) | `hollow_units.glb` ve isteğe bağlı tabur figürleri (12 §3) |
| `ui/icons_new/` | **Değişerek** (ek) | 205 ikon + 36 olay resmi (12 §4–§5); 20 taşınan teknolojinin ikonları aynen |
| `portraits/` | **Aynen** | Yeni portre yok |
| `flags/` | **Aynen** | `UND` bayrağı veriden çizilir |
| `audio/` | **Değişerek** (ek) | 49 efekt, 7 parça, 7 stinger (13) |

---

## 8. Test ve geliştirici araçları

| Araç | Karar | Modda |
|---|---|---|
| `tests/test_*.gd` (temel paket) | **Aynen** | WWII'de koşar (her test `mode()` ile kendi modunu seçer, varsayılan ww2) |
| `tests/test_modes.gd`, `tests/test_mode_template.gd` | **Aynen** | Zombi modu sözleşme testine kendiliğinden girer (`GameModes.ids(true)` döngüsü) |
| `tests/test_mode_zombie.gd`, `tests/test_zm_*.gd` | **Yeni** | 14 §7 |
| `game/dev/country_check.gd` | **Aynen** | `--game_mode=zombie` altyapıda var |
| `game/dev/balance.gd`, `gov_check.gd`, `playtest.gd` | **Aynen** (WWII'ye özgü) | Başka modda çıkış 2; mod için `zm_balance.gd` (yeni) |
| `game/dev/sim.gd` | **Değişerek** (araç) | `--game_mode` desteği (14 §10-5) |
| `tools/run_tests.sh` | **Aynen** | Her WWII dışı modu koşar |
| `tools/balance_parallel.sh` | **Değişerek** (araç) | `--game_mode` geçişi |
| `tools/new_mode.py` | **Aynen** | İskelet ve denetim |
| `tools/make_icon_prompts.py` | **Değişerek** (araç) | `--game_mode=zombie` (12 §9) |
| `tools/make_audio.py`, `tools/make_music.py` | **Değişerek** (içerik) | Yeni ses ve parça işlevleri (13 §7) |
| `game/dev/error_catcher.gd`, `audio_check.gd`, `drag_check.gd` | **Aynen** | — |

---

## 9. Mod altyapısının zombi modu için sağlaması gerekenler

Bu liste başta mod altyapısına **girdi** olarak istenmişti. Altyapı bu PR'da kurulduğu için bugünkü durumuyla yazılır.

| # | Gereksinim | Durum | Nerede |
|---|---|---|---|
| 1 | Veri dosyasını geçersiz kılma (tam dosya) | ✔ Sağlandı | `GameModes.path`, `load_json` |
| 2 | Kısmi değişiklik (yama, silme, kimlikli dizi birleştirme) | ✔ | `GameModes.merge` |
| 3 | Modun kendi veri dosyaları | ✔ | `own/`, `GameModes.load_own` |
| 4 | Başlangıç ve bitiş tarihi | ✔ | Manifest; `GameClock._ready`/`reset`, `Game.end_date` |
| 5 | Oynanabilir ve öne çıkan ülkeler, varsayılan oyuncu | ✔ | Manifest |
| 6 | Tarihî yapay zekâ takvimini kapatmak | ✔ | Manifest `ai.*`, `combat.*` |
| 7 | Kural betiği ve günlük/saatlik/aylık kancalar | ✔ | `ModeRules` |
| 8 | Yeni etki ve şart anahtarları | ✔ | `effect_keys`/`apply_effect`/`describe_effect`, `condition_keys`/`check_condition` |
| 9 | Oyun sonu ve puan | ✔ | `check_end`, `score` |
| 10 | Mod durumunun kayda yazılması | ✔ | Kayıt sürümü 2, `mode_state` |
| 11 | Kayıttan modu geri kurmak; bozuk kayıtta durumun korunması | ✔ | `Game.load_game`, `Game.save_mode` |
| 12 | Menüde mod seçimi | ✔ | `main_menu.gd` |
| 13 | CI'da modun sözleşme ve veri testleri | ✔ | `test_modes.gd`, `test_mode_<id>.gd`, `run_tests.sh` |
| 14 | İskelet ve denetim aracı | ✔ | `tools/new_mode.py` |
| 15 | Salgın adımının yapay zekâdan önce çalışması | ☐ Kanca | H01 |
| 16 | Özel savaş türü (salgın savaşı seçimi, iç cepheyi, gerginliği bozmasın) | ☐ Kanca | H02 |
| 17 | Teslimin yerine modun çöküş kuralı | ☐ Kanca | H03 |
| 18 | Kordon cephesi (eyalet listesiyle) | ☐ Kanca | H04 |
| 19 | Üretmeyen eyalet | ☐ Kanca | H05 |
| 20 | Moda özel panel ve kısayol | ☐ Kanca | H06 |
| 21 | Muharebe çarpanları ve kayıp sonrası kanca | ☐ Kanca | H07, H08 |
| 22 | Moda özel üst çubuk, uyarı, oyun sonu, kurulum ekranı, müzik | ☐ Kanca | H32–H38 |
| 23 | Moda özel harita modu | ☐ Görsel iş (insan onayı) | H48 |

---

## 10. Açık sorular

1. **`country_labels`:** `UND` hiçbir eyaletin sahibi olmadığı için etiket çizilmez (§4). Ama büyük bir düşmüş bölge kümesinin üzerinde
   "Boşlar" etiketi okunaklılığa yardım eder mi? (Harita katmanı işi; kural 5.)
2. **Komutanlar:** 1936 komutan listesi aynen kalır; salgında ölen/hastalanan komutan (ordu içi bulaş) olayı istenir mi? (08 ile birlikte.)
3. **Garantiler ve ittifaklar:** Temel oyundaki garanti/ittifak mekanikleri salgında da çalışır; "garanti verdiğin ülke çökerse" durumu
   09'daki koruma kuralıyla birleşmeli.
4. **Temel testlerin modda koşması:** Bugün temel test paketi yalnız WWII'de koşar; bazı genel testler (kayıt/yükleme, belirlenimcilik) zombi
   modunda da koşmalı mı? (14 §7'de ayrı `test_zm_save`/`test_zm_determinism` öneriliyor.)

## 11. Kaynaklar

- Depodaki kod ve veri (dosya listesi bu belgede sayıldı): `game/autoload/*.gd`, `game/core/*.gd`, `game/map/*.gd`, `game/ui/*.gd`,
  `game/dev/*.gd`, `tests/*.gd`, `tools/*`, `data/common/*.json`, `data/history/states_1936.json`, `data/map/*`, `assets/`.
- Mod altyapısı: `docs/modlar/README.md`, `game/core/game_modes.gd`, `game/core/mode_rules.gd`.
- Bu klasör: 01 §3e, 03–13, 14 §2–§3.
