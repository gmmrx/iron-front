extends "res://tests/test_case.gd"

class PostureLayer extends UnitLayer:
	func _walking(d: Division) -> bool: return not d.path.is_empty() and d.attacking == 0
	func _walk_pos(_d: Division) -> Vector2: return Vector2(500, 500)
	func _walk_dir(_d: Division) -> Vector2: return Vector2.RIGHT
	func _border_spot(own: int, foe: int) -> Vector2: return World.province(own).center + Vector2(10 + foe % 7, 0)

func test_post_stays_put_across_target_changes_and_quiet_hours_but_releases_on_march() -> void:
	for observer: bool in [false, true]:
		Game.observer = observer
		var layer := PostureLayer.new()
		layer.models = UnitModels.new()
		var d := Division.new()
		d.province = World.capital_province(player_tag())
		d.owner = player_tag()
		d.attacking = 11
		var c := {}
		var key := "%d:%s:0:idle" % [d.province, d.owner]
		var first := layer._goal_base(c, key, [d], 0.033, 1)
		d.attacking = 19
		for frame in range(2, 90):
			var next := layer._goal_base(c, key, [d], 0.033, frame)
			eq(next[0], first[0], "combat retargeting cannot relocate the post")
			eq(next[1], first[1], "settled unit cannot jitter while defending")
		d.attacking = 0
		eq(layer._goal_base(c, key, [d], 0.033, 90)[0], first[0], "quiet combat tick does not send soldier to province centre")
		d.path = PackedInt32Array([12])
		eq(layer._goal_base(c, key, [d], 0.033, 91)[0], Vector2(500, 500), "real march/retreat follows its path")
		check(not c.has("post_pid") and not c.has("post_goal"), "movement releases visual post")
		eq(d.path, PackedInt32Array([12]), "presentation never changes orders")
		layer.models.free()
		layer.free()
	Game.observer = false

func test_target_selection_is_stable_when_combat_iteration_order_changes() -> void:
	var layer := UnitLayer.new()
	var old := {1: Vector2(30, 40)}
	for candidates: Array in [[Vector2(20, 40), Vector2(30, 40), Vector2(40, 40)], [Vector2(40, 40), Vector2(30, 40), Vector2(20, 40)]]:
		layer._combat_target.clear()
		for candidate: Vector2 in candidates: layer._choose_combat_target(1, candidate, old)
		eq(layer._combat_target[1], old[1], "still-valid enemy remains the aim point")
	for candidates: Array in [[Vector2(40, 40), Vector2(20, 40)], [Vector2(20, 40), Vector2(40, 40)]]:
		layer._combat_target.clear()
		for candidate: Vector2 in candidates: layer._choose_combat_target(1, candidate, old)
		eq(layer._combat_target[1], Vector2(20, 40), "lost target replacement has deterministic ties")
	layer.free()

func test_marching_faces_route_not_stale_enemy_and_stationary_post_does_not_slide() -> void:
	var layer := UnitLayer.new()
	layer.map = MapView3D.new()
	var root := Node3D.new()
	var fig := Node3D.new()
	fig.set_meta("kind", "soldier")
	root.add_child(fig)
	var top := Node3D.new()
	top.name = "t"
	fig.add_child(top)
	var key := "%d:%s:0:" % [World.capital_province(player_tag()), player_tag()]
	var c := {"root": root, "fig": fig, "tag": player_tag(), "divs": [], "pos0": Vector2(100, 100),
		"walking": true, "mdir": Vector2.RIGHT, "cstate": 1, "ctarget": Vector2(0, 100), "yaw": 0.0}
	layer._counters[key] = c
	var keys: Array[String] = [key]
	for i in 60: layer._place_figures(keys, 1.0 / 30.0)
	near(float(c["yaw"]), 0.0, 0.001, "retreat/march faces travel direction, not the enemy behind")
	check(not c["aim_ready"], "moving unit cannot shoot at stale combat target")
	c["walking"] = false
	c["post_pid"] = World.capital_province(player_tag())
	c["ctarget"] = Vector2(200, 100)
	for i in 90: layer._place_figures(keys, 1.0 / 30.0)
	var settled := root.position
	var yaw := float(c["yaw"])
	for i in 90:
		c["vel"] = Vector2(-100, 100) if i % 2 == 0 else Vector2(100, -100)
		layer._place_figures(keys, 1.0 / 30.0)
		eq(root.position, settled, "stationary post position remains exact")
		near(float(c["yaw"]), yaw, 0.001, "layout velocity cannot turn a posted unit")
	check(c["aim_ready"], "settled facing soldier is allowed to fire")
	layer.map.free()
	root.free()
	layer.free()
