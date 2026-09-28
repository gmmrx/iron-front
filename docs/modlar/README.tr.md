[English](README.md) · **Türkçe**

# Oyun modları — katkıcı rehberi

Oyun birden çok **mod** taşıyabilir. İlk mod bugünkü 2. Dünya Savaşı oyunudur (`ww2`). Yeni bir mod, motoru değiştirmeden
kendi verisini, başlangıç tarihini, oynanabilir ülkelerini ve isteğe bağlı küçük bir kural betiğini getirir. Zombi istilası
modunun tasarım araştırması [zombi/](zombi/README.md) klasöründe.

Bu sayfa yapay zekâ asistanıyla kod yazanlar ("vibecoder") için yazıldı. Asistanına tek sayfalık özeti
[ASISTAN.md](ASISTAN.md) olarak verebilirsin. Claude Code kullanıyorsan `yeni-mod` yeteneği (skill) bu adımları kendisi izler.

> **Önce oku:** [docs/OZGUNLUK.md](../OZGUNLUK.md). Başka bir oyundan ad, metin, sayı tablosu ya da ekran düzeni alma.

---

## 30 dakikada ilk mod

```bash
# 1) iskelet: klasör, manifest, kural betiği, test; modu kayda ekler
python3 tools/new_mode.py soguk_savas --name-en "Cold War" --name-tr "Soğuk Savaş"

# 2) manifesti düzenle: data/modes/soguk_savas/mode.json (tarihler, oyuncu, açıklama)

# 3) veriyi değiştir (aşağıda ayrıntı)
python3 tools/new_mode.py --blank soguk_savas common/events.json     # WWII olayları olmasın
python3 tools/new_mode.py --blank soguk_savas common/focuses.json    # WWII program ağaçları olmasın
python3 tools/new_mode.py --blank soguk_savas common/history.json    # WWII tarih çizelgesi olmasın
python3 tools/new_mode.py --copy  soguk_savas common/laws.json       # yasaları baştan yazacağım

# 4) hızlı denetim (Godot gerekmez)
python3 tools/new_mode.py --check soguk_savas

# 5) oyunda aç (ya da menüde Yeni Oyun → mod listesi)
godot --path . -- --game_mode=soguk_savas

# 6) testler
godot --headless --path . --import                                   # yeni .gd dosyası eklediysen
godot --headless --path . -s tests/run.gd -- --file=test_mode_soguk_savas
godot --headless --path . -s tests/run.gd -- --file=test_modes
godot --headless --path . -s game/dev/country_check.gd -- --game_mode=soguk_savas --days=30
```

Bitince ayrı bir branch'te pull request aç ve açıklamaya test sonuçlarını sayılarla yaz.

---

## Klasörler

```
data/modes/
  modes.json                       kayıt: {"default": "ww2", "modes": ["ww2", "_template", ...]}  (sıra = menü sırası)
  ww2/mode.json                    WWII: yalnız manifest; verisi data/common, data/history, data/map
  _template/                       gizli ama ÇALIŞAN örnek mod (CI her koşuda test eder) — kopyalamaya başla
    mode.json
    scenario.json                  başlangıç sahipliği katmanı
    common/events.patch.json       1 olay ekler, 2 WWII olayını siler
    own/settings.json              modun kendi verisi (kural betiği okur)
  <id>/                            senin modun: manifest + YALNIZ değişen dosyalar
game/modes/<id>/rules.gd           isteğe bağlı kod kancaları (ModeRules'u genişletir)
tests/test_mode_<id>.gd            modun testleri
```

**Yasaklar** (`--check` ve `tests/test_modes.gd` yakalar):
- `data/modes/**` altında yalnız `.json` olur. `.gd` dosyası `data/` altında yüklenmez (klasör motor için gizli); betik
  `game/modes/<id>/` altına. Çeviri `game/localization/strings.csv`'ye. Görsel/ses dosyası yok (CLAUDE.md kural 6).
- `map/` yok: harita geometrisi bütün modlarda ortak (aşağıda "Bilinen sınırlar").
- Mod klasöründeki her `X.json` ya da `X.patch.json` için `data/X.json` var olmalı (yazım hatalarını yakalar).
  Tek istisna `own/`: modun kendi verisi (aşağıda).
- Aynı dosyanın hem tam kopyası (`X.json`) hem yaması (`X.patch.json`) olmaz: yama kopyanın üzerine uygulanır ve
  içindeki `null`'lar kopyada düzenlediğin kayıtları sessizce siler.

---

## Manifest (`mode.json`)

