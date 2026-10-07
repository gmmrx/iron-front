extends "res://tests/test_case.gd"
## Ground event contract, without loading figure art or creating particle nodes.

class RecordingFX extends CombatEffects:
	var events: Array[Dictionary] = []
	func muzzle(at: Vector3, direction: Vector3, weapon: String = "rifle", size: float = 1.0) -> void:
		events.append({"event": "muzzle", "at": at, "direction": direction, "weapon": weapon, "size": size})
	func projectile(from: Vector3, to: Vector3, weapon: String = "rifle", size: float = 1.0) -> void:
		events.append({"event": "projectile", "from": from, "to": to, "weapon": weapon, "size": size})
	func impact(at: Vector3, kind: String = "shell", size: float = 1.0) -> void:
		events.append({"event": "impact", "at": at, "kind": kind, "size": size})
	func smoke(at: Vector3, size: float = 1.0, dark: bool = false, drift: Vector3 = Vector3(0.3, 0.8, 0.1)) -> void:
		events.append({"event": "smoke", "at": at, "size": size, "dark": dark, "drift": drift})

func _fixture(kind: String = "soldier") -> Dictionary:
	var map := MapView3D.new()
	var fx := RecordingFX.new()
	var layer := UnitLayer.new()
	layer.map = map
	layer.combat_effects = fx
	layer._was_far = 0
	var root := Node3D.new()
	root.position = Vector3(9120.0, 0.05, 3200.0)
	Engine.get_main_loop().root.add_child(root)
	var fig := Node3D.new()
	fig.set_meta("kind", kind)
	fig.scale = Vector3.ONE * UnitLayer.FIG_SIZE
	root.add_child(fig)
	var top := Node3D.new()
	top.name = "t"
	top.position.y = 0.5
	top.rotation.y = 0.6
	fig.add_child(top)
	var c := {"root": root, "fig": fig, "divs": [], "yaw": 0.6, "cstate": 1,
		"ctarget": Vector2(9140.0, 3190.0), "shot_weapon": UnitLayer._combat_weapon(fig),
		"shot_t": 0.0, "shell_t": 99.0, "haze_t": 99.0}
	layer._counters["counter"] = c
	layer._glowing.append("counter")
	return {"map": map, "fx": fx, "layer": layer, "root": root, "fig": fig, "top": top, "counter": c}

func _dispose(f: Dictionary) -> void:
	(f["layer"] as UnitLayer).free()
	(f["root"] as Node3D).free()
	(f["fx"] as CombatEffects).free()
	(f["map"] as MapView3D).free()

func test_muzzle_uses_actual_transformed_socket_and_weapon_axis() -> void:
	var paused := GameClock.paused
	GameClock.paused = false
	for kind: String in ["soldier", "tank"]:
		var f := _fixture(kind)
		var layer: UnitLayer = f["layer"]
		var fx: RecordingFX = f["fx"]
		var top: Node3D = f["top"]
		var socket := top.global_transform
		var local_direction := Vector3(cos(UnitFigures.aim_yaw(kind)), 0.0, -sin(UnitFigures.aim_yaw(kind)))
		layer._fire(f["counter"], f["fig"], Vector2(9140, 3190))
		eq(fx.events.size(), 2, "one shared muzzle event and one timed projectile event")
		if fx.events.size() == 2:
			var muzzle: Dictionary = fx.events[0]
			var projectile: Dictionary = fx.events[1]
			near((muzzle["at"] as Vector3).distance_to(socket * UnitFigures.muzzle(kind)), 0.0, 0.001,
				kind + " uses the model-specific muzzle, including figure scale and top rotation")
			near((muzzle["direction"] as Vector3).distance_to((socket.basis * local_direction).normalized()), 0.0, 0.001,
				kind + " flame points down the real barrel/rifle axis")
			near((muzzle["direction"] as Vector3).length(), 1.0, 0.001, "direction is not multiplied by miniature scale")
			eq(muzzle["weapon"], "cannon" if kind == "tank" else "rifle", "weapon profile follows figure kind")
			eq(projectile["weapon"], muzzle["weapon"], "projectile and muzzle share the weapon profile")
			eq(projectile["from"], muzzle["at"], "round starts at the muzzle, not the counter center")
			near((projectile["to"] as Vector3).y, 0.15, 0.001, "timed impact ends at the flat map surface")
			eq(muzzle["size"], 1.0, "effects have constant world size at the canonical miniature scale")
		eq(layer.get_child_count(), 0, "ground hookup does not create per-event FX nodes")
		_dispose(f)
	GameClock.paused = paused

func test_hit_pose_is_damped_without_time_based_jitter_or_body_scaling() -> void:
	var f := _fixture()
	var layer: UnitLayer = f["layer"]
	var c: Dictionary = f["counter"]
	var top: Node3D = f["top"]
	c["recoil"] = 0.5
	c["shake"] = 0.5
	c["duck"] = 0.5
	layer._anim_t = 0.0
	layer._pose(c, f["fig"], 0.0)
	var original := top.transform
	layer._anim_t = 123.45
	layer._pose(c, f["fig"], 0.0)
	check(top.transform.is_equal_approx(original), "clock phase cannot vibrate a stationary hit pose")
	near(top.basis.get_scale().distance_to(Vector3.ONE), 0.0, 0.0001, "soldier is never squashed or inflated")
	for i in 60: layer._pose(c, f["fig"], 1.0 / 30.0)
	near(top.position.distance_to(Vector3(0, 0.5, 0)), 0.0, 0.001, "recoil returns fully to the firing position")
	_dispose(f)

