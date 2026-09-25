class_name SeaLanes
extends RefCounted
## Deniz yolu ağı (tools/build_sea_lanes.py): deniz bölgesi düğümleri, liman rıhtımları ve komşu bölgeler
## arasında yalnız sudan geçen yumuşak rotalar. Filo/nakliye hareketi ve rota görünümü bunları izler.

static var _loaded := false
static var _nodes := {}          ## pid -> Vector2
static var _docks := {}          ## "port-sea" -> Vector2
static var _raw := {}            ## "a-b" (a<b) -> Array (json)
static var _cache := {}          ## "from-to" -> [PackedVector2Array, PackedFloat32Array kümülatif uzunluk]

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/map/sea_lanes.json", FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k: String in d.get("nodes", {}):
		var p: Array = d["nodes"][k]
		_nodes[int(k)] = Vector2(p[0], p[1])
	for k: String in d.get("docks", {}):
		var p: Array = d["docks"][k]
		_docks[k] = Vector2(p[0], p[1])
	_raw = d.get("lanes", {})

## Deniz bölgesinin açık denizdeki düğümü (yoksa merkez)
static func node(pid: int) -> Vector2:
	_ensure()
	return _nodes.get(pid, World.province(pid).center)

## Limanın verilen denize açılan rıhtımı (yoksa INF)
static func dock(port: int, sea: int) -> Vector2:
	_ensure()
	return _docks.get("%d-%d" % [port, sea], Vector2.INF)

## a'dan b'ye rota ve kümülatif uzunluk; yoksa boş
static func lane(a: int, b: int) -> Array:
	_ensure()
	var key := "%d-%d" % [a, b]
	if _cache.has(key):
		return _cache[key]
	var raw: Array = _raw.get("%d-%d" % [mini(a, b), maxi(a, b)], [])
	if raw.size() < 2:
		_cache[key] = []
		return []
	var pts := PackedVector2Array()
	for p: Array in raw:
		pts.append(Vector2(p[0], p[1]))
	if a > b:
		pts.reverse()
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	_cache[key] = [pts, cum]
	return _cache[key]

## Rota üzerinde yay uzunluğu s'deki nokta ve yön (s sınırlanır)
static func at(l: Array, s: float) -> Array:
	var pts: PackedVector2Array = l[0]
	var cum: PackedFloat32Array = l[1]
	var total := cum[cum.size() - 1]
	s = clampf(s, 0.0, total)
	var i := cum.bsearch(s, true) - 1
	i = clampi(i, 0, pts.size() - 2)
	var seg := maxf(cum[i + 1] - cum[i], 1e-4)
	var t := (s - cum[i]) / seg
	var dir := (pts[i + 1] - pts[i]) / seg
	return [pts[i].lerp(pts[i + 1], t), dir]

static func length(l: Array) -> float:
	var cum: PackedFloat32Array = l[1]
	return cum[cum.size() - 1]

## Birden çok bölge üzerinden birleşik rota noktaları (rota görünümü için): [from, path...]
static func polyline(from_pid: int, path: PackedInt32Array, start := Vector2.INF) -> PackedVector2Array:
	var out := PackedVector2Array()
	var prev := from_pid
	var shift := Vector2.ZERO
	for pid in path:
		var l := lane(prev, pid)
		if l.is_empty():
			var a := World.province(prev).center
			var b := World.province(pid).center
			if out.is_empty():
				out.append(start if start != Vector2.INF else a)
			out.append(World.unwrap_near(out[out.size() - 1], b))
		else:
			var pts: PackedVector2Array = l[0]
			if out.is_empty():
				out.append(pts[0] if start == Vector2.INF else start)
			# dikiş: rotayı bir öncekinin yanına taşı
			shift = World.unwrap_near(out[out.size() - 1], pts[0]) - pts[0]
			for i in range(1, pts.size()):
				out.append(pts[i] + shift)
		prev = pid
	return out
