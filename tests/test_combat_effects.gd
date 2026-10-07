extends "res://tests/test_case.gd"
## Shared-renderer safety at the public event/advance boundary, without a full terrain or GPU preview.

class ProbeMap extends Node3D:
	var known_pid := 0
	var unknown_pid := 0
	var all_hidden := false
	func province_at(p: Vector2) -> int:
		return unknown_pid if all_hidden or p.x >= 5.0 else known_pid
	func height_at(_p: Vector2) -> float:
		return 0.0

func _fixture() -> Dictionary:
	var old_paused := GameClock.paused
	var old_fog := Military.fog_enabled
	var old_observer := Game.observer
	GameClock.paused = false
	var tree := Engine.get_main_loop() as SceneTree
	var map := ProbeMap.new()
	map.known_pid = World.capital_province(World.player_tag)
	map.unknown_pid = World.capital_province("SWE")
	tree.root.add_child(map)
	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.far = 10000.0
	tree.root.add_child(camera)
	camera.position = Vector3(0.0, 180.0, 180.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var fx := CombatEffects.new()
	fx.configure(map, camera)
	tree.root.add_child(fx)
	fx.set_process(false) # Tests own the real-second clock, not the scene's automatic delta.
	var target := Node3D.new()
	map.add_child(target)
	target.position = Vector3(0.0, 1.0, 0.0)
	return {"fx": fx, "map": map, "camera": camera, "target": target,
		"paused": old_paused, "fog": old_fog, "observer": old_observer}

func _dispose(f: Dictionary) -> void:
	for key: String in ["fx", "map", "camera"]:
		var node: Node = f[key]
		if node.is_inside_tree():
			node.get_parent().remove_child(node)
		node.free()
	GameClock.paused = f["paused"]
	Military.fog_enabled = f["fog"]
	Game.observer = f["observer"]

func _drawn(fx: CombatEffects) -> int:
	var total := 0
	for node: Node in fx.get_children():
		if node is MultiMeshInstance3D:
			total += (node as MultiMeshInstance3D).multimesh.visible_instance_count
	return total

func _assert_no_live_visuals(fx: CombatEffects, context: String) -> void:
	eq(_drawn(fx), 0, context + ": no visible batch instances")
	for node: Node in fx.get_children():
		if node is Light3D:
			check(not (node as Light3D).visible, context + ": no flash light leaks into the terrain")

func test_repeated_events_keep_fixed_geometry_and_bounded_active_capacity() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	check(fx.textures_ready, "all shipped explosion, smoke and water atlases load")
	var node_count := fx.get_child_count()
	var allocations: Array[int] = []
	for node: Node in fx.get_children():
		if node is MultiMeshInstance3D:
			allocations.append((node as MultiMeshInstance3D).multimesh.instance_count)
	for i in 160:
		fx.impact(Vector3.ZERO, "bomb", 1.0)
		fx.muzzle(Vector3(0, 3, 0), Vector3.RIGHT, "cannon", 1.0)
		fx.projectile(Vector3(0, 3, 0), Vector3(2, 0, 0), "cannon", 1.0)
		fx.trail(f["target"], 1.0, 0.3, true)
	fx.advance(0.025)
	var stats := fx.stats()
	gt(stats["active"], 100, "stress fixture actually filled a substantial live effect pool")
	check(int(stats["active"]) <= int(stats["capacity"]), "event saturation cannot exceed the advertised total capacity")
	check(int(stats["capacity"]) <= 600, "the shared whole-scene particle budget stays compact")
	gt(stats["dropped"], 0, "saturation drops cosmetic work rather than expanding the pool")
	check(int(stats["trails"]) <= CombatEffects.MAX_TRAILS, "repeated event trails are also bounded")
	eq(fx.get_child_count(), node_count, "hundreds of events allocate no emitter or light nodes")
	var batch_index := 0
	for node: Node in fx.get_children():
		check(not (node is GPUParticles3D or node is CPUParticles3D), "shared events never create per-emitter particle nodes")
		if node is MultiMeshInstance3D:
			var mesh := (node as MultiMeshInstance3D).multimesh
			eq(mesh.instance_count, allocations[batch_index], "preallocated batch geometry never grows")
			check(mesh.visible_instance_count <= mesh.instance_count, "drawn instances remain within the fixed GPU allocation")
			batch_index += 1
	eq(batch_index, 4, "all event profiles share four fixed render batches")
	_dispose(f)

func test_pause_freezes_existing_particles_trails_and_batch_transforms() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	fx.impact(Vector3.ZERO, "shell", 1.0)
	fx.projectile(Vector3(0, 3, 0), Vector3(2, 0, 0), "cannon", 1.0)
	fx.trail(f["target"], 1.0, 3.0, true)
	fx.advance(0.025)
	gt(_drawn(fx), 0, "pause fixture has real visible instances")
	var snapshot: Array = []
	for particle in fx._particles:
		snapshot.append([particle.age, particle.pos, particle.vel, particle.angle])
	var stats := fx.stats().duplicate()
	var trail_left: float = fx._trails[0]["left"]
	var light_life: Array = fx._light_life.duplicate()
	var transforms: Array = []
	for node: MultiMeshInstance3D in fx._batches:
		var batch: Array = []
		for i in node.multimesh.visible_instance_count:
			batch.append(node.multimesh.get_instance_transform(i))
		transforms.append(batch)
	GameClock.paused = true
	# All public event entry points must reject new cosmetic work while paused,
	# without using a pause check in the visibility predicate that draws existing effects.
	fx.muzzle(Vector3(0, 3, 0), Vector3.RIGHT, "cannon", 1.0)
	fx.projectile(Vector3(0, 3, 0), Vector3(2, 0, 0), "cannon", 1.0)
	fx.tracer(Vector3(0, 3, 0), Vector3(2, 0, 0), 180.0, 1.0)
	fx.impact(Vector3.ZERO, "bomb", 1.0)
	fx.smoke(Vector3(0, 2, 0), 1.0, true)
	fx.trail(f["target"], 1.0, 3.0, true)
	eq(fx.stats(), stats, "paused public APIs do not allocate particles/trails or increment emitted/dropped")
	eq(fx._light_life, light_life, "paused muzzle/impact calls do not allocate a flash light")
	for i in 8:
		fx.advance(0.5)
	eq(fx.stats(), stats, "pause does not advance, expire or create effects")
	near(fx._trails[0]["left"], trail_left, 0.0, "trail duration freezes with the game clock")
	eq(fx._particles.size(), snapshot.size(), "pause keeps the same live particle set")
	for i in mini(fx._particles.size(), snapshot.size()):
		var particle = fx._particles[i]
		eq([particle.age, particle.pos, particle.vel, particle.angle], snapshot[i], "age and motion freeze while paused")
	for i in fx._batches.size():
		var mesh: MultiMesh = fx._batches[i].multimesh
		eq(mesh.visible_instance_count, transforms[i].size(), "paused visibility stays stable")
		for j in mini(mesh.visible_instance_count, transforms[i].size()):
			check(mesh.get_instance_transform(j).is_equal_approx(transforms[i][j]), "paused world-space effect transform stays unchanged")
	GameClock.paused = false
	fx.advance(0.05)
	check(fx._particles[0].age > float(snapshot[0][0]), "effects resume after unpausing")
	_dispose(f)

func test_expiry_returns_all_transients_to_idle_without_event_node_growth() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	var node_count := fx.get_child_count()
	for i in 12:
		fx.impact(Vector3.ZERO, "shell", 1.0)
	fx.projectile(Vector3(0, 2, 0), Vector3(2, 0, 0), "cannon", 1.0)
	fx.trail(f["target"], 1.0, 0.3, true)
	fx.advance(0.025)
	gt(fx.stats()["active"], 0, "expiry fixture begins with live effects")
	for i in 220:
		fx.advance(0.1)
	eq(fx.stats()["active"], 0, "particles, delayed smoke, projectiles and scorches expire")
	eq(fx.stats()["trails"], 0, "finite trails expire instead of retaining their target")
	_assert_no_live_visuals(fx, "expired renderer")
	eq(fx.get_child_count(), node_count, "expiry leaves only the original reusable batch/light nodes")
	fx.impact(Vector3.ZERO, "water", 1.0)
	fx.advance(0.025)
	gt(_drawn(fx), 0, "idle allocations can immediately render another event")
	eq(fx.get_child_count(), node_count, "reuse does not create an emitter node")
	_dispose(f)

func test_far_zoom_clears_transients_even_if_the_game_is_paused() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	var camera: Camera3D = f["camera"]
	fx.impact(Vector3.ZERO, "shell", 1.0)
	fx.trail(f["target"], 1.0, 5.0, true)
	fx.advance(0.025)
	gt(_drawn(fx), 0, "near fixture drew effects before zooming out")
	GameClock.paused = true
	camera.position.y = CombatEffects.MAX_DISTANCE + 30.0
	fx.advance(0.5)
	eq(fx.stats()["active"], 0, "far zoom clears particles rather than retaining hidden transients")
	eq(fx.stats()["trails"], 0, "far zoom clears moving trails")
	_assert_no_live_visuals(fx, "far renderer")
	var emitted: int = fx.stats()["emitted"]
	fx.impact(Vector3.ZERO, "shell", 1.0)
	eq(fx.stats()["emitted"], emitted, "far events are rejected before allocation")
	_dispose(f)

func test_unknown_points_reject_events_and_live_effects_never_reveal_fog() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	var map: ProbeMap = f["map"]
	Military.fog_enabled = true
	Game.observer = false
	Military.invalidate_fog()
	check(Military.is_visible(map.known_pid), "fixture has an explored own province")
	check(not Military.is_visible(map.unknown_pid), "fixture has a genuinely unknown foreign province")
	var emitted: int = fx.stats()["emitted"]
	fx.impact(Vector3(8, 0, 0), "bomb", 1.0)
	fx.muzzle(Vector3(8, 2, 0), Vector3.RIGHT, "cannon", 1.0)
	fx.smoke(Vector3(8, 2, 0), 1.0, true)
	fx.projectile(Vector3(8, 2, 0), Vector3(0, 0, 0), "cannon", 1.0)
	fx.tracer(Vector3(8, 2, 0), Vector3(0, 0, 0), 180.0, 1.0)
	(f["target"] as Node3D).position = Vector3(8, 2, 0)
	fx.trail(f["target"], 1.0, 3.0, true)
	eq(fx.stats()["emitted"], emitted, "unknown-origin effects are rejected before consuming budget")
	eq(fx.stats()["trails"], 0, "unknown moving targets cannot reserve a smoke/fire trail")
	_assert_no_live_visuals(fx, "unknown event")
	fx.impact(Vector3.ZERO, "shell", 1.0)
	fx.advance(0.025)
	gt(_drawn(fx), 0, "explored fixture visibly rendered the event")
	# Visibility can change while paused (player/observer switch). Neither cards nor flash lights may leak.
	GameClock.paused = true
	map.all_hidden = true
	fx.advance(0.5)
	_assert_no_live_visuals(fx, "live event becomes unknown while paused")
	GameClock.paused = false
	fx.advance(0.025)
	eq(fx.stats()["active"], 0, "hidden particles are retired once their clock resumes")
	_assert_no_live_visuals(fx, "hidden resumed renderer")
	_dispose(f)

func test_cosmetic_events_do_not_advance_global_gameplay_rng() -> void:
	var expected: Array[int] = []
	seed(19361006)
	for i in 12:
		expected.append(randi())
	seed(19361006)
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	for i in 16:
		fx.impact(Vector3.ZERO, "shell", 1.0)
		fx.muzzle(Vector3(0, 2, 0), Vector3.RIGHT, "cannon", 1.0)
		fx.smoke(Vector3(0, 2, 0), 1.0, true)
		fx.projectile(Vector3(0, 2, 0), Vector3(2, 0, 0), "cannon", 1.0)
	fx.advance(0.1)
	_dispose(f)
	var actual: Array[int] = []
	for i in 12:
		actual.append(randi())
	eq(actual, expected, "creating/updating effect resources and events leaves the global gameplay RNG sequence untouched")

func test_water_impact_uses_liquid_flipbook_without_fire_scorch_or_flash() -> void:
	var f := _fixture()
	var fx: CombatEffects = f["fx"]
	fx.impact(Vector3.ZERO, "water", 1.0)
	fx.advance(0.05)
	var liquid := 0
	for particle in fx._particles:
		if particle.batch == CombatEffects.Batch.SPRITE:
			check(particle.kind != 0 and particle.kind != 2, "water does not produce explosion or burning sprites")
			if particle.kind == 3: liquid += 1
		if particle.batch == CombatEffects.Batch.GROUND:
			check(particle.kind != 1, "water does not leave a scorch decal")
	eq(liquid, 1, "water uses one dedicated animated liquid sprite")
	for light: Light3D in fx._lights:
		check(not light.visible, "water impact does not emit a fiery flash light")
	gt(_drawn(fx), 0, "water still produces visible foam, mist and droplets")
	_dispose(f)
