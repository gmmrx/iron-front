---
name: yeni-mod
description: Iron Front'a yeni bir oyun modu ekleme ya da var olan bir modu (data/modes, game/modes) düzenleme. "Yeni mod", "yeni senaryo", "oyun modu ekle", "zombi modu", "mod verisi", "mode.json" gibi isteklerde kullan.
---

# Yeni oyun modu

Ayrıntılı rehber: `docs/modlar/README.md`. Bu yetenek oradaki adımları sırayla uygular.

## 0. Önce oku
- `docs/OZGUNLUK.md`: başka oyundan ad, metin, sayı, ekran düzeni alma; başka ticari oyunu hiçbir dosyada anma.
- `CLAUDE.md` kuralları: oyuncu karar verir (kural 1), veri güdümlü (2), metinler EN+TR (3), görsel değişiklik yok (5),
  sanat dosyası üretme (6).

## 1. İskelet
`python3 tools/new_mode.py <id> --name-en "..." --name-tr "..."` → `data/modes/<id>/mode.json`,
`game/modes/<id>/rules.gd`, `tests/test_mode_<id>.gd`, kayıt (`data/modes/modes.json`). Kimlik: küçük harf, rakam, `_`.
Sonra `godot --headless --path . --import` (yeni .gd dosyaları için).

## 2. Manifest
`mode.json` alanları README'deki tabloda. Yazılmayan alan WWII değerini alır. Kapalı değer `0` ya da `""` (null değil).
Yarım bir modu menüde gizlemek için `"hidden": true`.

## 3. Veri
- Dosyanın çoğu değişecekse: `python3 tools/new_mode.py --copy <id> common/<dosya>.json`, sonra düzenle.
- Birkaç ekleme/silme: `data/modes/<id>/common/<dosya>.patch.json` (`null` siler; `"id"`li dizilerde `_delete`).
- WWII olayları ve ülke ağaçları olmasın: `--blank <id> common/events.json` VE `--blank <id> common/focuses.json`.
- Aynı dosyanın hem tam kopyası hem yaması olmaz (araç ve `--check` durdurur).
- WWII'de karşılığı olmayan veri (salgın, yeni tablo...): `data/modes/<id>/own/<ad>.json`; kural betiğinde
  `GameModes.load_own("<ad>.json")`. Sayıları koda sabit yazma.
- `data/common/` altındaki dosyaları mod için DEĞİŞTİRME.
- Motorun başvurduğu anahtarlar README'deki "Mod sözleşmesi" tablosunda; silme.

## 4. Senaryo (isteğe bağlı)
`scenario.json`: `owners` (eyalet → ülke), `capitals` (ülke → eyalet), `vp` (şehir → puan); manifestte `"scenario": "scenario.json"`.

## 5. rules.gd (isteğe bağlı)
- `extends ModeRules`; kanca listesi `game/core/mode_rules.gd`, örnek `game/modes/_template/rules.gd`.
- Yeni etki: `effect_keys` + `apply_effect` + `describe_effect` üçü birden; metni `strings.csv`'ye (EN+TR) ekle.
- Rastgelelik: kendi tohumlu `RandomNumberGenerator`'ın; durumu `to_save`'e `str()` ile yaz.
- Oyuncu adına iş yapma.

## 6. Metinler
Veri içinde `{"en", "tr"}`; kod/arayüz metinleri `game/localization/strings.csv` (EN+TR), ardından `--import`.

## 7. Doğrulama
1. `python3 tools/new_mode.py --check <id>`
2. `$GODOT --headless --path . -s tests/run.gd -- --file=test_mode_<id>` ve `-- --file=test_modes`
3. `$GODOT --headless --path . -s game/dev/country_check.gd -- --game_mode=<id> --days=30`
4. `GODOT=$GODOT tools/run_tests.sh`
Kırmızı test varsa hata metnindeki "nasıl düzeltilir" kısmını uygula; testi atlama ya da kapatma.

## 8. Motor koduna dokunman gerekiyorsa DUR
`game/autoload`, `game/map`, `game/ui`, `game/core` değişikliği modun işi değildir. Ne gerektiğini ve nedenini kullanıcıya
yaz, onay bekle. Onay gelirse WWII denge testini de koş (`tools/balance_parallel.sh 6`, her kontrol en az 5/6).

## 9. Teslim
Ayrı branch + pull request. Açıklamada: ne değişti, koşulan testler ve sonuçları (sayılarla), bilinen sınırlar.
Commit mesajları Türkçe.
