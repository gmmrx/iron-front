class_name MapCamera3D
extends Camera3D
## klasik strateji tarzı strateji kamerası: uzakta tepeden, yaklaştıkça eğilen bakış.
## Hedef nokta zeminde (x, z); mesafe tekerlekle imlece doğru yumuşak değişir.

const MIN_DIST := 55.0
const MAX_DIST_EUROPE := 5200.0
var MAX_DIST := 5200.0              ## harita boyuna göre (dünya haritasında tüm gezegen görünür)
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
var target := Vector3.ZERO
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
	target = Vector3(world_xz.x, 0, world_xz.y)
	if new_distance > 0.0:
		distance = clampf(new_distance, MIN_DIST, MAX_DIST)
		_target_distance = distance
	_clamp_target()
	_apply()

func zoom_at(screen_pos: Vector2, steps: float) -> void:
	_zoom_anchor_screen = screen_pos
	_target_distance = clampf(_target_distance / pow(ZOOM_STEP, steps), MIN_DIST, MAX_DIST)

## Sürükleme: imlecin altındaki zemin noktası imleçle birlikte hareket eder.
func drag(from_screen: Vector2, to_screen: Vector2) -> void:
	var a = ground_point(from_screen)
	var b = ground_point(to_screen)
	if a == null or b == null:
		return
	target += Vector3(a.x - b.x, 0, a.z - b.z)
	_clamp_target()
	_apply()

## Ekran pikseli / dünya birimi (hedef noktada) — ad katmanı ölçeği için
func view_scale() -> float:
	var vp_h := get_viewport().get_visible_rect().size.y
	return vp_h / (2.0 * distance * tan(deg_to_rad(fov) * 0.5))

func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp != _fit_vp:
		_fit_vp = vp
		_update_max_dist(vp)
	var dir := Vector2.ZERO
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
	if dir != Vector2.ZERO:
		var world_per_screen := 1.0 / view_scale()
		var step := dir.normalized() * PAN_SPEED * vp.y * world_per_screen * delta
		target += Vector3(step.x, 0, step.y)
		_clamp_target()

	if absf(distance - _target_distance) > 0.01:
		var anchor = ground_point(_zoom_anchor_screen)
		distance = lerpf(distance, _target_distance, 1.0 - exp(-delta * ZOOM_SMOOTHING))
		if absf(distance - _target_distance) < 0.05:
			distance = _target_distance
		_apply()
		var after = ground_point(_zoom_anchor_screen)
		if anchor != null and after != null:
			target += Vector3(anchor.x - after.x, 0, anchor.z - after.z)
		_clamp_target()
	_apply()

func _pitch() -> float:
	return _pitch_for(distance)

func _apply() -> void:
	var p := _pitch()
	var focus := Vector3(target.x, 0.0, target.z)   # sabit yükseklik: arazide kamera inip çıkmaz
	position = focus + Vector3(0, sin(p), cos(p)) * distance
	look_at(focus, Vector3.UP)

## Görüş alanı haritadan taşmasın: ekran köşelerinin zemindeki izdüşümü (hedefe göre) harita içinde kalır
func _clamp_target() -> void:
	var e := _extents(distance, get_viewport().get_visible_rect().size)
	var lo := Vector2(-e.position.x, -e.position.y)
	var hi := Vector2(map_size.x - e.end.x, map_size.y - e.end.y)
	if World.wraps:
		# doğu-batı sarmalanır: kenarda durmaz, dikişten öbür tarafa geçer (harita kopyası kenarı doldurur)
		if target.x < 0.0 or target.x >= map_size.x:
			target.x = fposmod(target.x, map_size.x)
	else:
		target.x = clampf(target.x, lo.x, hi.x) if lo.x <= hi.x else map_size.x * 0.5
	target.z = clampf(target.z, lo.y, hi.y) if lo.y <= hi.y else map_size.y * 0.5

func _pitch_for(d: float) -> float:
	var t := sqrt(clampf(inverse_lerp(MIN_DIST, MAX_DIST_EUROPE, d), 0.0, 1.0))
	return lerpf(PITCH_NEAR, PITCH_FAR, clampf(t * 1.6, 0.0, 1.0))

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
	MAX_DIST = lo
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