func test_cannon_and_rifle_have_separate_non_burst_cadences() -> void:
	var paused := GameClock.paused
	var figures := UnitLayer.FIGURES
	GameClock.paused = false
	UnitLayer.FIGURES = true
	for kind: String in ["soldier", "tank"]:
		var f := _fixture(kind)
		var layer: UnitLayer = f["layer"]
		var fx: RecordingFX = f["fx"]
		var c: Dictionary = f["counter"]
		c["walking"] = true
		layer._combat_fx(0.01)
		eq(fx.events.size(), 0, "marching/retreating soldiers cannot fire backwards")
		c["walking"] = false
		c["aim_ready"] = false
		layer._combat_fx(0.01)
		eq(fx.events.size(), 0, "soldier must face target before firing")
		c["aim_ready"] = true
		layer._combat_fx(0.01)
		eq(fx.events.size(), 2, "one shot dispatches just muzzle plus projectile")
		var gap := UnitLayer.CANNON_GAP if kind == "tank" else UnitLayer.RIFLE_GAP
		ge(c["shot_t"], gap.x, kind + " respects minimum firing interval")
		check(float(c["shot_t"]) <= gap.y, kind + " respects maximum firing interval")
		for i in 5:
			layer._combat_fx(0.05)
		eq(fx.events.size(), 2, "no continuous beam or frame-by-frame re-firing")
		_dispose(f)
	gt(UnitLayer.CANNON_GAP.x, UnitLayer.RIFLE_GAP.y, "even the fastest cannon reload is slower than a rifle")
	GameClock.paused = paused
	UnitLayer.FIGURES = figures

func test_pause_freezes_shots_timers_and_recoil_pose() -> void:
	var paused := GameClock.paused
	var f := _fixture("tank")
	var layer: UnitLayer = f["layer"]
	var fx: RecordingFX = f["fx"]
	var c: Dictionary = f["counter"]
	c["recoil"] = 0.8
	c["shake"] = 0.7
	var pose := (f["top"] as Node3D).transform
	GameClock.paused = true
	layer._combat_fx(0.5)
	layer._fire(c, f["fig"], c["ctarget"])
	layer._shell(c["ctarget"])
	layer._haze(Vector2(9120, 3200), c["ctarget"])
	eq(fx.events.size(), 0, "paused combat sends no shared FX events")
	eq(c["shot_t"], 0.0, "reload does not advance while paused")
	eq(c["recoil"], 0.8, "recoil does not advance while paused")
	eq((f["top"] as Node3D).transform, pose, "figure combat pose remains fixed while paused")
	_dispose(f)
	GameClock.paused = paused

func test_offscreen_and_far_visible_counters_do_not_dispatch() -> void:
	var paused := GameClock.paused
	var figures := UnitLayer.FIGURES
	GameClock.paused = false
	UnitLayer.FIGURES = true
	var f := _fixture()
	var layer: UnitLayer = f["layer"]
	var fx: RecordingFX = f["fx"]
	var camera := MapCamera3D.new()
	camera.distance = 200.0
	camera.target = Vector3.ZERO
	layer.camera = camera
	layer._combat_fx(0.1)
	eq(fx.events.size(), 0, "renderer-visible nodes outside the camera region do not consume FX budget")
	eq(f["counter"]["shot_t"], 0.0, "offscreen counters do not advance shot dispatch timers")
	camera.target = (f["root"] as Node3D).position
	camera.distance = UnitLayer.CARD_DIST + 1.0
	layer._combat_fx(0.1)
	eq(fx.events.size(), 0, "stale near-figure visibility cannot dispatch beyond the figure zoom limit")
	camera.free()
	_dispose(f)
	GameClock.paused = paused
	UnitLayer.FIGURES = figures

func test_shell_and_sparse_haze_use_shared_effects_only() -> void:
	var paused := GameClock.paused
	GameClock.paused = false
	var f := _fixture()
	var layer: UnitLayer = f["layer"]
	var fx: RecordingFX = f["fx"]
	layer._shell(Vector2(9140, 3190))
	layer._haze(Vector2(9120, 3200), Vector2(9140, 3190))
	eq(fx.events.size(), 2, "incoming shell and background haze are shared renderer events")
	if fx.events.size() == 2:
		eq(fx.events[0]["event"], "impact", "shell creates one compound impact instead of individual sprite nodes")
		eq(fx.events[0]["kind"], "shell", "shell uses the heavy impact profile")
		eq(fx.events[1]["event"], "smoke", "haze uses the shared smoke profile")
		check(not fx.events[1]["dark"], "background haze is not opaque burning-wreck smoke")
		lt(fx.events[1]["size"], 1.0, "background smoke stays smaller than a main explosion")
	gt(UnitLayer.HAZE_GAP.x, 4.0, "background smoke does not build up every second")
	eq(layer.get_child_count(), 0, "no old per-node ground particle pool is created")
	_dispose(f)
	GameClock.paused = paused
