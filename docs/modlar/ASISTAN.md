[English](ASSISTANT.md) · **Türkçe**

# Yapay zekâ asistanına verilecek tek sayfa: bu oyuna mod eklemek

Bu metni asistanına (Claude, ChatGPT, Copilot...) yapıştır; ayrıntı için docs/modlar/README.tr.md.

**Oyun:** Godot 4.7 + GDScript, veri güdümlü 2. Dünya Savaşı büyük strateji oyunu. Modlar motoru değiştirmeden kendi verisini getirir.

**Nereye ne yazılır**
- Manifest: `data/modes/<id>/mode.json` (ad `{en,tr}`, tarihler, oyuncu, `featured`, `playable`, `scenario`, `rules`).
- Veri: `data/modes/<id>/common/<dosya>.json` (dosyanın tamamı) ya da `<dosya>.patch.json` (derin birleştirme; `null` siler;
  `"id"`li dizilerde `{"id": x, "_delete": true}` siler). Yalnız `.json`; harita ortak. Aynı dosyanın hem kopyası hem yaması olmaz.
- Modun kendi verisi (WWII'de karşılığı yok): `data/modes/<id>/own/<ad>.json`; kural betiği `GameModes.load_own("<ad>.json")` ile okur.
- Manifestte `welcome` metni tam bir `%s` (ülke adı) içerir; yüzde işareti `%%`. Tarihler takvimde var olan gün.
- Kod (gerekirse): `game/modes/<id>/rules.gd`, `extends ModeRules`; kancalar: on_new_game, on_game_started, on_day, on_hour,
  on_month, check_end, score, to_save/from_save, effect_keys/apply_effect/describe_effect, condition_keys/check_condition.
- Metin: veri içinde `{"en": "...", "tr": "..."}`; arayüz/kod metni `game/localization/strings.csv` (İngilizce + Türkçe).
- İskelet ve araçlar: `python3 tools/new_mode.py <id>`, `--check`, `--copy <id> common/x.json`, `--blank <id> common/events.json`
  (ayrıca `common/focuses.json`, `common/history.json`: WWII program ağaçları ve tarih çizelgesi).

**Yasaklar**
- `data/common`, `game/autoload`, `game/map`, `game/ui` dosyalarını mod için değiştirme; gerekiyorsa DUR ve insana sor.
- Başka bir oyundan ad, metin, sayı tablosu, ekran düzeni alma; başka ticari oyunu dosyalarda anma (docs/OZGUNLUK.md).
- Oyuncu adına iş yapma (ticaret, üretim, geri çekilme...); krizler 2–3 seçenekli olay olur.
- Görsel/ses dosyası indirme ya da üretme; render/shader/renk/kamera/model değişikliği yapma.
- Motorun kendi olaylarını (`call_to_arms`, `white_peace`, `election`, `faction_invite`) ve `_generic` ağacını silme.

**Bitti demeden önce**
1. `python3 tools/new_mode.py --check <id>`
2. `godot --headless --path . --import` (yeni .gd/CSV eklediysen)
3. `godot --headless --path . -s tests/run.gd -- --file=test_modes` ve `-- --file=test_mode_<id>`
4. `godot --headless --path . -s game/dev/country_check.gd -- --game_mode=<id> --days=30`
5. `GODOT=... tools/run_tests.sh`
6. Ayrı branch + pull request; açıklamada ne değişti, hangi testler, sonuç sayıları, bilinen sınırlar.
