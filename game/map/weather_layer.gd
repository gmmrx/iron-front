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
const RAIN_CAP := 384          ## tek, sabit iki üçgenlik streak havuzu; simülasyon/emitter yok
const RAIN_WIND := Vector3(26.0, -8.0, 7.0) ## dünya yönünde güçlü yatay rüzgâr, gerçek birim/sn
const RAIN_SHADER := preload("res://assets/shaders/weather_rain.gdshader")

var map: MapView3D
var camera: MapCamera3D
var rain: MultiMeshInstance3D
var snow: GPUParticles3D
var _rain_material: ShaderMaterial
var _rain_time := 0.0
var _rain_bounds := Vector2.ZERO
var _day := -1
var _cache := {}               ## (hücre x, hücre y, bölge) -> [kind, intensity]
var current := Kind.CLEAR      ## kamera hedefindeki hava (HUD gösterir)
var force := -1                ## geliştirici: -1 serbest, yoksa zorlanan Kind
var current_intensity := 0.0

func _ready() -> void:
	rain = _make_rain()
	snow = _make_snow()
	add_child(rain)
	add_child(snow)

## Bölgesel hava: hücre + gün tohumlu gürültü; mevsim ve enlem olasılığı belirler. Sonuç yalnız (gün, hücre, bölge)'ye
## bağlıdır: önbellek anahtarında bölge de var (yoksa hücrede ilk sorgulanan noktanın bölgesi hücrenin tamamına yazılıyor,
## sonuç sorgu sırasına bağlı oluyordu)
func weather_at(world_xz: Vector2) -> Array:
	if _day != World.day_count:
		_cache.clear()
		_day = World.day_count
	var cx := floori(world_xz.x / CELL)
	var cy := floori(world_xz.y / CELL)
	var pid := map.province_at(world_xz) if map else 0
	var key := Vector3i(cx, cy, pid)
	if _cache.has(key):
		return _cache[key]
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

func _process(delta: float) -> void:
	if camera == null or not World.in_game:
		rain.visible = false
		rain.multimesh.visible_instance_count = 0
		snow.emitting = false
		snow.visible = false
		return
	if not GameClock.paused:
		_rain_time += clampf(delta, 0.0, 0.1) # simulation speed never multiplies wind or streak motion
	_rain_material.set_shader_parameter("rain_time", _rain_time)
	snow.speed_scale = 0.0 if GameClock.paused else 1.0
	var target := Vector2(camera.target.x, camera.target.z)
	var w := weather_at(target)
	current = w[0]
	current_intensity = w[1]
	if force >= 0:
		current = force as Kind
		current_intensity = 1.0
	var near := camera.distance < MAX_VIEW_DIST
	var fade := clampf(1.0 - (camera.distance - 350.0) / (MAX_VIEW_DIST - 350.0), 0.0, 1.0)
	# yakın zoom: kutu görüş alanı kadar küçülür, parçacık sayısı da azalır (ekranı kaplayan büyük damlalar FPS yiyordu)
	var ext := clampf(camera.distance * 0.9, 45.0, BOX.x)
	var density := clampf(ext / BOX.x, 0.3, 1.0)
	var snow_pm := snow.process_material as ParticleProcessMaterial
	snow_pm.emission_box_extents = Vector3(ext * 0.5, BOX.y * 0.5, ext * 0.5)
	var ground := map.height_at(target) if map else 0.0
	var center := Vector3(target.x, ground + BOX.y * 0.5 + 4.0, target.y)
	var rain_height := clampf(camera.distance * 0.18, 14.0, 56.0)
	rain.global_position = Vector3(target.x, ground + rain_height * 0.5 + 0.35, target.y)
	snow.global_position = center
	var want_rain := near and current == Kind.RAIN
	var want_snow := near and current == Kind.SNOW
	var amount := clampf(current_intensity * fade * density, 0.0, 1.0)
	rain.multimesh.visible_instance_count = roundi(RAIN_CAP * amount) if want_rain else 0
	rain.visible = want_rain and rain.multimesh.visible_instance_count > 0
	_rain_material.set_shader_parameter("field_size", Vector3(ext, rain_height, ext))
	_rain_material.set_shader_parameter("streak_width", clampf(camera.distance * 0.00055, 0.04, 0.18))
	_rain_material.set_shader_parameter("rain_opacity", 0.30 * current_intensity * fade)
	var bounds := Vector2(ext, rain_height)
	if bounds != _rain_bounds:
		_rain_bounds = bounds
		rain.custom_aabb = AABB(Vector3(-ext * 0.5 - 3.0, -rain_height * 0.5 - 3.0, -ext * 0.5 - 3.0), Vector3(ext + 6.0, rain_height + 6.0, ext + 6.0))
	snow.amount_ratio = clampf(amount * (0.55 if UnitModels.COMPAT else 1.0), 0.05, 1.0)
	if snow.emitting != want_snow:
		snow.emitting = want_snow
	snow.visible = want_snow

func _make_rain() -> MultiMeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = RAIN_CAP
	mm.visible_instance_count = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 19360901 # Stable nongrid seeds; no consumption of the gameplay RNG.
	for i in RAIN_CAP:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	_rain_material = ShaderMaterial.new()
	_rain_material.shader = RAIN_SHADER
	UnitModels.compat_material(_rain_material)
	_rain_material.set_shader_parameter("wind_velocity", RAIN_WIND)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _rain_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	return node

func _make_snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = BOX * 0.5
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	p.process_material = pm
	p.amount = 800
	p.lifetime = 5.0
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.visibility_aabb = AABB(-BOX * 0.6, BOX * 1.2)
	p.emitting = false
	p.amount_ratio = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = false
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
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
