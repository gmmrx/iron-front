extends "res://tests/test_case.gd"
## Only aircraft bomb/crash scale grows. Ground shell artwork and shared budgets stay unchanged.

class ProbeMap extends MapView3D:
	var pid := 0
	func province_at(_p: Vector2) -> int: return pid
	func height_at(_p: Vector2) -> float: return 0.0

class RecordingFX extends CombatEffects:
	var events: Array[Dictionary] = []
	func impact(at: Vector3, kind: String = "shell", scale: float = 1.0) -> void:
		events.append({"at": at, "kind": kind, "scale": scale})

func _sea() -> int:
	for province: Province in World.provinces:
		if province != null and province.type == Province.Type.SEA: return province.id
	return 0

func test_aircraft_dispatch_larger_single_bomb_and_crash_profiles() -> void:
	var paused := GameClock.paused
	GameClock.paused = false
	var map := ProbeMap.new()
	map.pid = World.capital_province(World.player_tag)
	var fx := RecordingFX.new()
	var air := AirLayer.new()
	air.map = map
	air.combat_effects = fx
	air._blast(Vector3.ZERO, World.player_tag, map.pid)
	air._crash_impact(Vector3.ZERO, World.player_tag, map.pid)
	eq(fx.events.size(), 2, "one bomb and one crash dispatch only two compound events")
	if fx.events.size() == 2:
		eq(fx.events[0]["kind"], "bomb", "bomb keeps its dedicated shared profile")
		eq(fx.events[1]["kind"], "crash", "crash keeps its dedicated shared profile")
		ge(float(fx.events[0]["scale"]) / 1.25, 1.5, "bomb silhouette is at least 1.5× larger")
		check(float(fx.events[0]["scale"]) / 1.25 <= 1.8, "bomb growth stays within the requested range")
		ge(float(fx.events[1]["scale"]) / 1.6, 1.5, "crash silhouette is at least 1.5× larger")
		check(float(fx.events[1]["scale"]) / 1.6 <= 1.8, "crash growth stays within the requested range")
	map.pid = _sea()
	air._blast(Vector3.ZERO, World.player_tag, map.pid)
	air._crash_impact(Vector3.ZERO, World.player_tag, map.pid)
	eq(fx.events.size(), 4, "water landings still dispatch exactly one event each")
	if fx.events.size() == 4:
		eq(fx.events[2]["kind"], "water", "bomb in water has no invented fireball/scorch")
		eq(fx.events[3]["kind"], "water", "crash in water retains the splash profile")
	GameClock.paused = true
	air._blast(Vector3.ZERO, World.player_tag, map.pid)
	air._crash_impact(Vector3.ZERO, World.player_tag, map.pid)
	eq(fx.events.size(), 4, "pause cannot dispatch enlarged aircraft impacts")
	GameClock.paused = false
	Military.fog_enabled = true
	Military.invalidate_fog()
	map.pid = World.capital_province("SWE")
	air._blast(Vector3.ZERO, "SWE", map.pid)
	air._crash_impact(Vector3.ZERO, "SWE", map.pid)
	eq(fx.events.size(), 4, "unknown aircraft do not reveal larger explosions through FoW")
	air.free()
	fx.free()
	map.free()
	GameClock.paused = paused

func test_shared_silhouette_grows_without_more_particles_or_ground_changes() -> void:
	var paused := GameClock.paused
	GameClock.paused = false
	var map := ProbeMap.new()
	map.pid = World.capital_province(World.player_tag)
	var camera := Camera3D.new()
	Engine.get_main_loop().root.add_child(camera)
	camera.position = Vector3(0, 180, 180)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var fx := CombatEffects.new()
	fx.configure(map, camera)
	Engine.get_main_loop().root.add_child(fx)
	fx.set_process(false)
	var budgets: int = fx.stats()["capacity"]
	for profile: Array in [["bomb", 1.25, AirLayer.BOMB_IMPACT_SCALE], ["crash", 1.6, AirLayer.CRASH_IMPACT_SCALE]]:
		fx._rng.seed = 19361006
		fx.impact(Vector3.ZERO, profile[0], profile[1])
		var previous_size: Vector2 = fx._particles[0].size
		var previous_count: int = fx.stats()["active"]
		fx.clear_all()
		fx._rng.seed = 19361006
		fx.impact(Vector3.ZERO, profile[0], profile[2])
		near(fx._particles[0].size.x / previous_size.x, float(profile[2]) / float(profile[1]), 0.00001, "actual shared billboard silhouette follows the aircraft-only scale")
		eq(fx.stats()["active"], previous_count, "larger silhouette adds no particles or batches")
		eq(fx.stats()["capacity"], budgets, "shared effect capacity remains unchanged")
		fx.clear_all()
	fx.impact(Vector3.ZERO, "shell", 1.0)
	near(fx._particles[0].size.x, 8.4, 0.00001, "liked ground/tank shell silhouette remains unchanged")
	eq(CombatEffects.MAX_DISTANCE, 580.0, "shared far-distance budget is not extended")
	fx.free()
	camera.free()
	map.free()
	GameClock.paused = paused
