class_name GameModes
extends RefCounted
## Oyun modları: kayıt defteri (data/modes/modes.json), etkin modun manifesti (data/modes/<id>/mode.json) ve veri yolu
## çözümü. Rehber: docs/modlar/README.md.
##
## Saf sınıf: hiçbir autoload'a başvurmaz. Autoload'lar _ready'de, SceneTree betikleri (tests/run.gd, game/dev/*.gd)
## _init'te kullanabilsin diye. Modu değiştirmek (veriyi yeniden yüklemek, kuralları kurmak) Game.switch_mode'un işi.
##
## Veri katmanı: bir mod data/ altındaki herhangi bir JSON'u iki yolla değiştirebilir:
##   data/modes/<id>/common/laws.json        dosyanın TAMAMININ yerine geçer
##   data/modes/<id>/common/laws.patch.json  temel dosyayla derin birleşir (bkz. merge)
## Harita geometrisi (data/map/provinces.json ve dokular) bütün modlarda ortaktır.

const REGISTRY := "res://data/modes/modes.json"
const DATA_ROOT := "res://data/"
const MODES_DIR := "res://data/modes/"
const BASE_MODE := "ww2"
const ID_PATTERN := "^[a-z][a-z0-9_]{1,23}$"

## Manifestte olmayan alanın değeri: bugünkü WWII oyununun sabitleri (tests/test_modes.gd bunları kilitler)
const DEFAULTS := {
	"hidden": false,
	"start_date": "1936-01-01",
	"end_date": "1948-01-01",
	"start_tension": 0.0,
	"default_player": "TUR",
	"featured": ["GER", "ENG", "FRA", "ITA", "SOV", "TUR", "POL", "SPR"],
	"playable": "all",
	"menu_focus": "GER",
	"majors": ["GER", "ENG", "FRA", "ITA", "SOV"],
	"start_techs": ["infantry_weapons_1", "artillery_1", "industry_1", "radio"],
	"start_techs_min_population": 15000000,
	"scenario": "",
	"rules": "",
}
const SUB_DEFAULTS := {
	"ai": {"rearm_year": 1939, "cautious_until": "1942-01-01", "phoney_war_days": 270, "major_hold_fire_days": 240},
	"combat": {"phoney_war_days": 270},
}
## Metin alanı manifestte {en, tr} olarak yoksa okunan çeviri anahtarı (strings.csv)
const TEXT_KEYS := {"subtitle": "MENU_SUBTITLE", "welcome": "NOTE_WELCOME", "end_text": "GAMEOVER_TIME"}

static var id: String = ""                    ## etkin mod
static var manifest: Dictionary = {}          ## etkin modun manifesti
static var _registry: Dictionary = {}
static var _info_cache: Dictionary = {}
static var _majors: Dictionary = {}

static func _static_init() -> void:
	var want := ""
	for a: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--game_mode="):
			want = a.get_slice("=", 1)
	if want == "" or not exists(want):
		if want != "":
			push_warning("Oyun modu bulunamadı: '%s' — varsayılan mod açılıyor" % want)
		want = default_id()
	set_current(want)

# ------------------------------------------------------------------ kayıt defteri
static func _reg() -> Dictionary:
	if _registry.is_empty():
		var v: Variant = _parse(REGISTRY)
		_registry = v if v is Dictionary else {"default": BASE_MODE, "modes": [BASE_MODE]}
	return _registry

static func default_id() -> String:
	return str(_reg().get("default", BASE_MODE))

## Kayıtlı modlar (modes.json sırası = menü sırası). Gizli modlar (ör. _template) yalnız istenirse.
static func ids(include_hidden: bool = false) -> Array[String]:
	var out: Array[String] = []
	for m: Variant in _reg().get("modes", []):
		var mid := str(m)
		if include_hidden or not bool(info(mid).get("hidden", false)):
			out.append(mid)
	return out

static func exists(mode_id: String) -> bool:
	return mode_id in ids(true) and FileAccess.file_exists(MODES_DIR + mode_id + "/mode.json")