Yazmadığın alan WWII değerini alır.

| Alan | Tip | Varsayılan (WWII) | Anlamı |
|---|---|---|---|
| `id` | metin | — (zorunlu) | klasör adıyla aynı; küçük harf, rakam, `_` |
| `name` | `{en, tr}` | — (zorunlu) | menüdeki ad |
| `hidden` | bool | `false` | `true`: menüde görünmez (yarım modlar için) |
| `description` | `{en, tr}` | — | menüde adın altında |
| `subtitle` / `subtitle_key` | `{en, tr}` / CSV anahtarı | `MENU_SUBTITLE` | ana menü alt başlığı |
| `welcome` / `welcome_key` | `{en, tr}` (tam bir `%s`) | `NOTE_WELCOME` | oyun başında haber (`%s` = ülke adı; yüzde işareti `%%`) |
| `end_text` / `end_text_key` | `{en, tr}` | `GAMEOVER_TIME` | süre dolunca oyun sonu metni |
| `start_date` | `"YYYY-AA-GG"` | `1936-01-01` | başlangıç tarihi (takvimde var olan gün; boş olamaz) |
| `end_date` | `"YYYY-AA-GG"` ya da `""` | `1948-01-01` | süre sınırı (`""` = yok) |
| `start_tension` | sayı | `0.0` | başlangıç kriz endeksi |
| `default_player` | ülke kodu | `TUR` | ülke seçiminde önce seçili ülke |
| `featured` | [ülke kodu] | 8 büyük ülke | ülke seçiminin üstündeki kartlar |
| `playable` | `"all"` ya da [ülke kodu] | `"all"` | seçilebilir ülkeler |
| `menu_focus` | ülke kodu | `GER` | ana menü kamerasının süzüldüğü yer |
| `majors` | [ülke kodu] | GER ENG FRA ITA SOV | büyük güçler (araştırma yuvası, AI davranışı) |
| `start_techs` | [teknoloji] | 4 temel teknoloji | büyük ve kalabalık ülkelere başta verilir |
| `start_techs_min_population` | tamsayı | `15000000` | bu nüfusun üstü de alır |
| `ai.rearm_year` | yıl (`0` = kapalı) | `1939` | AI bu yıldan sonra askerî fabrikaya yönelir |
| `ai.cautious_until` | tarih (`""` = kapalı) | `1942-01-01` | demokrasiler bu tarihe kadar büyük güce temkinli |
| `ai.phoney_war_days` | gün (`0` = kapalı) | `270` | demokrasiler savaşın ilk günlerinde isteksiz |
| `ai.major_hold_fire_days` | gün (`0` = kapalı) | `240` | büyük güçler birbirinin anavatanına bu kadar gün saldırmaz |
| `combat.phoney_war_days` | gün | `270` | muharebede demokrasi isteksizlik cezası süresi |
| `scenario` | dosya adı | `""` | başlangıç sahipliği katmanı (aşağıda) |
| `rules` | `res://game/modes/<id>/rules.gd` | `""` | kod kancaları (aşağıda) |

Kapalı değer için `null` yazma; `0` ya da `""` yaz.

---

## Veriyi değiştirmek: tam dosya ya da patch

Mod `data/` altındaki her JSON'u (harita geometrisi hariç) iki yolla değiştirebilir:

| Yol | Ne zaman | Nasıl |
|---|---|---|
| **Tam dosya** | dosyanın çoğu değişecek | `data/modes/<id>/common/laws.json` (kopya: `--copy`). Temel dosyanın **tamamının** yerine geçer. |
| **Patch** | birkaç şey eklenecek/silinecek | `data/modes/<id>/common/events.patch.json`. Temel dosyayla derin birleşir. |

**Patch kuralları:**
- Sözlükler iç içe birleşir. Değeri `null` olan anahtar **silinir**; yeni anahtar sona eklenir.
- Öğeleri `"id"` taşıyan diziler kimliğe göre birleşir: aynı kimlik güncellenir, yeni kimlik sona eklenir,
  `{"id": "x", "_delete": true}` o öğeyi siler.
- Diğer diziler ve değerler olduğu gibi değişir.
- Temel sıra korunur; sonuç her seferinde aynıdır (belirlenimci).

Örnek (`_template`):
```json
{"events": {
  "jap_february_26": null,
  "template_hello": {"title": {"en": "...", "tr": "..."}, "options": [...], "trigger": {"tag": "TUR", "date": "1936-01-10"}}
}}
```

