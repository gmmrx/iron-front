[English](CLAUDE.md) · **Türkçe** (Claude Code İngilizce `CLAUDE.md`yi okur; bu dosya insanlar için)

# Iron Front — Claude Code çalışma kuralları

1936–1948 arası geçen, 82 ülkeyle oynanabilen bir 2. Dünya Savaşı büyük strateji oyunu. Godot 4.7.2, GDScript,
veri güdümlü (`data/common/*.json`). Web sürümü: https://gmmrx.github.io/iron-front/ (main'e her push'ta yeniden yayınlanır).
Oyun wikisi: `docs/wiki/` (Türkçesi `docs/wiki/tr/`), yol haritası: `ROADMAP.md` (Türkçesi `ROADMAP.tr.md`).
**Oyun tasarımı kuralları: `docs/DESIGN.md`** (Türkçesi `docs/TASARIM.md`). Oyun 1936'dan sonu açık serbest oyun (yalnız
savaşın katılımcıları, senaryo yok); o sayfanın
izin vermediği hiçbir şey yapılmaz.
Kullanıcıyla Türkçe konuş. Oyunun ve belgelerin ana dili İngilizcedir.

## Kurulum (Linux, ekransız)
```
GODOT_VERSION=4.7.2
BASE=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable
curl -sSL -o godot.zip $BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
unzip -q godot.zip -d ~/godot && mv ~/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 ~/godot/godot
export GODOT=~/godot/godot
$GODOT --headless --path . --import      # bir kez; yeni class_name / çeviri sonrası tekrar
```
Python araçları için: `pip install pillow numpy scipy`.

## Testler (hepsi ekransız)
| Komut | Ne ölçer |
|---|---|
| `GODOT=$GODOT tools/run_tests.sh` | içe aktarma + `tests/run.gd` + country_check (60 gün); CI'daki iş budur |
| `$GODOT --headless --path . -s tests/run.gd [-- --file=test_data]` | test paketi (`tests/test_*.gd`, her test temiz oyunla; yazım: `docs/wiki/08_developer.md`) |
| `$GODOT --headless --path . -s game/dev/country_check.gd -- --days=150` | 82 ülkenin her biriyle oyuncu eylemleri oyunu etkiliyor mu, oyuncu adına otomatik iş var mı (çıkış kodu 1 = sorun) |
| `GODOT=$GODOT tools/balance_parallel.sh 6` | 1936–1942 tarihî akış, 12 kontrol. Her kontrol en az 5/6 geçmeli |
| `$GODOT --headless --path . -s game/dev/gov_check.gd -- --player=TUR` | 1936 istikrar/savaş desteği, tarihli olaylar, seçimler |
| `$GODOT --headless --path . -s game/dev/playtest.gd` | Türkiye → Irak savaşı, emirler, teslim, kayıt/yükleme |
| `$GODOT --headless --path . -s game/dev/sim.gd` | simülasyon hızı (profil) |
| `$GODOT --headless --path . -s game/dev/fig_check.gd -- --load=war_demo_watch --battle --days=3` | muharebede (ya da `--war=GER,DEN --play=DEN`) figür yerleşimi: üst üste binen figür çiftleri, kayma, sıçrama, dip dibe düşmanlar; ekran görüntüsü için `--focus` yazar |

Denge testi uzun sürer (~15 dk, 6 paralel süreç); oyun mantığını değiştiren her işten sonra koş.

## Değişmez kurallar
1. **Oyuncu her şeye karar verir.** Oyuncu adına hiçbir şey kendiliğinden yapılmaz (ticaret, üretim, atama, geri çekilme,
   hava kanadı...). Otomatik bir kolaylık gerekiyorsa kapalı başlayan, oyuncunun açtığı bir seçenek olur. Yapay zekâ
   ülkeleri otomatik olabilir. Tarihî baskılar ve krizler 2–3 gerçek seçenekli olay olarak gelir.
