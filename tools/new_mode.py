#!/usr/bin/env python3
"""Oyun modu aracı (yalnız Python standart kitaplığı; Godot gerekmez). Rehber: docs/modlar/README.md

  python3 tools/new_mode.py <kimlik> [--name-en ".."] [--name-tr ".."] [--desc-en ".."] [--desc-tr ".."]
        Yeni mod iskeleti: data/modes/<kimlik>/mode.json, game/modes/<kimlik>/rules.gd,
        tests/test_mode_<kimlik>.gd; modu data/modes/modes.json'a ekler.
  python3 tools/new_mode.py --check [<kimlik>]
        Hızlı denetim (Godot'suz): JSON geçerli mi, zorunlu alanlar, İngilizce+Türkçe metin, tarihler, yasak dosya
        türleri, yazım hatası olan dosya adları (GameModes.validate ile aynı kurallar). Kimlik verilmezse bütün modlar.
  python3 tools/new_mode.py --copy <kimlik> common/<dosya>.json
        Temel veri dosyasını moda kopyalar (dosyanın TAMAMI modda değişecekse).
  python3 tools/new_mode.py --blank <kimlik> common/events.json|common/focuses.json
        WWII olaylarını / ülke program ağaçlarını kaldıran bir patch yazar (motorun kendi olayları ve _generic ağacı kalır).
  python3 tools/new_mode.py --remove <kimlik> --yes
        Modu kayıttan ve diskten siler.
"""
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
MODES = DATA / "modes"
REGISTRY = MODES / "modes.json"
ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,23}$")
ENGINE_EVENTS = ["call_to_arms", "white_peace", "election", "faction_invite"]
KNOWN_FIELDS = {"_comment", "id", "hidden", "name", "description", "subtitle", "welcome", "end_text", "subtitle_key",
                "welcome_key", "end_text_key", "start_date", "end_date", "start_tension", "default_player", "featured",
                "playable", "menu_focus", "majors", "start_techs", "start_techs_min_population", "scenario", "rules",
                "ai", "combat"}
TEXT_FIELDS = ["name", "description", "subtitle", "welcome", "end_text"]
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SUB_KNOWN = {"ai": {"rearm_year", "cautious_until", "phoney_war_days", "major_hold_fire_days"},
             "combat": {"phoney_war_days"}}
DEFAULT_DATES = {"start_date": "1936-01-01", "end_date": "1948-01-01"}
OWN_DIR = "own"          # modun kendi veri dosyaları: temel veride karşılığı aranmaz (GameModes.load_own)


