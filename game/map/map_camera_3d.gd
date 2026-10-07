class_name MapCamera3D
extends Camera3D
## Strateji kamerası: uzakta tepeden, yaklaştıkça eğilen bakış.
## Hedef nokta zeminde (x, z); mesafe tekerlekle imlece doğru yumuşak değişir.

const MIN_DIST := 55.0
const MAX_DIST_EUROPE := 5200.0
const STRATEGIC_MAX_DIST := 5200.0  ## bölgesel bakış; dünyanın geri kalanına kaydırarak/sarmalayarak gidilir
var MAX_DIST := STRATEGIC_MAX_DIST  ## küçük harita veya dar ekran için ayrıca haritaya sığdırılır
const PITCH_NEAR := deg_to_rad(48.0)
const PITCH_FAR := deg_to_rad(80.0)
const ZOOM_STEP := 1.18
const ZOOM_SMOOTHING := 12.0
const PAN_SPEED := 1.2             ## ekran yüksekliği / saniye
const EDGE_MARGIN := 4.0

var map: MapView3D
var map_size := Vector2(5120, 4348):
	set(v):
		map_size = v
		_fit_vp = Vector2.ZERO          # uzaklaşma sınırı yeniden hesaplansın
var _fit_vp := Vector2.ZERO
var edge_pan_enabled := true
var input_locked := false            ## tam ekran panel açıkken tuşla da kaydırma yok
var target := Vector3.ZERO
## Kaydırma (tuş, kenar, sürükleme) doğrudan kamerayı değil hedefini oynatır; kamera ona yumuşakça gelir, sürükleme
## bırakılınca sürtünmeyle süzülür (araştırma ağacındaki gibi). Kodun target'ı doğrudan değiştirmesi de geçerlidir.
const PAN_SMOOTHING := 12.0
const DRAG_SMOOTHING := 22.0         ## sürüklerken imleci sıkı izler
const GLIDE_FRICTION := 5.0
var _goal := Vector3.ZERO
var _target_prev := Vector3.ZERO     ## son karede kameranın bıraktığı target (başka kod değiştirdiyse hedef ona uyar)
var _vel := Vector2.ZERO             ## süzülme hızı (dünya birimi / sn)
var _dragging := false
var _drag_us := 0
var distance := 1400.0
var _target_distance := 1400.0
var _zoom_anchor_screen := Vector2.ZERO

func _ready() -> void:
	fov = 34.0
	near = 0.5
	far = 60000.0
	_apply()

func focus_on(world_xz: Vector2, new_distance: float = -1.0) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp != _fit_vp:
		_fit_vp = vp
		_update_max_dist(vp)
	_stop_flight()
	target = Vector3(world_xz.x, 0, world_xz.y)
	if new_distance > 0.0:
		distance = clampf(new_distance, MIN_DIST, MAX_DIST)
		_target_distance = distance
	_clamp_target()
	_goal = target
	_target_prev = target
	_vel = Vector2.ZERO
	_apply()

## Uçuş: hedefe ve uzaklığa yumuşak geçiş (TAK diye sıçramak yerine). Yol uzunsa ortasında biraz uzaklaşır (yol
## görünsün); bitince flight_finished. Kullanıcı sürükler, tekerleği çevirir ya da kod focus_on derse uçuş biter.
signal flight_finished
var _fly := {}

func fly_to(world_xz: Vector2, new_distance: float, secs := 1.3) -> void:
	var d1 := clampf(new_distance, MIN_DIST, MAX_DIST)
	var from := Vector2(target.x, target.z)
	var to := world_xz
	if World.wraps:
		to.x = from.x + wrapf(to.x - from.x, -map_size.x * 0.5, map_size.x * 0.5)
	var hop := clampf(from.distance_to(to) * 0.3, 0.0, 1200.0) * clampf(1.0 - absf(d1 - distance) / maxf(distance, 1.0), 0.3, 1.0)
	_fly = {"from": from, "to": to, "d0": distance, "d1": d1, "hop": hop, "t": 0.0, "secs": maxf(secs, 0.05)}
	_vel = Vector2.ZERO

func flying() -> bool:
	return not _fly.is_empty()

func _stop_flight() -> void:
	_fly = {}

