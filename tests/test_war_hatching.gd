extends "res://tests/test_case.gd"
## Analytical cartographic stroke filtering plus the production owner/controller and fixed-world contracts.
const FRONT_SHADER := preload("res://assets/shaders/front_ink.gdshader")
const MAP_SHADER := preload("res://assets/shaders/map3d.gdshader")

func player_tag() -> String: return "GER"

func test_generated_stencil_preserves_alpha_and_mipmaps() -> void:
	var texture: Texture2D = load("res://assets/ui/map/front_comb_perpendicular_v3.png")
	var image := texture.get_image()
	check(image.has_mipmaps(), "distant teeth have a mip chain")
	check(image.get_pixel(100, 100).a < 0.01, "transparent source margin is not a baked backdrop")
	check(image.get_pixel(100, 320).a > 0.9, "continuous spine is present")
	check(image.get_pixel(100, 380).a > 0.9, "perpendicular tooth is present")
	check(image.get_pixel(150, 380).a < 0.01, "open tooth gap stays transparent")

func _integral(phase: float, duty: float) -> float:
	return floorf(phase) * duty + minf(phase - floorf(phase), duty)

func _stroke(phase: float, duty: float, footprint: float) -> float:
	var width := clampf(duty, 0.0, 0.45)
	var span := maxf(footprint, 0.0001)
	var center := fposmod(phase, 1.0) + width * 0.5
	return clampf((_integral(center + span * 0.5, width) - _integral(center - span * 0.5, width)) / span, 0.0, 1.0)

func test_stroke_filter_preserves_thin_ink_area_at_all_zoom_footprints() -> void:
	var duty := 0.56 / 4.8
	for footprint: float in [0.0001, 0.008, 0.06, 0.25, 0.7, 1.0, 2.0, 5.0]:
		var sum := 0.0
		for i in 4096:
			var coverage := _stroke((i + 0.31) / 4096.0, duty, footprint)
			check(coverage >= 0.0 and coverage <= 1.0, "filtered coverage remains bounded")
			sum += coverage
		near(sum / 4096.0, duty, 0.0003, "zoom changes filtering, not ink density/width")
	for phase: float in [-12000.13, -0.01, 0.0, 0.13, 9999.13]:
		near(_stroke(phase, duty, 1.0), duty, 0.000001, "one-period pixels converge to the duty instead of flickering")
	var code := FileAccess.get_file_as_string("res://assets/shaders/occupation_ink.gdshaderinc")
	check(code.contains("fract(phase)"), "large-coordinate integral subtraction stays local and precise")
	check(not code.contains("TIME") and not code.contains("texture(") and not code.contains("for ("), "hatch filter has no time, lookup or ray/sample loop")

func test_front_band_world_dimensions_do_not_follow_camera_zoom() -> void:
	var front := FrontLayer.new()
	front._mat = ShaderMaterial.new()
	front._mat.shader = FRONT_SHADER
	front._mat.set_shader_parameter("period", FrontLayer.HATCH_PERIOD)
	front._mat.set_shader_parameter("band", FrontLayer.HATCH_BAND)
	front._dirty = false
	var camera := MapCamera3D.new()
	front.camera = camera
	front._mi = [MeshInstance3D.new()]
	for distance: float in [55.0, 150.0, 450.0, 1100.0, 2600.0, 5200.0]:
		camera.distance = distance
		front._process(0.0)
		near(front._mat.get_shader_parameter("period"), 4.0, 0.000001, "fixed world hatch spacing")
		near(front._mat.get_shader_parameter("band"), 8.0, 0.000001, "larger fixed world hatch width")
		check(front._mi[0].visible, "one geometry survives every zoom without a LOD pop")
	near(FrontLayer.LIFT, 0.06, 0.000001, "ink is on the flat map, not suspended above it")
	var code := FileAccess.get_file_as_string("res://assets/shaders/front_ink.gdshader")
	check(not code.contains("TIME"), "front opacity does not shimmer/pulse independently of the game")
	check(code.contains("held <= 0") and code.contains("side_controls"), "front fragment masks water and unrelated controller land")
	check(code.contains("textureGrad") and code.contains("dFdx(stencil_uv)"), "unwrapped gradients prevent repeat seam shimmer")
	check(not code.contains("edge_distance *"), "teeth are perpendicular, never diagonally sheared")
	check(not code.contains("attack_len") and not code.contains("battle_tex"), "combat does not deform the border or upload a battle mask")
	check(code.contains("float(held) != side_controls.x && float(held) != side_controls.y"), "smooth ribbon excludes unrelated territory without staircase cuts")
	check(code.contains("marks *= step(0.5, y)"), "teeth only appear on the opposing side")
	check(code.contains("max(1.5,"), "border backbone is thicker independently of teeth")
	for node: MeshInstance3D in front._mi: node.free()
	front.free()
	camera.free()

