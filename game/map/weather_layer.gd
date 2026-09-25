class_name WeatherLayer
extends Node3D
## Hava durumu: bölgesel yağış durumu (açık / yağmur / kar) + kameranın yakınında yağış parçacıkları.
## Durum, günün tarihine ve konuma bağlı deterministik gürültüden üretilir (kaydetmeye gerek yok):
## sonbahar/ilkbahar çamur aylarında (Military.mud_level) yağmur sık; kış (Military.winter_level) yağışı kar yapar.
## Diorama görünümü: yağış yalnız yakın/orta zoom'da görünür; uzak zoom'da harita okunur kalır.

enum Kind { CLEAR, RAIN, SNOW }

const CELL := 180.0            ## hava hücresi (dünya birimi)
const MAX_VIEW_DIST := 750.0   ## bu mesafeden uzakta parçacık yok
const BOX := Vector3(150.0, 70.0, 150.0)

var map: MapView3D
var camera: MapCamera3D
var rain: GPUParticles3D
var snow: GPUParticles3D
var _day := -1
var _cache := {}               ## hücre -> [kind, intensity]
var current := Kind.CLEAR      ## kamera hedefindeki hava (HUD gösterir)
var force := -1                ## geliştirici: -1 serbest, yoksa zorlanan Kind
var current_intensity := 0.0

func _ready() -> void:
	rain = _make_emitter(true)
	snow = _make_emitter(false)
	add_child(rain)
	add_child(snow)

## Bölgesel hava: hücre + gün tohumlu gürültü; mevsim ve enlem olasılığı belirler
func weather_at(world_xz: Vector2) -> Array:
	if _day != World.day_count:
		_cache.clear()
		_day = World.day_count
	var cx := floori(world_xz.x / CELL)
	var cy := floori(world_xz.y / CELL)
	var key := cx * 100000 + cy
	if _cache.has(key):
		return _cache[key]
	var pid := map.province_at(world_xz) if map else 0
	var p := World.province(pid) if pid > 0 else null
	var lat: float = p.lonlat.y if p else 45.0
	var alat := absf(lat)
	var m := GameClock.month
	# yağış olasılığı: ılıman kuşakta sonbahar/ilkbahar yüksek, yaz düşük; çöl kuşağı (15–32°) çok düşük
	var season := 0.35
	if m in [10, 11, 3, 4]: season = 0.55
	elif m in [12, 1, 2]: season = 0.45
	elif m in [6, 7, 8]: season = 0.22
	var zone := 1.0
	if alat < 32.0 and alat > 15.0: zone = 0.25
	elif alat <= 15.0: zone = 1.1
	var prob := season * zone
	if pid > 0 and Military.mud_level(pid) > 0.0:
		prob = maxf(prob, 0.7)
	# yavaş değişen gürültü: 3 günlük pencereler, komşu hücreler benzer
	var slow := World.day_count / 3
	var h := _hash(cx * 3 + 11, cy * 7 + 5, slow)
	var h2 := _hash(cx, cy, slow + 1)
	var v := h * 0.7 + h2 * 0.3
	var out: Array
	if v < prob:
		var intensity := clampf((prob - v) / prob * 1.4, 0.3, 1.0)
		var kind := Kind.SNOW if (pid > 0 and Military.winter_level(pid) > 0.0) or (alat > 58.0 and m in [11, 12, 1, 2, 3]) else Kind.RAIN
		out = [kind, intensity]
	else:
		out = [Kind.CLEAR, 0.0]
	_cache[key] = out
	return out

func _hash(x: int, y: int, z: int) -> float:
	var n := int(x) * 374761393 + int(y) * 668265263 + int(z) * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n) % 100000) / 100000.0

func _process(_delta: float) -> void:
	if camera == null or not World.in_game:
		rain.emitting = false
		snow.emitting = false
		return
	var target := Vector2(camera.target.x, camera.target.z)
	var w := weather_at(target)
	current = w[0]
	current_intensity = w[1]
	if force >= 0:
		current = force as Kind
		current_intensity = 1.0
	var near := camera.distance < MAX_VIEW_DIST
	var fade := clampf(1.0 - (camera.distance - 350.0) / (MAX_VIEW_DIST - 350.0), 0.0, 1.0)
	var ground := map.height_at(target) if map else 0.0
	var center := Vector3(target.x, ground + BOX.y * 0.5 + 4.0, target.y)
	rain.global_position = center
	snow.global_position = center
	var want_rain := near and current == Kind.RAIN
	var want_snow := near and current == Kind.SNOW
	rain.amount_ratio = clampf(current_intensity * fade, 0.0, 1.0)
	snow.amount_ratio = clampf(current_intensity * fade, 0.0, 1.0)
	if rain.emitting != want_rain:
		rain.emitting = want_rain
	if snow.emitting != want_snow:
		snow.emitting = want_snow

func _make_emitter(is_rain: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = BOX * 0.5
	pm.direction = Vector3(0.15, -1.0, 0.05) if is_rain else Vector3(0, -1, 0)
	pm.spread = 4.0 if is_rain else 25.0
	pm.gravity = Vector3(0, -90.0, 0) if is_rain else Vector3(0, -6.0, 0)
	pm.initial_velocity_min = 55.0 if is_rain else 2.0
	pm.initial_velocity_max = 70.0 if is_rain else 4.0
	if not is_rain:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.5
		pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	p.process_material = pm
	p.amount = 5000 if is_rain else 1600
	p.lifetime = 1.0 if is_rain else 6.0
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.visibility_aabb = AABB(-BOX * 0.6, BOX * 1.2)
	p.emitting = false
	p.amount_ratio = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.09, 2.6) if is_rain else Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if is_rain else BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = false
	mat.albedo_color = Color(0.86, 0.92, 1.0, 0.7) if is_rain else Color(1.0, 1.0, 1.0, 0.9)
	if not is_rain:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 32
		tex.height = 32
		mat.albedo_texture = tex
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
