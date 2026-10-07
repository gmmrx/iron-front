extends "res://tests/test_case.gd"

func player_tag() -> String: return "GER"

func test_tooltips_keep_gold_but_use_regular_body_font() -> void:
	for tooltip: Control in [HoverTooltip.new(), MapTooltip.new()]:
		(Engine.get_main_loop() as SceneTree).root.add_child(tooltip)
		var title := tooltip.get("_title") as Label
		eq(title.get_theme_font("font"), UiTheme.get_theme().default_font, "tooltip title uses ordinary font")
		eq(title.get_theme_color("font_color"), UiTheme.ACCENT, "gold accent remains unchanged")
		tooltip.free()

func test_day_night_starts_disabled_and_only_fades_in_when_enabled() -> void:
	var cycle := DayNight.new()
	var map := MapView3D.new()
	map._material = ShaderMaterial.new()
	map._material.shader = preload("res://assets/shaders/map3d.gdshader")
	var sun := DirectionalLight3D.new()
	cycle.setup(map, null, sun, Environment.new())
	check(not cycle.enabled, "country selection starts in daylight")
	cycle._process(1.0)
	near(cycle._strength, 0.0, 0.001, "disabled cycle never shades half the menu map")
	cycle.enabled = true
	cycle._process(1.0)
	check(cycle._strength > 0.0 and cycle._strength < 1.0, "gameplay fades into the cycle")
	cycle.enabled = false
	cycle._process(0.01)
	near(cycle._strength, 0.0, 0.001, "returning to menu removes night immediately")
	cycle.free()
	map.free()
	sun.free()

func test_diplomacy_flag_dimensions_match_across_countries() -> void:
	for tag: String in ["GER", "SOV", "TUR", "JAP", "ENG"]:
		var flag := FlagFactory.uniform(country(tag), 540)
		eq(flag.get_size(), Vector2(540, 360), "identical flag rectangle for " + tag)
		eq(flag, FlagFactory.uniform(country(tag), 540), "resized flag is cached")

func test_recon_preview_contains_only_reachable_targets_and_is_read_only() -> void:
	var c := player()
	c.sp = 1000
	c.stockpile[Air.TYPES["fighter"]["eq"]] = 1000.0
	var wing := Air.deploy(c, "fighter", Air._home_base(c.tag))
	if not check(wing != null, "recon fixture has a real wing"): return
	var before := [c.sp, wing.base, wing.mission, wing.planes]
	var targets := Air.recon_targets(c.tag)
	gt(targets.size(), 0, "eligible nearby provinces light up")
	lt(targets.size(), World.provinces.size(), "unreachable world is not highlighted")
	for pid: int in targets:
		var reachable := false
		for candidate: AirWing in Air.wings_of(c.tag):
			if candidate.planes <= 0 or (candidate.on_mission() and candidate.mission != AirWing.Mission.RECON): continue
			if Air.in_range(candidate, pid) or Air.base_for(candidate, pid) > 0:
				reachable = true
				break
		if not check(reachable, "highlighted target can receive a real recon order"): break
	eq([c.sp, wing.base, wing.mission, wing.planes], before, "preview neither spends points nor dispatches aircraft")
	c.sp = 0
	check(Air.recon_targets(c.tag).is_empty(), "no affordable orders means no green targets")

func test_recon_mask_can_clear_without_touching_other_overlay_textures() -> void:
	var map := MapView3D.new()
	map._material = ShaderMaterial.new()
	map._material.shader = preload("res://assets/shaders/map3d.gdshader")
	var pid := World.capital_province(player_tag())
	map.set_recon_targets({pid: 255})
	check(map._material.get_shader_parameter("recon_enabled"), "recon pass is enabled")
	eq(map._recon_texture.get_image().get_data()[pid], 255, "correct province receives the mask")
	check(map._mark_texture == null, "construction/order overlay is independent")
	map.set_recon_targets({})
	check(not map._material.get_shader_parameter("recon_enabled"), "leaving target mode clears green pass")
	map.free()

func test_generated_front_stencil_has_alpha_and_mipmaps() -> void:
	var texture := load("res://assets/ui/map/front_comb_v2.png") as Texture2D
	gt(texture.get_width(), 1000, "high resolution generated source")
	check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "transparent stencil, not a rectangular decal")
	check(texture.get_image().has_mipmaps(), "distant front uses prefiltered mipmaps")