func test_tight_turns_limit_offset_before_the_ribbon_can_fold() -> void:
	near(FrontLayer.bend_width_scale(Vector2(-1, 0), Vector2.ZERO, Vector2(1, 0)), 1.0, 0.001, "straight border keeps width")
	var bend := FrontLayer.bend_width_scale(Vector2(-1, 0), Vector2.ZERO, Vector2(0, 1))
	check(bend > 0.0 and bend < 0.3, "tight corners shrink inside local curvature radius")
	var hairpin := FrontLayer.bend_width_scale(Vector2(-1, 0), Vector2.ZERO, Vector2(-0.99, 0.01))
	check(hairpin < bend, "hairpins shrink more than right angles")

func test_occupation_data_uses_original_owner_and_current_controller() -> void:
	var pid := World.capital_province("POL")
	var state: StateRegion = World.state_of_province(pid)
	var original := state.owner
	World.set_controller(pid, "GER")
	var map := MapView3D.new()
	map._material = ShaderMaterial.new()
	map._material.shader = MAP_SHADER
	map.rebuild_province_data()
	var data := map._data_texture.get_image().get_data()
	eq(data[pid * 4], country(original).index, "occupation preserves original state owner")
	eq(data[pid * 4 + 1], country("GER").index, "occupation stripe gets occupier/controller")
	eq(data[pid * 4 + 2] + data[pid * 4 + 3] * 256, state.id, "state identity unchanged")
	eq(state.owner, original, "render packing cannot annex/change ownership")
	var code := FileAccess.get_file_as_string("res://assets/shaders/map3d.gdshader")
	check(code.contains("ctl > 0 && ctl != owner && map_mode == 2"), "existing occupied-state mode/eligibility remains unchanged")
	check(code.find("occupation_ink(uv * map_size") < code.find("// province ve eyalet sınırları"), "state/country lines paint above hatch instead of getting covered")
	check(not code.contains("float stripe = step(0.5"), "old aliased half-filled stripes removed")
	check(code.contains("if (fog_enabled)"), "existing FoW color pass remains")
	map.free()

func test_front_pairs_follow_control_without_changing_war_or_fog_rules() -> void:
	country("GER").war_goals["POL"] = true
	check(Diplomacy.declare_war("GER", "POL"), "real war fixture declared")
	var front := FrontLayer.new()
	var pairs := front.front_pairs()
	gt(pairs.size(), 0, "real GER/POL border has a front")
	for pair: Array in pairs:
		check(World.province(pair[0]).is_land() and World.province(pair[1]).is_land(), "front remains land/land only")
		check(FrontPanel.side(World.controller_tag(pair[0])) == 1 and FrontPanel.side(World.controller_tag(pair[1])) == 2,
			"front uses current war sides/controllers, not historical country borders")
	var before := World.controller.duplicate()
	var old_fog := Military.fog_enabled
	Military.fog_enabled = true
	eq(front.front_pairs(), pairs, "render redesign does not alter persistent FoW/front-pair gameplay semantics")
	eq(World.controller, before, "front queries cannot mutate control")
	Military.fog_enabled = old_fog
	front.free()
