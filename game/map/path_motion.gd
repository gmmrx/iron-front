class_name PathMotion
extends RefCounted
## Simülasyondaki (saatlik, bölge merkezleri arası) hareketi akıcı görsele çevirir:
## saat içi ara değer + Catmull-Rom eğrisi (köşeler yumuşak, yön türevden).

## p0..p3 kontrol noktaları, t: p1 -> p2 arası
static func catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func catmull_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	return 0.5 * ((-p0 + p2) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2)

## Rota noktaları: [şimdiki bölge, yol...] merkezleri
static func route_points(from_pid: int, path: PackedInt32Array, from_override := Vector2.INF) -> Array[Vector2]:
	var pts: Array[Vector2] = [World.province(from_pid).center if from_override == Vector2.INF else from_override]
	for pid in path:
		# dikişten geçen rotada noktalar bir öncekine göre sarmalanır (Pasifik)
		pts.append(World.unwrap_near(pts[pts.size() - 1], World.province(pid).center))
	return pts

## pts[0] -> pts[1] kesiminde t oranında konum ve yön (önceki nokta bilinmiyorsa yansıtılır)
static func sample(pts: Array[Vector2], t: float, prev := Vector2.INF) -> Array:
	var p1 := pts[0]
	var p2 := pts[1]
	var p0 := prev if prev != Vector2.INF else p1 - (p2 - p1)
	var p3 := pts[2] if pts.size() > 2 else p2 + (p2 - p1)
	var pos := catmull(p0, p1, p2, p3, t)
	var tan := catmull_tangent(p0, p1, p2, p3, t)
	return [pos, tan.normalized() if tan.length_squared() > 1e-6 else (p2 - p1).normalized()]

## Tümenin akıcı görsel konumu: [konum, yön, hareket ediyor mu, hız (dünya birimi / gerçek saniye)]
static func division(d: Division) -> Array:
	var here := World.province(d.province).center
	if d.path.is_empty() or d.training > 0:
		return [here, Vector2.ZERO, false, 0.0]
	var km := World.km_per_px_at(here)
	var dist_km := maxf(World.distance_km(d.province, d.path[0]), 1.0)
	var kmh := 0.0
	if d.attacking == 0:
		kmh = Military._speed(d, d.path[0])
	var prog := d.progress + kmh * GameClock.hour_fraction()
	var t := clampf(prog / dist_km, 0.0, 1.0)
	# saldırıda: sınıra kadar ilerler, orada kalır
	if d.attacking > 0:
		t = minf(t, 0.34)
	var from_p := World.province(d.province)
	var to_p := World.province(d.path[0])
	if not (from_p.is_land() and to_p.is_land()):
		var nxt := d.path[1] if d.path.size() > 1 else -1
		var lp := sea_pose(_prev_of(d.get_instance_id(), d.province), d.province, d.path[0], nxt, t, here)
		if not lp.is_empty():
			var wsp := SeaLanes.length(SeaLanes.lane(d.province, d.path[0])) / dist_km * kmh * GameClock.hours_per_second()
			return [lp[0], lp[1], true, wsp]
	var pts := route_points(d.province, d.path)
	var s := sample(pts, t)
	var wspeed := kmh / km * GameClock.hours_per_second() if d.attacking == 0 else 0.0
	return [s[0], s[1], d.attacking == 0, wspeed]