**`--blank`:** `common/events.json` için bütün WWII olaylarını, `common/focuses.json` için bütün ülke program
ağaçlarını, `common/history.json` için tarih çizelgesini kaldıran bir patch yazar. Motorun kendi olayları ve `_generic`
ağacı kalır. Olayları boşaltırsan ağaçları da boşalt: WWII programları bazı olayları açar. Ağaçları boşaltırsan çizelgeyi
de boşalt: çizelge WWII odaklarını tamamlar (araç ikisini de uyarır, test de yakalar).

**Tarih çizelgesi (`common/history.json`):** yapay zekâ ülkeleri buradaki tarihî adımları tam gününde atar (savaşlar,
ilhaklar, ittifaklar); oyuncunun ülkesi hiçbirini kendiliğinden atmaz. `ai_free_from` tarihinden önce yapay zekâ kendi
başına savaş açmaz ve saldırı çağrılarına katılmaz (WWII'de 1945-09-02). Modun kendi çizelgesini yazabilir
(`{"ai_free_from": "YYYY-AA-GG", "entries": [{"date", "tag", "focus" | "mark_focus" | "effects", "require"}]}`) ya da
`--blank` ile boşaltabilir; boş çizelgede `ai_free_from` modun başlangıç tarihi olur.

## Senaryo katmanı (`scenario.json`)

Harita ortak, ama başlangıç sınırları moda göre değişebilir:
```json
{"owners": {"346": "TUR"}, "capitals": {"TUR": 346}, "vp": {"123": 10}}
```
`owners`: eyalet kimliği → ülke; `capitals`: ülke → eyalet kimliği; `vp`: şehir kimliği → zafer puanı. Kimlikler
`data/map/states.json` ve `data/map/cities.json`'da. Nüfus, insan gücü ve kontrol kendiliğinden yeniden hesaplanır.
Olmayan bir eyalet/ülke/şehir kimliği (yazım hatası) `test_modes::test_mode_contract`'ı kırmızı yapar.

## Modun kendi verisi (`own/`)

WWII verisinde karşılığı olmayan her şey (ör. salgın parametreleri, zombi türleri, araştırma merkezi tablosu)
`data/modes/<id>/own/<ad>.json` dosyalarına yazılır. Bu klasörde "temel dosya var mı" denetimi ve tam dosya/yama kuralı
yoktur; motor bu dosyaları kendiliğinden okumaz, **kural betiğin** okur:
```gdscript
var cfg: Variant = GameModes.load_own("epidemic.json")     # yoksa null
```
Sayıları koda sabit yazma, buraya koy (CLAUDE.md kural 2). Örnek: `data/modes/_template/own/settings.json` ve
`game/modes/_template/rules.gd`.

---

## Kural betiği (`game/modes/<id>/rules.gd`)

Veri yetmediğinde küçük kod kancaları. `extends ModeRules`; kullanmadığın kancayı sil. Tam liste:
[`game/core/mode_rules.gd`](../../game/core/mode_rules.gd), örnek: [`game/modes/_template/rules.gd`](../../game/modes/_template/rules.gd).

| Kanca | Ne zaman |
|---|---|
| `on_new_game()` | her yeni oyunda (açılışta ve `Game.new_game` sonunda); her oyunda taze betik örneği |
| `on_game_started(player)` | oyuncu ülkesini seçip oyuna girince |
| `on_day()` / `on_hour()` / `on_month()` | her gün (AI'dan sonra, oyun sonu denetiminden önce) / saat / ay |
| `check_end()` | `{}` = devam; `{"victory": bool, "reason": "<CSV anahtarı>"}` = oyun biter |
| `score(tag)` | oyun sonu skoru (`-1` = zafer puanı toplamı) |
| `to_save()` / `from_save(d)` | modun kendi durumu kayda yazılır/okunur (büyük tamsayıları `str()` ile yaz) |
| `effect_keys()`, `apply_effect`, `describe_effect` | olay/program için **yeni etki** (üçüne birden ekle; CLAUDE.md kural 2) |
| `condition_keys()`, `check_condition` | olay/program için **yeni şart** |

Kurallar: oyuncu adına iş yapma (kural 1); rastgelelik gerekiyorsa kendi `RandomNumberGenerator`'ını tohumla ve kayda yaz;
autoload'lara adıyla erişebilirsin (`World`, `Economy`...), ama motor dosyalarını değiştirmen gerekiyorsa **dur ve sor**.

## Metinler

- Veri içindeki metinler JSON'da `{"en": "...", "tr": "..."}` (olay başlıkları, mod adı...).
- Arayüz ya da kural betiği metinleri `game/localization/strings.csv`'ye İngilizce ve Türkçe satır olarak; ardından
  `godot --headless --path . --import`.

---

## Mod sözleşmesi

Motor bazı anahtarlara doğrudan başvurur. Modun verisi bunları silmemeli; `tests/test_modes.gd::test_mode_contract` ve
`test_mode_<id>` denetler.

| Dosya | Anahtar | Eksikse |
|---|---|---|
| `common/events.json` | `call_to_arms`, `white_peace`, `election`, `faction_invite` | `call_to_arms`/`faction_invite`: hata vermez, sessizce çalışmaz (müttefikler savaşa çağrılmaz, davet boşa düşer); `white_peace`: barış teklifi oyuncuya gitmez; `election`: seçim penceresi hata verir |
| `common/focuses.json` | `trees._generic` | program ağacı her istendiğinde hata verir; kendi ağacı olmayan ülkelerin programı olmaz |
| `common/laws.json` | `conscription`, `economy`, `trade` grupları; `start._default` | yasa kurulumu çöker |
| `common/spirits.json` | `popularity._<ideoloji>` (ülkelerin bütün ideolojileri için), `start`, `start_factions` | siyaset kurulumu çöker |
| `common/units.json` | `start_divisions._default`, `templates` (en az bir şablon; 0: piyade, 1: zırhlı), `terrain.plains` (bilinmeyen arazinin yedeği) | ordu kurulumu çöker |
| `common/equipment.json` | `infantry_equipment`, `convoy`; `start_fleets._default_coastal` | üretim/konvoy/filo kurulumu çöker |
| `common/buildings.json` | kaynaklar içinde `oil` | yakıt hesabı |
| `common/technologies.json` | `start_techs`'teki her teknoloji | başlangıç teknolojisi verilemez |
| `common/countries.json` | haritadaki eyaletlerin sahibi olan her ülke | harita yüklenemez |

## "Bitti" tanımı

1. `python3 tools/new_mode.py --check <id>` → sorun yok
2. `-s tests/run.gd -- --file=test_modes` ve `--file=test_mode_<id>` → hepsi geçti
3. `-s game/dev/country_check.gd -- --game_mode=<id> --days=30` → 0 sorun
4. `GODOT=... tools/run_tests.sh` (CI'daki iş; bütün modları koşar) → hepsi geçti
5. Motor koduna dokunduysan WWII denge testi: `GODOT=... tools/balance_parallel.sh 6` (her kontrol en az 5/6)

## Bilinen sınırlar

- **Harita ortak.** Bütün modlar aynı bölge/eyalet/şehir geometrisini kullanır; ayrı harita paketi (≈120 MB) web sürümünü
  şişirir. Sınırlar `scenario.json` ile değişir.
- **WWII'ye göre yazılmış motor ayrıntıları.** Mod aynı kimlikleri koruduğu sürece çalışır: ideoloji adları
  (demokratik/komünist/faşist/bağlantısız), AI'ın yasa ve danışman sırası (`ai.gd`), birkaç ülkeye özgü AI ayarı, başlangıç
  üretim hattı ekipmanları. Bunları değiştiren bir mod AI'ı ilgili konuda pasif bırakır.
- **Birim modelleri, ikonlar, sesler** moddan değiştirilemez (kural 5 ve 6); görsel ihtiyaçlar listelenir, kullanıcı üretir.
- **Moda özgü arayüz paneli ve harita modu yok.** Gerekirse ayrı bir iş olarak, yalnız `panel_layout` yardımcılarıyla eklenir.
- **WWII denetimleri** (`balance.gd`, `gov_check.gd`, `playtest.gd`) yalnız `ww2` modunda koşar.
- Bir mod kaydı eski sürümde açılırsa WWII verisine yüklenir.

## SSS

- **Modum menüde görünmüyor.** `modes.json`'da kayıtlı mı? (`--check` sorun olarak yazar.) `mode.json`'da `"hidden": true`
  mı kalmış? (`--check` bunu "bilgi" satırı olarak yazar; `false` yap.)
- **"Kaydın oyun modu bulunamadı".** Kayıt, kayıtlı olmayan bir moddan (silinmiş ya da adı değişmiş).
- **Yeni bir etki istiyorum.** Önce var olan etki sözlüğüne bak (`game/autoload/politics.gd` → `apply_effects`); yoksa
  `rules.gd`'de `effect_keys` + `apply_effect` + `describe_effect`.
- **Test "bilinmeyen etki" diyor.** Etki anahtarı ne motorda ne de `rules.gd`'nin `effect_keys()` listesinde.