def load(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


def dump(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def registry() -> dict:
    return load(REGISTRY)


def die(msg: str) -> None:
    print("HATA: " + msg)
    sys.exit(1)


def valid_date(s: str) -> bool:
    """YYYY-AA-GG ve takvimde var olan gün (GameModes.valid_date ile aynı)"""
    if not DATE_RE.match(s):
        return False
    y, m, d = (int(x) for x in s.split("-"))
    if not 1 <= m <= 12 or d < 1:
        return False
    leap = y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)
    dim = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    return d <= dim


def mode_dir(mid: str, must_exist: bool = True) -> Path:
    """Kimliği doğrula ve mod klasörünü döndür ('.', '..', 'ww2/' gibi girdiler reddedilir)"""
    if mid != "_template" and not ID_RE.match(mid):
        die(f"geçersiz kimlik '{mid}' (küçük harf, rakam ve _; harfle başlar)")
    folder = MODES / mid
    if folder.resolve().parent != MODES.resolve():
        die(f"geçersiz kimlik '{mid}'")
    if must_exist and not (folder / "mode.json").exists():
        die(f"'{mid}' modu yok (önce: python3 tools/new_mode.py {mid})")
    return folder


# ---------------------------------------------------------------- yeni mod
def new_mode(mid: str, opts: dict) -> None:
    if not ID_RE.match(mid):
        die("kimlik küçük harf, rakam ve _ olmalı, harfle başlamalı (2–24 karakter): örn. zombie, cold_war")
    reg = registry()
    if mid in reg["modes"] or (MODES / mid).exists():
        die(f"'{mid}' zaten var")
    name_en = opts.get("name-en", mid.replace("_", " ").title())
    name_tr = opts.get("name-tr", name_en)
    manifest = {
        "_comment": "Alanların anlamı: docs/modlar/README.md. Yazmadığın alan WWII değerini alır. Menüde görünmesin "
                    "istersen \"hidden\": true yap. Önce docs/OZGUNLUK.md.",
        "id": mid,
        "hidden": False,
        "name": {"en": name_en, "tr": name_tr},
        "description": {"en": opts.get("desc-en", "TODO: one sentence about this mode."),
                        "tr": opts.get("desc-tr", "YAPILACAK: bu modu anlatan bir cümle.")},
        "start_date": "1936-01-01",
        "end_date": "1948-01-01",
        "default_player": "TUR",
        "scenario": "",
        "rules": f"res://game/modes/{mid}/rules.gd",
    }
    dump(MODES / mid / "mode.json", manifest)
    rules = ROOT / "game" / "modes" / mid / "rules.gd"
    rules.parent.mkdir(parents=True, exist_ok=True)
    rules.write_text(RULES_SKELETON.replace("<ID>", mid), encoding="utf-8")
    test = ROOT / "tests" / f"test_mode_{mid}.gd"
    test.write_text(TEST_SKELETON.replace("<ID>", mid), encoding="utf-8")
    reg["modes"].append(mid)
    dump(REGISTRY, reg)
    print(f"""Mod oluşturuldu: {mid}
  data/modes/{mid}/mode.json        manifest (ad, tarihler, oyuncu, kurallar)
  game/modes/{mid}/rules.gd         kod kancaları (isteğe bağlı)
  tests/test_mode_{mid}.gd          modun testleri (veri bütünlüğü + duman testi)
  data/modes/modes.json             kayda eklendi

Sonraki adımlar:
  0. Önce docs/OZGUNLUK.md (başka oyundan ad/metin/sayı alma).
  1. mode.json'u düzenle (açıklama, tarih, oyuncu). Metinler hep İngilizce + Türkçe.
  2. Veri değiştir: tam dosya  → python3 tools/new_mode.py --copy {mid} common/<dosya>.json
                    kısmi      → data/modes/{mid}/common/<dosya>.patch.json (bkz. data/modes/_template)
                    WWII olayları olmasın → python3 tools/new_mode.py --blank {mid} common/events.json
                                            python3 tools/new_mode.py --blank {mid} common/focuses.json
                    modun kendi verisi (WWII'de karşılığı yok) → data/modes/{mid}/own/<ad>.json,
                                            kural betiğinde GameModes.load_own("<ad>.json")
  3. Denetle: python3 tools/new_mode.py --check {mid}
  4. Oyunda aç: godot --path . -- --game_mode={mid}   (ya da menüde Yeni Oyun → mod)
  5. Testler: godot --headless --path . -s tests/run.gd -- --file=test_mode_{mid}
              godot --headless --path . -s tests/run.gd -- --file=test_modes
              godot --headless --path . -s game/dev/country_check.gd -- --game_mode={mid} --days=30
  6. Ayrı branch + pull request; açıklamaya test sayılarını yaz.""")


RULES_SKELETON = '''extends ModeRules
## <ID> modunun kural betiği. Kancaların hepsi isteğe bağlı: kullanmadığını sil.
## Çağrılma sırası ve kurallar: game/core/mode_rules.gd, docs/modlar/README.md. Örnek: game/modes/_template/rules.gd.
## Oyuncu adına iş yapma (CLAUDE.md kural 1); yeni etki eklersen apply_effect + describe_effect ikisine birden (kural 2).

func on_new_game() -> void:
	pass

func on_day() -> void:
	pass

## Oyun sonu: {} = devam; {"victory": bool, "reason": "<strings.csv anahtarı>"}
func check_end() -> Dictionary:
	return {}

## Kayda yazılacak mod durumu (büyük tamsayıları str() ile yaz)
func to_save() -> Dictionary:
	return {}

func from_save(_d: Dictionary) -> void:
	pass
'''

TEST_SKELETON = '''extends "res://tests/test_data.gd"
## <ID> modu: test_data.gd'nin bütün veri bütünlüğü denetimleri bu modun birleşik verisiyle koşar; aşağıya moda özgü
## testler eklenir (örnekler: tests/test_mode_template.gd). Koş: godot --headless --path . -s tests/run.gd -- --file=test_mode_<ID>

func mode() -> String:
	return "<ID>"

## Duman testi: mod açılır ve 30 gün hatasız ilerler
func test_<ID>_runs_30_days() -> void:
	eq(GameModes.id, "<ID>", "etkin mod")
	days(30)
	check(not Game.over, "30 günde oyun bitmedi")
'''


# ---------------------------------------------------------------- denetim
def check(mids) -> int:
    reg = registry()
    problems = []
    if reg.get("default") not in reg.get("modes", []):
        problems.append("modes.json: \"default\" modes listesinde değil")
    for d in sorted(p.name for p in MODES.iterdir() if p.is_dir()):
        if d not in reg["modes"]:
            problems.append(f"data/modes/{d}: modes.json'da kayıtlı değil")
    for mid in mids:
        problems += check_one(mid, reg)
    for mid in mids:
        try:
            if not mid.startswith("_") and load(MODES / mid / "mode.json").get("hidden") is True:
                print(f"bilgi: {mid} gizli (\"hidden\": true) — menüde görünmez; hazır olunca false yap")
        except (OSError, json.JSONDecodeError):
            pass
    if problems:
        print(f"{len(problems)} sorun:")
        for p in problems:
            print("  - " + p)
        return 1
    print(f"Sorun yok ({', '.join(mids)}).")
    return 0


def check_one(mid: str, reg: dict) -> list:
    out = []
    folder = MODES / mid
    if mid != "_template" and not ID_RE.match(mid):
        return [f"{mid}: kimlik küçük harf, rakam ve _ olmalı (2–24 karakter, harfle başlar)"]
    if mid not in reg["modes"]:
        out.append(f"{mid}: modes.json'da kayıtlı değil")
    mpath = folder / "mode.json"
    if not mpath.exists():
        return out + [f"{mid}: {mpath.relative_to(ROOT)} yok"]
    try:
        m = load(mpath)
    except json.JSONDecodeError as e:
        return out + [f"{mid}: mode.json bozuk JSON (satır {e.lineno}, sütun {e.colno}: {e.msg})"]
    if m.get("id") != mid:
        out.append(f"{mid}: mode.json \"id\" klasör adıyla aynı olmalı")
    for k in m:
        if k not in KNOWN_FIELDS:
            out.append(f"{mid}: mode.json bilinmeyen alan '{k}' (yazım hatası mı?)")
    if "name" not in m:
        out.append(f"{mid}: \"name\" zorunlu")
    for f in TEXT_FIELDS:
        if f in m:
            d = m[f]
            if not isinstance(d, dict) or not d.get("en") or not d.get("tr"):
                out.append(f"{mid}: \"{f}\" hem \"en\" hem \"tr\" metni istiyor")
            elif f == "welcome":
                for lang in ("en", "tr"):
                    t = str(d[lang]).replace("%%", "")
                    if t.count("%s") != 1 or "%" in t.replace("%s", ""):
                        out.append(f"{mid}: \"welcome\" ({lang}) tam bir %s içermeli (oyuncunun ülke adı); yüzde işaretini %% yaz")
            elif d["en"].count("%s") != d["tr"].count("%s"):
                out.append(f"{mid}: \"{f}\" İngilizce ve Türkçe metinde %s sayısı farklı")
    for f in ("start_date", "end_date"):
        if f not in m or (f == "end_date" and m[f] == ""):
            continue
        if not valid_date(str(m[f])):
            out.append(f"{mid}: \"{f}\" takvimde var olan bir YYYY-AA-GG tarihi olmalı (şu an '{m[f]}')")
    sd = str(m.get("start_date", DEFAULT_DATES["start_date"]))
    ed = str(m.get("end_date", DEFAULT_DATES["end_date"]))
    if valid_date(sd) and valid_date(ed) and ed <= sd:
        out.append(f"{mid}: end_date start_date'ten sonra olmalı (yoksa oyun ilk gün biter)")
    for sec, known in SUB_KNOWN.items():
        if sec not in m:
            continue
        if not isinstance(m[sec], dict):
            out.append(f"{mid}: \"{sec}\" bir nesne olmalı: {{\"alan\": değer}}")
            continue
        for k in m[sec]:
            if k not in known:
                out.append(f"{mid}: \"{sec}\" içinde bilinmeyen alan '{k}' (alanlar: {', '.join(sorted(known))})")
    cu = m.get("ai", {}).get("cautious_until", "") if isinstance(m.get("ai"), dict) else ""
    if cu and not valid_date(str(cu)):
        out.append(f"{mid}: \"ai.cautious_until\" takvimde var olan bir YYYY-AA-GG tarihi olmalı")
    rules = m.get("rules", "")
    if rules:
        if not rules.startswith("res://game/modes/"):
            out.append(f"{mid}: \"rules\" res://game/modes/<id>/rules.gd altında olmalı")
        elif not (ROOT / rules.replace("res://", "")).exists():
            out.append(f"{mid}: kural betiği yok: {rules}")
    sc = m.get("scenario", "")
    if sc:
        if not (folder / sc).exists():
            out.append(f"{mid}: senaryo dosyası yok: {sc}")
        else:
            try:
                sv = load(folder / sc)
                if not isinstance(sv, dict):
                    out.append(f"{mid}: {sc} bir JSON nesnesi olmalı")
                else:
                    for k in sv:
                        if k not in ("owners", "capitals", "vp", "_comment"):
                            out.append(f"{mid}: {sc} bilinmeyen alan '{k}' (owners, capitals, vp)")
            except json.JSONDecodeError as e:
                out.append(f"{mid}: {sc} bozuk JSON (satır {e.lineno}, sütun {e.colno}: {e.msg})")
    for p in sorted(folder.rglob("*")):
        parts = p.relative_to(folder).parts
        if any(x.startswith(".") for x in parts):
            continue                                    # gizli dosyalar (.DS_Store vb.): Godot da görmez
        if p.is_dir():
            if parts[0] == "map" and len(parts) == 1:
                out.append(f"{mid}: map/ desteklenmiyor (harita bütün modlarda ortak)")
            continue
        rel = p.relative_to(folder).as_posix()
        if rel == "mode.json" or rel == sc:
            continue
        if p.suffix != ".json":
            out.append(f"{mid}: {rel} — mod klasöründe yalnız .json olur")
            continue
        try:
            load(p)
        except json.JSONDecodeError as e:
            out.append(f"{mid}: {rel} bozuk JSON (satır {e.lineno}, sütun {e.colno}: {e.msg})")
            continue
        if parts[0] == OWN_DIR:
            continue                                    # modun kendi verisi (GameModes.load_own)
        base = rel[: -len(".patch.json")] + ".json" if rel.endswith(".patch.json") else rel
        if not (DATA / base).exists():
            out.append(f"{mid}: {rel} — data/{base} yok (yazım hatası mı? örn. comon/ → common/; kendi verin own/ altına)")
        elif not rel.endswith(".patch.json") and (folder / (rel[:-5] + ".patch.json")).exists():
            out.append(f"{mid}: {rel} ve {rel[:-5]}.patch.json birlikte olmaz — yama moddaki tam dosyanın üzerine uygulanır; birini seç")
    ev = folder / "common" / "events.patch.json"
    if ev.exists():
        try:
            patch = load(ev).get("events", {})
            for e in ENGINE_EVENTS:
                if e in patch and patch[e] is None:
                    out.append(f"{mid}: events.patch.json '{e}' olayını siliyor — motor bu olayı kendisi açar")
        except json.JSONDecodeError:
            pass
    return out


# ---------------------------------------------------------------- kopya / boş patch / silme
def copy(mid: str, rel: str) -> None:
    folder = mode_dir(mid)
    rp = Path(rel)
    if rp.is_absolute() or ".." in rp.parts or not rel.endswith(".json"):
        die(f"'{rel}' geçersiz: data/ altındaki bir .json yolu ver (örn. common/laws.json)")
    src = DATA / rel
    if not src.exists() or rel.startswith("modes/") or rel.startswith("map/"):
        die(f"data/{rel} kopyalanamaz (yok ya da harita/mod dosyası)")
    dst = folder / rel
    if dst.exists():
        die(f"{dst.relative_to(ROOT)} zaten var")
    pp = folder / (rel[:-5] + ".patch.json")
    if pp.exists():
        die(f"{pp.relative_to(ROOT)} var: yama, kopyalanan tam dosyanın ÜZERİNE uygulanır (içindeki null'lar kopyadaki "
            f"kayıtları siler). Önce yamayı sil ya da değişikliklerini kopyaya işle, sonra --copy'yi yeniden koş.")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    print(f"Kopyalandı: {dst.relative_to(ROOT)} (bu dosya artık temel dosyanın TAMAMININ yerine geçer)")


def blank(mid: str, rel: str) -> None:
    folder = mode_dir(mid)
    if (folder / rel).exists():
        die(f"{(folder / rel).relative_to(ROOT)} (tam kopya) var: yama onun üzerine uygulanırdı. Kopyadan kayıtları "
            f"elle sil ya da kopyayı kaldırıp --blank'i yeniden koş.")
    if rel == "common/events.json":
        base = load(DATA / rel)["events"]
        patch = {"events": {k: None for k in base if k not in ENGINE_EVENTS}}
        note = f"{len(patch['events'])} WWII olayı kaldırıldı; motor olayları kaldı: {', '.join(ENGINE_EVENTS)}"
    elif rel == "common/focuses.json":
        base = load(DATA / rel)["trees"]
        patch = {"trees": {k: None for k in base if k != "_generic"}}
        note = f"{len(patch['trees'])} ülke ağacı kaldırıldı; _generic kaldı (kendi ağacı olmayan ülkeler kullanır)"
    else:
        die("--blank yalnız common/events.json ve common/focuses.json için")
    patch = {"_comment": "tools/new_mode.py --blank ile üretildi: " + note, **patch}
    dst = folder / (rel[:-5] + ".patch.json")
    if dst.exists():
        die(f"{dst.relative_to(ROOT)} zaten var")
    dump(dst, patch)
    print(f"Yazıldı: {dst.relative_to(ROOT)} — {note}")
    if rel == "common/events.json" and not (folder / "common" / "focuses.patch.json").exists():
        refs = sorted({e for tree in load(DATA / "common/focuses.json")["trees"].values() for f in tree
                       for eff in f.get("effects", []) for k, e in eff.items() if k == "event" and e in patch["events"]})
        if refs:
            print(f"UYARI: WWII program ağaçları kaldırılan {len(refs)} olaya başvuruyor ({', '.join(refs[:5])}...).")
            print(f"       Ağaçları da kaldır: python3 tools/new_mode.py --blank {mid} common/focuses.json")


def remove(mid: str) -> None:
    if mid in ("ww2", "_template"):
        die(f"'{mid}' silinemez")
    mode_dir(mid, must_exist=False)
    reg = registry()
    if mid not in reg["modes"] and not (MODES / mid).is_dir() and not (ROOT / "game" / "modes" / mid).is_dir():
        die(f"'{mid}' diye bir mod yok")
    if mid in reg["modes"]:
        reg["modes"].remove(mid)
    if reg.get("default") == mid:
        reg["default"] = "ww2"
        print("not: varsayılan mod ww2'ye döndü")
    dump(REGISTRY, reg)
    for p in (MODES / mid, ROOT / "game" / "modes" / mid):
        if p.exists():
            shutil.rmtree(p)
    for t in (ROOT / "tests" / f"test_mode_{mid}.gd", ROOT / "tests" / f"test_mode_{mid}.gd.uid"):
        if t.exists():
            t.unlink()
    print(f"Silindi: {mid}")


def main(argv) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "--check":
        return check(argv[1:] or registry()["modes"])
    if argv[0] == "--copy" and len(argv) == 3:
        copy(argv[1], argv[2])
        return 0
    if argv[0] == "--blank" and len(argv) == 3:
        blank(argv[1], argv[2])
        return 0
    if argv[0] == "--remove" and len(argv) >= 2:
        if "--yes" not in argv:
            die("silmek için --yes ekle")
        remove(argv[1])
        return 0
    if argv[0].startswith("--"):
        print(__doc__)
        return 2
    opts = {}
    it = iter(argv[1:])
    for a in it:
        if a.startswith("--"):
            opts[a[2:]] = next(it, "")
    new_mode(argv[0], opts)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