## Filonun akıcı görsel konumu (limanda: rıhtım noktası dışarıdan verilir)
static func fleet(f: Fleet, from_pos: Vector2) -> Array:
	var prev := _prev_of(f.get_instance_id(), f.location)
	if f.path.is_empty():
		return [from_pos, Vector2.ZERO, false, 0.0]
	var here := World.province(f.location).center
	var km := World.km_per_px_at(here)
	var dist_km := maxf(Navy.leg_km(f.location, f.path[0]), 1.0)
	var kmh := Navy.speed(f)
	var t := clampf((f.progress + kmh * GameClock.hour_fraction()) / dist_km, 0.0, 1.0)
	var nxt := f.path[1] if f.path.size() > 1 else -1
	var lp := sea_pose(prev, f.location, f.path[0], nxt, t, from_pos)
	if not lp.is_empty():
		var l := SeaLanes.lane(f.location, f.path[0])
		var wspeed := SeaLanes.length(l) / dist_km * kmh * GameClock.hours_per_second()
		return [lp[0], lp[1], true, wspeed]
	var pts := route_points(f.location, f.path, from_pos)
	var s := sample(pts, t)
	return [s[0], s[1], true, kmh / km * GameClock.hours_per_second()]

# ------------------------------------------------------------------ deniz yolları
const CORNER := 22.0            ## düğümlerde köşe yumuşatma yarıçapı (piksel)
static var _prev := {}           ## nesne id -> [şimdiki bölge, önceki bölge]

## Bir önceki bölge (köşe yumuşatma için; yalnız görsel)
static func _prev_of(id: int, loc: int) -> int:
	var e: Array = _prev.get(id, [])
	if e.is_empty():
		_prev[id] = [loc, -1]
		return -1
	if int(e[0]) != loc:
		_prev[id] = [loc, int(e[0])]
		return int(e[0])
	return int(e[1])

## Deniz yolunda konum/yön: from -> to rotasında t oranı; düğüm köşeleri ikinci derece Bézier ile yuvarlanır.
## Rota yoksa boş dizi. `ref`: sonuç bu noktanın yanına sarmalanır (dikiş).
static func sea_pose(prev: int, from: int, to: int, nxt: int, t: float, ref: Vector2) -> Array:
	var l := SeaLanes.lane(from, to)
	if l.is_empty():
		return []
	var L := SeaLanes.length(l)
	var s := t * L
	var p := _lane_point(prev, from, to, nxt, l, s)
	var q := _lane_point(prev, from, to, nxt, l, minf(s + 1.0, L + 0.5))
	var dir := q - p
	if dir.length_squared() < 1e-8:
		dir = SeaLanes.at(l, s)[1]
	var shift := World.unwrap_near(ref, p) - p if ref != Vector2.INF else Vector2.ZERO
	return [p + shift, dir.normalized()]

static func _lane_point(prev: int, from: int, to: int, nxt: int, l: Array, s: float) -> Vector2:
	var L := SeaLanes.length(l)
	var pts: PackedVector2Array = l[0]
	# varışa yakın: sonraki rotaya kavis
	if nxt >= 0 and s > L * 0.5:
		var n := SeaLanes.lane(to, nxt)
		if not n.is_empty():
			var r := minf(CORNER, minf(L * 0.5, SeaLanes.length(n) * 0.5))
			if s > L - r:
				var a: Vector2 = SeaLanes.at(l, L - r)[0]
				var c := pts[pts.size() - 1]
				var b: Vector2 = SeaLanes.at(n, r)[0]
				b = World.unwrap_near(c, b)
				return _bezier(a, c, b, (s - (L - r)) / (2.0 * r))
	# çıkışa yakın: önceki rotadan gelen kavis
	if prev >= 0 and s < L * 0.5:
		var pl := SeaLanes.lane(prev, from)
		if not pl.is_empty():
			var PL := SeaLanes.length(pl)
			var r := minf(CORNER, minf(PL * 0.5, L * 0.5))
			if s < r:
				var a: Vector2 = SeaLanes.at(pl, PL - r)[0]
				var c := pts[0]
				a = World.unwrap_near(c, a)
				var b: Vector2 = SeaLanes.at(l, r)[0]
				return _bezier(a, c, b, 0.5 + s / (2.0 * r))
	return SeaLanes.at(l, s)[0]

static func _bezier(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return a * v * v + c * 2.0 * u * v + b * u * u
