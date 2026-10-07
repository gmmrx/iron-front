extends "res://tests/test_case.gd"
## Wind-driven rain is one bounded batch; weather rules and simulation state remain separate.

class ProbeMap extends MapView3D:
	func province_at(_p: Vector2) -> int:
		return World.capital_province(World.player_tag)
	func height_at(_p: Vector2) -> float:
		return 0.0

func _fixture() -> Dictionary:
	var paused := GameClock.paused
	var speed := GameClock.speed
	GameClock.paused = false
	var map := ProbeMap.new()
	var camera := MapCamera3D.new()
	camera.map = map
	camera.map_size = Vector2(2000, 2000)
	camera.edge_pan_enabled = false
	camera.input_locked = true
	Engine.get_main_loop().root.add_child(camera)
	camera.focus_on(Vector2(1000, 1000), 150.0)
	camera.set_process(false)
	var weather := WeatherLayer.new()
	weather.map = map
	weather.camera = camera
	weather.force = WeatherLayer.Kind.RAIN
	Engine.get_main_loop().root.add_child(weather)
	weather.set_process(false)
	weather._process(0.0)
	return {"weather": weather, "map": map, "camera": camera, "paused": paused, "speed": speed}

func _dispose(f: Dictionary) -> void:
	for key: String in ["weather", "camera", "map"]:
		var node: Node = f[key]
		if node.is_inside_tree(): node.get_parent().remove_child(node)
		node.free()
	GameClock.paused = f["paused"]
	GameClock.speed = f["speed"]

func test_rain_has_one_fixed_batch_and_wind_is_nearly_horizontal() -> void:
	var f := _fixture()
	var weather: WeatherLayer = f["weather"]
	var mm := weather.rain.multimesh
	check(weather.rain is MultiMeshInstance3D, "rain does not allocate a GPU simulation emitter")
	check(mm.mesh is QuadMesh, "rain uses two-triangle streaks")
	eq(mm.instance_count, 384, "rain budget is fixed rather than the old 2200 particles")
	check(mm.visible_instance_count > 0 and mm.visible_instance_count <= 384, "near rain actually draws within its fixed allocation")
	eq(weather.rain.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "streaks add no shadow pass")
	var wind: Vector3 = weather._rain_material.get_shader_parameter("wind_velocity")
	gt(Vector2(wind.x, wind.z).length(), absf(wind.y) * 3.0, "world-space wind is strongly horizontal instead of vertical falling lines")
	var camera: MapCamera3D = f["camera"]
	camera.rotation.y += PI * 0.5
	weather._process(0.0)
	eq(weather._rain_material.get_shader_parameter("wind_velocity"), wind, "rotating the camera does not rotate the world's wind")
	var count := weather.get_child_count()
	for i in 120: weather._process(1.0 / 60.0)
	eq(weather.get_child_count(), count, "ongoing rain cannot allocate event nodes")
	eq(mm.instance_count, 384, "ongoing rain cannot expand its GPU instance buffer")
	_dispose(f)

func test_rain_clock_is_real_time_and_pause_freezes_rain_and_snow() -> void:
	var f := _fixture()
	var weather: WeatherLayer = f["weather"]
	var before := weather._rain_time
	GameClock.speed = 1
	weather._process(0.05)
	near(weather._rain_time - before, 0.05, 0.000001, "slow simulation uses the same real-second wind step")
	before = weather._rain_time
	GameClock.speed = 5
	weather._process(0.05)
	near(weather._rain_time - before, 0.05, 0.000001, "fast simulation does not accelerate wind")
	GameClock.paused = true
	before = weather._rain_time
	for i in 5: weather._process(0.1)
	near(weather._rain_time, before, 0.0, "paused rain shader phase remains unchanged")
	near(weather._rain_material.get_shader_parameter("rain_time"), before, 0.000001, "shader uses the frozen CPU clock, not TIME")
	weather.force = WeatherLayer.Kind.SNOW
	weather._process(0.1)
	near(weather.snow.speed_scale, 0.0, 0.0, "existing snow simulation also freezes during pause")
	GameClock.paused = false
	weather._process(0.05)
	near(weather.snow.speed_scale, 1.0, 0.0, "snow resumes at normal real speed")
	_dispose(f)

func test_rain_zoom_clear_and_fog_contracts_remain_bounded() -> void:
	var f := _fixture()
	var weather: WeatherLayer = f["weather"]
	var camera: MapCamera3D = f["camera"]
	var explored := Military.fog_levels().duplicate()
	for distance: float in [55, 150, 350, 650]:
		camera.focus_on(Vector2(1000, 1000), distance)
		weather._process(0.05)
		check(weather.rain.multimesh.visible_instance_count <= 384, "zoom never enlarges the rain budget")
		check(weather._rain_material.get_shader_parameter("rain_opacity") <= 0.30, "rain cannot become a white opaque line curtain")
		check(weather.rain.custom_aabb.size.x < 200.0, "bounds remain local, not map-sized")
		ge(weather.rain.global_position.y - weather._rain_bounds.y * 0.5, 0.3, "rain starts above the flat map rather than drawing below it")
	camera.focus_on(Vector2(1000, 1000), WeatherLayer.MAX_VIEW_DIST + 20.0)
	weather._process(0.05)
	check(not weather.rain.visible, "far zoom has no rain draw")
	eq(weather.rain.multimesh.visible_instance_count, 0, "far rain has no visible instances")
	check(not weather.snow.visible and not weather.snow.emitting, "far zoom stops and hides snow")
	camera.focus_on(Vector2(1000, 1000), 150.0)
	weather.force = WeatherLayer.Kind.CLEAR
	weather._process(0.05)
	check(not weather.rain.visible and not weather.snow.visible, "clear weather leaves no stale rain/snow draw")
	eq(Military.fog_levels(), explored, "weather visibility never changes military exploration")
	_dispose(f)