## Uçuşun bir karesi: kübik yumuşak başlayıp yumuşak biten geçiş
func _fly_step(delta: float) -> void:
	var f := _fly
	f["t"] = minf(float(f["t"]) + delta / float(f["secs"]), 1.0)
	var x: float = f["t"]
	var k := 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
	var p: Vector2 = (f["from"] as Vector2).lerp(f["to"], k)
	distance = lerpf(f["d0"], f["d1"], k) + sin(PI * k) * float(f["hop"])
	_target_distance = distance
	target = Vector3(p.x, 0.0, p.y)
	_clamp_target()
	_goal = target
	_target_prev = target
	_apply()
	if x >= 1.0:
		_fly = {}
		flight_finished.emit()

func zoom_at(screen_pos: Vector2, steps: float) -> void:
	_stop_flight()
	_zoom_anchor_screen = screen_pos
	_target_distance = clampf(_target_distance / pow(ZOOM_STEP, steps), MIN_DIST, MAX_DIST)

## Sürükleme: imlecin altındaki zemin noktası imleçle birlikte hareket eder (kamera sıkı ama yumuşak izler)
func drag(from_screen: Vector2, to_screen: Vector2) -> void:
	_stop_flight()
	var a = ground_point(from_screen)
	var b = ground_point(to_screen)
	if a == null or b == null:
		return
	var d := Vector3(a.x - b.x, 0, a.z - b.z)
	_goal = _clamped(_goal + d)
	var now := Time.get_ticks_usec()
	var dt := float(now - _drag_us) / 1e6
	_drag_us = now
	if _dragging:
		# bırakınca süzülme hızı: son hareketlerin ortalaması
		_vel = _vel.lerp(Vector2(d.x, d.z) / maxf(dt, 1.0 / 240.0), 0.5) if dt < 0.1 else Vector2.ZERO

## Fareyle sürükleme başlar / biter (bırakınca harita süzülür; durup bıraktıysa süzülmez)
func begin_drag() -> void:
	_stop_flight()
	_dragging = true
	_vel = Vector2.ZERO
	_drag_us = Time.get_ticks_usec()

func end_drag() -> void:
	_dragging = false
	if float(Time.get_ticks_usec() - _drag_us) / 1e6 > 0.08:
		_vel = Vector2.ZERO

## Ekran pikseli / dünya birimi (hedef noktada) — ad katmanı ölçeği için
func view_scale() -> float:
	var vp_h := get_viewport().get_visible_rect().size.y
	return vp_h / (2.0 * distance * tan(deg_to_rad(fov) * 0.5))

func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp != _fit_vp:
		_fit_vp = vp
		_update_max_dist(vp)
	if not _fly.is_empty():
		_fly_step(delta)
		return
	var dir := Vector2.ZERO
	if not input_locked:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if edge_pan_enabled and DisplayServer.window_is_focused():
		var m := get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, vp).has_point(m):
			if m.x <= EDGE_MARGIN: dir.x -= 1
			elif m.x >= vp.x - EDGE_MARGIN: dir.x += 1
			if m.y <= EDGE_MARGIN: dir.y -= 1
			elif m.y >= vp.y - EDGE_MARGIN: dir.y += 1
	if target != _target_prev:
		_goal = target                  # başka kod kamerayı taşıdı: hedef de oraya
		_vel = Vector2.ZERO
	if dir != Vector2.ZERO:
		var world_per_screen := 1.0 / view_scale()
		var step := dir.normalized() * PAN_SPEED * vp.y * world_per_screen * delta
		_goal = _clamped(_goal + Vector3(step.x, 0, step.y))
		_vel = Vector2.ZERO
	if not _dragging and _vel.length() > 1.0:
		_goal = _clamped(_goal + Vector3(_vel.x, 0, _vel.y) * delta)
		_vel *= exp(-GLIDE_FRICTION * delta)
	elif not _dragging:
		_vel = Vector2.ZERO
	var dg := _goal - target
	if World.wraps:
		dg.x = wrapf(dg.x, -map_size.x * 0.5, map_size.x * 0.5)
	if dg.length_squared() > 1e-6:
		var recent := float(Time.get_ticks_usec() - _drag_us) / 1e6 < 0.12
		var k := 1.0 - exp(-(DRAG_SMOOTHING if _dragging or recent else PAN_SMOOTHING) * delta)
		target += dg if dg.length() < 0.02 else dg * k
		_clamp_target()
		if World.wraps:
			_goal.x = target.x + wrapf(_goal.x - target.x, -map_size.x * 0.5, map_size.x * 0.5)

	if absf(distance - _target_distance) > 0.01:
		var anchor = ground_point(_zoom_anchor_screen)
		distance = lerpf(distance, _target_distance, 1.0 - exp(-delta * ZOOM_SMOOTHING))
		if absf(distance - _target_distance) < 0.05:
			distance = _target_distance
		_apply()
		var after = ground_point(_zoom_anchor_screen)
		if anchor != null and after != null:
			var za := Vector3(anchor.x - after.x, 0, anchor.z - after.z)
			target += za
			_goal = _clamped(_goal + za)     # kaydırma sürerken de imlecin altındaki nokta yerinde kalır
		_clamp_target()
	_apply()
	_target_prev = target

