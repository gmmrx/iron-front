extends RefCounted
## Oyun durumunun karşılaştırılabilir anlık görüntüsü (kayıt/yükleme ve belirlenimcilik testleri için).
##   var S := preload("res://tests/snapshot.gd").new();  S.diff_fields(S.take(), S.take())

## Kayıtta tutulmayan, her saat/gün yeniden hesaplanan alanlar
const DERIVED := {
	"Country": ["surrender_progress", "air_losses", "fuel_cap", "naval_strength_cache", "resource_use", "consumer_goods"],
	"Division": ["s", "in_combat"],
	"Fleet": ["in_combat", "submerged"],
	"AirWing": ["losses_today", "kills_today"],
	"ProductionLine": ["last_output", "resource_fraction"],
	"ConstructionProject": ["last_daily", "assigned_factories"],
}

## İki anlık görüntü arasındaki farklar, alana göre toplanmış
func diff_fields(a: Dictionary, b: Dictionary) -> Array:
	var diffs: Array = []
	_diff("", a, b, diffs)
	return _by_field(diffs)

var _all := false

## include_derived: yeniden hesaplanan alanlar da (belirlenimcilik için; kayıt/yüklemede atlanır)
func take(include_derived := false) -> Dictionary:
	_all = include_derived
	var s := {}
	s["tarih"] = [GameClock.year, GameClock.month, GameClock.day, GameClock.hour]
	s["gün"] = World.day_count
	s["gerginlik"] = World.world_tension
	s["oyuncu"] = World.player_tag
	s["kontrol"] = Array(World.controller)
	for c: Country in World.countries.values():
		var o := _obj(c)
		o["states"] = _sorted(c.states)
		s["ülke/" + c.tag] = o
	for d in Military.divisions:
		s["tümen/%d" % d.id] = _obj(d)
	for a in Military.armies:
		s["ordu/%d" % a.id] = _obj(a)
	for cm in Military.commanders:
		s["komutan/%d" % cm.id] = _obj(cm)
	for g in Military.groups:
		s["ordular grubu/%d" % g.id] = _obj(g)
	for f in Navy.fleets:
		s["filo/%d" % f.id] = _obj(f)
	for w in Air.wings:
		s["kanat/%d" % w.id] = _obj(w)
	for st: StateRegion in World.states.values():
		s["eyalet/%d" % st.id] = {"owner": st.owner, "buildings": _plain(st.buildings), "resources": _plain(st.resources),
			"damage": snappedf(st.damage, 0.0001)}
	s["savaşlar"] = _plain(Diplomacy.wars)
	s["katılmayı bekleyen"] = _plain(Diplomacy.waiting_to_join)
	s["başlangıç ZP"] = _plain(Diplomacy._start_vp)
	s["ittifaklar"] = _plain(Politics.factions)
	s["olay geçmişi"] = _plain(Politics.fired_events)
	s["bekleyen olaylar"] = _plain(Politics.pending_events)
	s["dünya olayları"] = _plain(World.world_log)
	s["dünya alındı"] = Game.won
	s["sayaçlar"] = [Military._next_id, Military._next_army, Navy._next_id, Air._next_id, Diplomacy._next_id,
		Military._next_commander, Military._next_group]
	return s

func _obj(o: Object) -> Dictionary:
	var out := {}
	var skip: Array = [] if _all else DERIVED.get(_class(o), [])
	for p: Dictionary in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n in skip:
			continue
		out[n] = _plain(o.get(n))
	return out

func _class(o: Object) -> String:
	var sc: Script = o.get_script()
	return sc.get_global_name() if sc else o.get_class()

## Karşılaştırılabilir düz değer: sayılar float, nesneler sözlük, diziler dizi, sözlük anahtarları metin
func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_OBJECT:
			return _obj(v) if v != null else null
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[str(k)] = _plain(v[k])
			return out
		TYPE_COLOR:
			return (v as Color).to_html()
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var out: Array = []
			for x in v:
				out.append(_plain(x))
			return out
	return v

func _sorted(a: Array) -> Array:
	var out: Array = a.duplicate()
	out.sort()
	return _plain(out)

## Farkları alana göre topla: "/tümen/12/idle_hours" ve "/tümen/40/idle_hours" → "/tümen/*/idle_hours (2 fark, ör. ...)"
func _by_field(diffs: Array) -> Array:
	var groups := {}
	var order: Array = []
	var digits := RegEx.create_from_string("/[0-9]+|\\[[0-9]+\\]")
	for d: String in diffs:
		var key := digits.sub(d.get_slice(":", 0), "/*", true)
		if not groups.has(key):
			groups[key] = [0, d]
			order.append(key)
		groups[key][0] += 1
	var out: Array = []
	for k: String in order:
		out.append("%s — %d fark, ör. %s" % [k, groups[k][0], groups[k][1]])
	return out

func _diff(path: String, a: Variant, b: Variant, out: Array) -> void:
	if out.size() > 5000:
		return
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		if absf(a - b) > 1e-6 * maxf(1.0, absf(a)):
			out.append("%s: önce %s, sonra %s" % [path, a, b])
		return
	if typeof(a) != typeof(b):
		out.append("%s: önce %s, sonra %s" % [path, _short(a), _short(b)])
		return
	if a is Dictionary:
		for k in a:
			if not b.has(k):
				out.append("%s/%s: yüklemede yok" % [path, k])
			else:
				_diff("%s/%s" % [path, k], a[k], b[k], out)
		for k in b:
			if not a.has(k):
				out.append("%s/%s: yüklemede fazladan var" % [path, k])
	elif a is Array:
		if a.size() != b.size():
			out.append("%s: uzunluk %d → %d" % [path, a.size(), b.size()])
			return
		for i in a.size():
			_diff("%s[%d]" % [path, i], a[i], b[i], out)
	elif a != b:
		out.append("%s: önce %s, sonra %s" % [path, _short(a), _short(b)])

func _short(v: Variant) -> String:
	var s := str(v)
	return s if s.length() < 80 else s.substr(0, 77) + "..."
