extends "res://tests/test_case.gd"
## Discovery remains gameplay state; its visual helper only builds a small cached 2D mask.

func player_tag() -> String:
	return "GER"

func _fog() -> CloudFog:
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0 / 255.0, 0.0, 0.0, 0.0))
	var fog := CloudFog.new()
	fog.setup(ImageTexture.create_from_image(image), Vector2(64, 32), true)
	return fog

func test_discovery_visual_allocates_only_a_cached_2d_mask() -> void:
	var fog := _fog()
	eq(fog.get_child_count(), 1, "only the mask viewport is allocated")
	eq(fog._mask_vp.size, Vector2i(4, 2), "mask follows the existing low-resolution CELL contract")
	check(fog._mask_vp.disable_3d, "discovery mask has no 3D rendering")
	eq(fog._mask_vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "mask does not render every frame")
	eq(fog.find_children("*", "MeshInstance3D", true, false).size(), 0, "no discovery cloud box or mesh")
	check(not fog.has_method("_noise"), "no runtime 3D noise allocation path")
	check(fog.mask_texture() != null, "existing terrain shader still receives the discovery mask")
	var levels := Image.create(256, 1, false, Image.FORMAT_R8)
	fog.set_fog(ImageTexture.create_from_image(levels))
	eq(fog._mask_vp.render_target_update_mode, SubViewport.UPDATE_ONCE, "discovery changes request a single mask draw")
	fog.set_fade(0.0)
	fog.prewarm(3)
	eq(fog.get_child_count(), 1, "legacy fade/prewarm APIs cannot create a volume")
	fog.clear()
	eq(fog._mask_vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "disabled FoW does not keep rendering")
	fog.free()

func test_unit_air_fleet_and_building_rules_do_not_need_cloud_geometry() -> void:
	Military.fog_enabled = true
	Military.invalidate_fog()
	var unknown := World.capital_province("SWE")
	var state: StateRegion = World.states[country("SWE").capital_state]
	var enemy: Division = Military._create(country("SWE"), 0, unknown, 1.0, 0)
	var fog := _fog()
	fog.clear()
	fog.set_fade(0.0)
	check(Military.hidden(enemy), "unknown foreign division stays hidden with no cloud volume")
	check(Military.hidden_at("SWE", unknown), "foreign fleet/air shared discovery gate stays hidden")
	check(not Military.hidden_at("GER", unknown), "own fleet/air is never hidden by lack of discovery")
	check(Military.state_fogged(state), "unknown foreign building state stays hidden")
	var wing := AirWing.new()
	wing.owner = "SWE"
	wing.planes = 50
	wing.base = state.id
	wing.zone = unknown
	wing.mission = AirWing.Mission.SUPERIORITY
	var air := AirLayer.new()
	check(air._fogged(wing), "foreign aircraft mission remains filtered independently of clouds")
	wing.mission = AirWing.Mission.IDLE
	check(air._fogged(wing), "foreign aircraft base remains filtered independently of clouds")
	Game.observer = true
	check(not Military.hidden(enemy), "observer still sees unknown divisions")
	check(not Military.hidden_at("SWE", unknown), "observer still sees unknown fleets and air")
	check(not Military.state_fogged(state), "observer still sees unknown buildings")
	check(not air._fogged(wing), "observer aircraft remains visible")
	Game.observer = false
	air.free()
	fog.free()

func test_map_discovery_tint_is_subtle_and_has_no_noise_loop() -> void:
	var source := FileAccess.get_file_as_string("res://assets/shaders/map3d.gdshader")
	var block := source.substr(source.find("// Only a subtle unexplored tint"))
	block = block.substr(0, block.find("// ülke adları"))
	check(block.contains("texture(fog_mask, uv).r"), "unexplored cue still comes from discovery")
	check(block.contains("0.08 * fog_fade"), "existing subtle 8% shade and transition are preserved")
	check(block.contains("vec3(0.53, 0.59, 0.64)"), "native neutral tint matches the existing web map")
	check(not block.contains("cloud_fbm") and not block.contains("TIME"), "unknown map pixels do not evaluate cloud noise each frame")
