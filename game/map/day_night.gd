class_name DayNight
extends Node
## Gece ve gündüz: güneşin dünyadaki yeri oyun tarihinden ve saatinden (saat UTC sayılır; Greenwich 12:00'de öğle).
## Harita (map3d.gdshader) her noktada güneşin yüksekliğine göre karanlık ve alacakaranlık boyar; terminatör harita
## üstünde kesintisiz kayar (GameClock.hour_fraction ile saat arası da akar). Yakın zoom'da 3D modeller (asker, tank,
## şehir, gemi) haritanın ışığıyla aydınlanır: güneş ve ortam ışığı kameranın baktığı yerin gecesine göre kısılır, harita
## bu kısılmayı shader'da geri alır (yer her noktada kendi saatinde kalır). Yalnız görüntü: oyun kurallarını etkilemez.

## Gece zemin rengi katı shader'larda: night_tint (map3d, ambient_clouds)
## Hızlı oyunda gün birkaç saniyede geçer: gece hız arttıkça hafifler (yanıp sönme olmasın). Kademe 0..5
const SPEED_STRENGTH: Array[float] = [1.0, 1.0, 1.0, 0.9, 0.75, 0.55]
const MODEL_NIGHT := 0.3                      ## gece yakında 3D modellere kalan ışık payı
const CLOSE_DIST := Vector2(450.0, 900.0)      ## modellerin ışığı bu kamera uzaklığından yakında gece kısılır

var map: MapView3D
var camera: MapCamera3D
var sun: DirectionalLight3D
var env: Environment
var enabled := false
var _sun_energy := 1.0
var _ambient := 1.0
var _strength := 0.0

func setup(m: MapView3D, cam: MapCamera3D, s: DirectionalLight3D, e: Environment) -> void:
	map = m
	camera = cam
	sun = s
	env = e
	_sun_energy = sun.light_energy
	_ambient = env.ambient_light_energy

## Şehir minyatürlerinin camı (city_windows.gdshader): bütün şehirlerde tek malzeme, uniform'ları her karede
static var _windows: ShaderMaterial
static func window_material() -> ShaderMaterial:
	if _windows == null:
		_windows = ShaderMaterial.new()
		_windows.shader = preload("res://assets/shaders/city_windows.gdshader")
		UnitModels.compat_material(_windows)
		_windows.set_shader_parameter("map_size", Vector2(World.map_width, World.map_height))
		_windows.set_shader_parameter("proj_lon_min", World._lon_min)
		_windows.set_shader_parameter("proj_y_top", World._y_top)
		_windows.set_shader_parameter("proj_px_per_rad", World._px_per_rad)
	return _windows

## Güneş hesabı GameClock'ta (oyun kuralları da kullanır: gece saldırısı, keşif); burada kısa adlar
static func subsolar(doy: float, utc: float) -> Vector2:
	return GameClock.subsolar(doy, utc)

static func sun_height(ll: Vector2, sub: Vector2) -> float:
	return GameClock.sun_height(ll, sub)

static func night_of(h: float) -> float:
	return GameClock.night_of(h)

func _process(delta: float) -> void:
	if map == null or not World._miller:
		return
	var utc := float(GameClock.hour) + (GameClock.hour_fraction() if not GameClock.paused else 0.0)
	var sub := subsolar(GameClock.day_of_year() + utc / 24.0, utc)
	var target: float = SPEED_STRENGTH[GameClock.speed] if enabled else 0.0
	_strength = move_toward(_strength, target, delta * 0.25) if enabled else 0.0
	# kameranın baktığı yerin gecesi: modeller (yakında) o ışıkla
	var light := 1.0
	if camera and _strength > 0.0:
		var t := Vector2(camera.target.x, camera.target.z)
		var n := night_of(sun_height(World.lonlat(t), sub)) * _strength
		var close := 1.0 - smoothstep(CLOSE_DIST.x, CLOSE_DIST.y, camera.distance)
		light = lerpf(1.0, MODEL_NIGHT, n * close)
	sun.light_energy = _sun_energy * light
	env.ambient_light_energy = _ambient * light
	map.set_day_night(sub, _strength, light)
	if _windows:
		_windows.set_shader_parameter("sun_lonlat", sub)
		_windows.set_shader_parameter("night_strength", _strength)