func _pitch() -> float:
	return _pitch_for(distance)

func _apply() -> void:
	var p := _pitch()
	var focus := Vector3(target.x, 0.0, target.z)   # sabit yükseklik: arazide kamera inip çıkmaz
	position = focus + Vector3(0, sin(p), cos(p)) * distance
	look_at(focus, Vector3.UP)

## Görüş alanı haritadan taşmasın: ekran köşelerinin zemindeki izdüşümü (hedefe göre) harita içinde kalır
func _clamp_target() -> void:
	target = _clamped(target)

func _clamped(v: Vector3) -> Vector3:
	var e := _extents(distance, get_viewport().get_visible_rect().size)
	var lo := Vector2(-e.position.x, -e.position.y)
	var hi := Vector2(map_size.x - e.end.x, map_size.y - e.end.y)
	if World.wraps:
		# doğu-batı sarmalanır: kenarda durmaz, dikişten öbür tarafa geçer (harita kopyası kenarı doldurur)
		if v.x < 0.0 or v.x >= map_size.x:
			v.x = fposmod(v.x, map_size.x)
	else:
		v.x = clampf(v.x, lo.x, hi.x) if lo.x <= hi.x else map_size.x * 0.5
	v.z = clampf(v.z, lo.y, hi.y) if lo.y <= hi.y else map_size.y * 0.5
	return v

func _pitch_for(d: float) -> float:
	# Keep the strategic map overhead; only tilt as the player enters the diorama.
	var t := smoothstep(100.0, 650.0, d)
	return lerpf(PITCH_NEAR, PITCH_FAR, t)

## Düz zeminde, hedefe göre görünen alan (xz): ekran köşelerinden atılan ışınların y=0 kesişimleri.
## Bir köşe ufka bakıyorsa çok büyük bir dikdörtgen döner (sığmaz).
func _extents(d: float, vp: Vector2) -> Rect2:
	var p := _pitch_for(d)
	var c := Vector3(0, sin(p), cos(p)) * d
	var fwd := -c.normalized()
	var right := Vector3(1, 0, 0)
	var up := Vector3(0, cos(p), -sin(p))
	var tv := tan(deg_to_rad(fov) * 0.5)
	var th := tv * (vp.x / maxf(vp.y, 1.0))
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var dir: Vector3 = fwd + right * sx * th + up * sy * tv
			if dir.y > -1e-4:
				return Rect2(-1e9, -1e9, 2e9, 2e9)
			var hit := c + dir * (-c.y / dir.y)
			mn = mn.min(Vector2(hit.x, hit.z))
			mx = mx.max(Vector2(hit.x, hit.z))
	return Rect2(mn, mx - mn)

## En uzak zoom: görünen alanın haritaya tam sığdığı mesafe (ikili arama)
func _update_max_dist(vp: Vector2) -> void:
	var lo := MIN_DIST
	var hi := 60000.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		var e := _extents(mid, vp)
		if e.size.x <= map_size.x * 0.995 and e.size.y <= map_size.y * 0.995:
			lo = mid
		else:
			hi = mid
	MAX_DIST = minf(lo, STRATEGIC_MAX_DIST)
	_target_distance = minf(_target_distance, MAX_DIST)
	distance = minf(distance, MAX_DIST)
	_clamp_target()

## Ekrandaki noktanın altındaki arazi noktası (yükseklik dahil); ıskalarsa null
func ground_point(screen: Vector2) -> Variant:
	var o := project_ray_origin(screen)
	var d := project_ray_normal(screen)
	if d.y > -1e-4:
		return null
	var t := -o.y / d.y
	if map:
		for i in 4:  # yükseklik alanına yakınsa
			var p := o + d * t
			t = (map.height_at(Vector2(p.x, p.z)) - o.y) / d.y
	return o + d * t