2. **Veri güdümlü**: içerik `data/common/*.json` içinde; motor kodu içerikten bağımsız. Olay/odak etkileri için var olan
   etki sözlüğünü kullan (`game/autoload/politics.gd` → `apply_effects` ve `describe_effects`). Yeni etki ekliyorsan ikisine de ekle.
3. **Tüm metinler** `game/localization/strings.csv` içinde **İngilizce ve Türkçe**. CSV değişince `--import` gerekir.
   Oyun kayıtlı ayar yoksa İngilizce açılır (`GameSettings.DEFAULT_LANG`); Türkçe Ayarlar → Dil'den seçilir.
4. **Özgünlük (dava riski): önce `docs/ORIGINALITY.md`'yi (Türkçesi `docs/OZGUNLUK.md`) oku.** Başka ticari oyunların adını ya da wiki adreslerini hiçbir
   dosyada anma (kod, yorum, belge, commit mesajı); "türün klasiği gibi", "parite" gibi örtmecelerle de anma. Başka bir
   oyundan ad, metin, sayı tablosu ya da ekran düzeni alma; adlar tarihî ya da bizim, sayılar kendi formülümüzden ve
   gerekçesi yazılı. "Iron Front" çalışma adıdır; oyunun adını metinlere sabit yazma.
5. **Görseli göremezsin**: render, shader, ışık, renk, kamera ve model değişikliği yapma; masaüstü (Forward+) ve web
   (gl_compatibility) görüntüsü bozulmamalı. Arayüz eklemen gerekirse yalnız var olan yardımcıları kullan
   (`game/ui/panel_layout.gd`: `frame`, `fixed`, `info_cells`, `section`, `row`, `row_action`, `table`, `table_row`,
   `small_button`, `progress`, `tile`, `empty`; `UiTheme.skin()`), yeni görsel stil icat etme.
6. **Sanat dosyası indirme ya da üretme** (ikon, portre, resim, ses). İkon/portre adları `tools/make_icon_prompts.py`
   ile listelenir; dosyaları kullanıcı üretir.
7. Dokunma: `docs/reference/`, `topbar.png`, `art/prototypes/`, `tools/blender/dress_survivor.py`, `tools/blender/inspect_survivor.py`.
8. GDScript: tipi belirsiz bir ifadeden `:=` ile değişken çıkarma ("Cannot infer the type" ayrıştırma hatası);
   açık tip yaz (`var x: bool = ...`). Autoload'lar: World, Economy, Politics, Research, Diplomacy, Military, Navy, Air, AI,
   Game, GameClock, Audio.
9. Oyuncunun ülkesi `World.player_tag`; `World.start_game(tag)` oyuncuya özgü varsayılanları (elle ticaret, elle kanat,
   "son askere kadar") ayarlar; kayıttan devamda `World.resume_game(tag)` (tercihler korunur). Kayıt/yükleme: `game/autoload/game.gd` — yeni ülke/tümen alanını kayda ekle.

## İş akışı
- Her görev **ayrı branch + pull request**. **main'e doğrudan push yok** (main'e push web sürümünü yeniden yayınlar).
- PR açıklamasında: ne değişti, hangi testler koştu ve sonuçları (sayılarla), bilinen sınırlar.
- Commit mesajları Türkçe. Yeni mekanik eklediysen `docs/wiki/` ve `docs/wiki/tr/` ilgili sayfalarını, `ROADMAP.md` ve
  `ROADMAP.tr.md` durumunu güncelle.
- **Belgeler iki dilde**: asıl dosya İngilizce (`README.md`, `ROADMAP.md`, `docs/wiki/*.md`, `docs/ORIGINALITY.md`,
  `docs/DESIGN.md`, `docs/cloud/TASKS.md`), Türkçesi yanında (`*.tr.md`, `docs/wiki/tr/`, `docs/OZGUNLUK.md`,
  `docs/TASARIM.md`, `docs/cloud/GOREVLER.md`).
  Birini değiştirirsen ötekini de aynı işte güncelle; her dosyanın başında karşı dile bağlantı var.