## Bir modun manifesti (yoksa ya da bozuksa boş sözlük)
static func info(mode_id: String) -> Dictionary:
	if not _info_cache.has(mode_id):
		var v: Variant = _parse(MODES_DIR + mode_id + "/mode.json")
		_info_cache[mode_id] = v if v is Dictionary else {}
	return _info_cache[mode_id]

## Etkin modu ayarlar (yalnız kimlik ve manifest; veriyi yeniden yüklemez — bunu Game.switch_mode yapar)
static func set_current(mode_id: String) -> bool:
	if not exists(mode_id):
		push_error("Oyun modu kayıtlı değil: '%s' (data/modes/modes.json)" % mode_id)
		return false
	var m := info(mode_id)
	if m.is_empty():
		push_error("Oyun modu manifesti okunamadı: %s%s/mode.json" % [MODES_DIR, mode_id])
		return false
	id = mode_id
	manifest = m
	_majors.clear()
	for t: Variant in get_value("majors", DEFAULTS["majors"]):
		_majors[str(t)] = true
	return true

## Test ve araçlar: önbellekleri boşalt (mod dosyaları diskte değiştiyse)
static func clear_cache() -> void:
	_registry.clear()
	_info_cache.clear()

# ------------------------------------------------------------------ veri yolu
## res://data/X → modda data/modes/<id>/X varsa o, yoksa res://data/X
static func path(base_path: String) -> String:
	if id == "" or not base_path.begins_with(DATA_ROOT):
		return base_path
	var p := MODES_DIR + id + "/" + base_path.substr(DATA_ROOT.length())
	return p if FileAccess.file_exists(p) else base_path

## JSON oku: path() + varsa <X>.patch.json birleştirmesi. Patch yoksa bugünkü okumayla birebir aynı.
static func load_json(base_path: String) -> Variant:
	var v: Variant = _parse(path(base_path))
	var pp := patch_path(base_path)
	if pp != "" and FileAccess.file_exists(pp):
		v = merge(v, _parse(pp))
	return v

## res://data/common/laws.json → res://data/modes/<id>/common/laws.patch.json
static func patch_path(base_path: String) -> String:
	if id == "" or not base_path.begins_with(DATA_ROOT):
		return ""
	return MODES_DIR + id + "/" + base_path.substr(DATA_ROOT.length()).get_basename() + ".patch.json"

static func _parse(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))

## Derin birleştirme (patch kuralları, docs/modlar/README.md):
## - sözlükler özyinelemeli birleşir; değer null ise anahtar silinir; yeni anahtarlar sona eklenir
## - öğeleri "id" taşıyan diziler kimliğe göre birleşir: yeni kimlik sona eklenir, {"id": x, "_delete": true} siler
## - diğer diziler ve değerler olduğu gibi değiştirilir
static func merge(base: Variant, patch: Variant) -> Variant:
	if base is Dictionary and patch is Dictionary:
		var out: Dictionary = (base as Dictionary).duplicate()
		for k: Variant in patch:
			var pv: Variant = patch[k]
			if pv == null:
				out.erase(k)
			elif out.has(k):
				out[k] = merge(out[k], pv)
			else:
				out[k] = pv
		return out
	if base is Array and patch is Array and _id_list(base) and _id_list(patch):
		var out: Array = (base as Array).duplicate()
		var at := {}
		for i in out.size():
			at[str(out[i]["id"])] = i
		var removed := {}
		for item: Dictionary in patch:
			var key := str(item["id"])
			if bool(item.get("_delete", false)):
				removed[key] = true
			elif at.has(key):
				out[at[key]] = merge(out[at[key]], item)
			else:
				at[key] = out.size()
				out.append(item)
		if not removed.is_empty():
			var kept: Array = []
			for item: Dictionary in out:
				if not removed.has(str(item["id"])):
					kept.append(item)
			out = kept
		return out
	return patch

static func _id_list(a: Array) -> bool:
	for x: Variant in a:
		if not (x is Dictionary and (x as Dictionary).has("id")):
			return false
	return not a.is_empty()

# ------------------------------------------------------------------ manifest değerleri
static func get_value(key: String, fallback: Variant = null) -> Variant:
	if manifest.has(key):
		return manifest[key]
	return DEFAULTS.get(key, fallback)

## ai / combat alt bölümleri
static func sub(section: String, key: String) -> Variant:
	var d: Variant = manifest.get(section, {})
	if d is Dictionary and (d as Dictionary).has(key):
		return d[key]
	return SUB_DEFAULTS.get(section, {}).get(key)

## Etkin modun metni: manifestte {en, tr} varsa etkin dilde, yoksa çeviri anahtarı (<alan>_key ya da TEXT_KEYS)
static func text(field: String) -> String:
	return text_of(id, field)

static func text_of(mode_id: String, field: String) -> String:
	var m := info(mode_id)
	var d: Variant = m.get(field)
	if d is Dictionary:
		var loc := TranslationServer.get_locale().substr(0, 2)
		return str((d as Dictionary).get(loc, (d as Dictionary).get("en", "")))
	var key := str(m.get(field + "_key", TEXT_KEYS.get(field, "")))
	return str(TranslationServer.translate(key)) if key != "" else ""

## [yıl, ay, gün]
static func start_date() -> Array[int]:
	return _ymd(str(get_value("start_date")))

## YYYYMMDD; 0 = süre sınırı yok
static func end_date_int() -> int:
	var s := str(get_value("end_date"))
	if s == "":
		return 0
	var a := _ymd(s)
	return a[0] * 10000 + a[1] * 100 + a[2]

## "YYYY-MM-DD" → YYYYMMDD; "" → 0
static func date_int(s: String) -> int:
	if s == "":
		return 0
	var a := _ymd(s)
	return a[0] * 10000 + a[1] * 100 + a[2]

static func _ymd(s: String) -> Array[int]:
	var p := s.split("-")
	return [int(p[0]), int(p[1]) if p.size() > 1 else 1, int(p[2]) if p.size() > 2 else 1]

static func default_player() -> String:
	return str(get_value("default_player"))

static func featured() -> Array:
	return get_value("featured")

## Manifestteki "playable": "all" ya da etiket listesi (ülkenin haritada var olup olmadığına World bakar)
static func is_playable_tag(tag: String) -> bool:
	var p: Variant = get_value("playable")
	return not (p is Array) or tag in p

static func is_major(tag: String) -> bool:
	return _majors.has(tag)

static func start_techs() -> Array:
	return get_value("start_techs")

static func start_techs_min_population() -> int:
	return int(get_value("start_techs_min_population"))

## Başlangıç sahiplik/başkent/zafer puanı katmanı: {"owners": {state_id: TAG}, "capitals": {TAG: state_id}, "vp": {city_id: int}}
static func scenario() -> Dictionary:
	var f := str(get_value("scenario"))
	if f == "":
		return {}
	var v: Variant = _parse(MODES_DIR + id + "/" + f)
	return v if v is Dictionary else {}

static func rules_path() -> String:
	return str(get_value("rules"))

# ------------------------------------------------------------------ kayıt yuvaları
## ww2 kayıt adları değişmez; diğer modlarda yuva adı "<id>_" ile başlar
static func save_prefix() -> String:
	return "" if id == BASE_MODE else id + "_"

## Yuva adından mod: ilk "_"a kadarki parça kayıtlı bir modsa o, değilse ww2 (ülke etiketleri büyük harftir)
static func slot_mode(slot: String) -> String:
	var head := slot.get_slice("_", 0)
	if head != slot and head == head.to_lower() and exists(head):
		return head
	return BASE_MODE

# ------------------------------------------------------------------ doğrulama (tests/test_modes.gd, tools/new_mode.py --check)
## İnsan dilinde sorun listesi: "mod: dosya: ne yanlış — nasıl düzeltilir"
static func validate(mode_id: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(ID_PATTERN)
	if mode_id != "_template" and re.search(mode_id) == null:
		out.append("%s: kimlik küçük harf, rakam ve _ olmalı (2–24 karakter, harfle başlar)" % mode_id)
	var mpath := MODES_DIR + mode_id + "/mode.json"
	if not FileAccess.file_exists(mpath):
		out.append("%s: mode.json yok — %s oluştur (tools/new_mode.py %s)" % [mode_id, mpath, mode_id])
		return out
	var v: Variant = _parse(mpath)
	if not (v is Dictionary):
		out.append("%s: mode.json geçerli bir JSON nesnesi değil — virgül/tırnak hatasına bak" % mode_id)
		return out
	var m: Dictionary = v
	if str(m.get("id", "")) != mode_id:
		out.append("%s: mode.json \"id\" alanı klasör adıyla aynı olmalı (şu an '%s')" % [mode_id, m.get("id", "")])
	for f: String in ["name", "description", "subtitle", "welcome", "end_text"]:
		if not m.has(f):
			if f == "name":
				out.append("%s: \"name\" zorunlu: {\"en\": ..., \"tr\": ...}" % mode_id)
			continue
		var d: Variant = m[f]
		if not (d is Dictionary) or str(d.get("en", "")) == "" or str(d.get("tr", "")) == "":
			out.append("%s: \"%s\" hem \"en\" hem \"tr\" metni istiyor (CLAUDE.md kural 3)" % [mode_id, f])
		elif str(d["en"]).count("%s") != str(d["tr"]).count("%s"):
			out.append("%s: \"%s\" İngilizce ve Türkçe metinde %%s sayısı farklı" % [mode_id, f])
	for f: String in ["start_date", "end_date"]:
		if m.has(f) and str(m[f]) != "" and not RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(str(m[f])):
			out.append("%s: \"%s\" YYYY-AA-GG biçiminde olmalı (şu an '%s')" % [mode_id, f, m[f]])
	var sd := date_int(str(m.get("start_date", DEFAULTS["start_date"])))
	var ed := date_int(str(m.get("end_date", DEFAULTS["end_date"])))
	if ed != 0 and ed <= sd:
		out.append("%s: end_date start_date'ten sonra olmalı" % mode_id)
	for k: String in m:
		if not (k in DEFAULTS or k in SUB_DEFAULTS or k in ["id", "name", "description", "subtitle", "welcome", "end_text",
				"subtitle_key", "welcome_key", "end_text_key", "_comment"]):
			out.append("%s: mode.json bilinmeyen alan '%s' — yazım hatası mı? (alanlar: docs/modlar/README.md)" % [mode_id, k])
	for sec: String in SUB_DEFAULTS:
		if m.has(sec):
			for k: String in m[sec]:
				if not SUB_DEFAULTS[sec].has(k):
					out.append("%s: \"%s\" içinde bilinmeyen alan '%s'" % [mode_id, sec, k])
	var rules := str(m.get("rules", ""))
	if rules != "":
		if not rules.begins_with("res://game/modes/"):
			out.append("%s: \"rules\" res://game/modes/<id>/rules.gd altında olmalı (data/ altındaki .gd yüklenmez)" % mode_id)
		elif not ResourceLoader.exists(rules):
			out.append("%s: kural betiği bulunamadı: %s" % [mode_id, rules])
	var sc := str(m.get("scenario", ""))
	if sc != "" and not FileAccess.file_exists(MODES_DIR + mode_id + "/" + sc):
		out.append("%s: senaryo dosyası yok: %s" % [mode_id, sc])
	_check_files(mode_id, MODES_DIR + mode_id + "/", "", out)
	return out

static func _check_files(mode_id: String, root: String, rel: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root + rel)
	if dir == null:
		return
	for sub_dir: String in dir.get_directories():
		if rel == "" and sub_dir == "map":
			out.append("%s: map/ klasörü desteklenmiyor — harita bütün modlarda ortak (docs/modlar/README.md)" % mode_id)
			continue
		_check_files(mode_id, root, rel + sub_dir + "/", out)
	for f: String in dir.get_files():
		var r := rel + f
		if r == "mode.json" or (rel == "" and f == str(info(mode_id).get("scenario", ""))):
			continue
		if not f.ends_with(".json"):
			out.append("%s: %s — mod klasöründe yalnız .json olur (.gd → game/modes/%s/, metin → strings.csv, görsel yok)" % [mode_id, r, mode_id])
			continue
		var base: String = r.trim_suffix(".patch.json") + ".json" if f.ends_with(".patch.json") else r
		if not FileAccess.file_exists(DATA_ROOT + base):
			out.append("%s: %s — data/%s yok; mod yalnız var olan veri dosyalarını değiştirebilir (yazım hatası mı?)" % [mode_id, r, base])
