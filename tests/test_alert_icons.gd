extends "res://tests/test_case.gd"

func test_notification_art_and_interaction() -> void:
	var alerts := AlertBar.new()
	var clicked: Array[String] = []
	for id: String in AlertBar.ICON_IDS:
		var texture := AlertBar.notification_icon(id)
		check(texture != null, id + ": asset exists")
		check(texture == AlertBar.notification_icon(id), id + ": texture cached")
		check(texture.resource_path.ends_with("/alerts_gold/" + id + ".png"), id + ": dedicated art")
		var image := texture.get_image()
		check(image.has_mipmaps(), id + ": mipmaps for small UI")
		check(image.get_pixel(0, 0).a < 0.01, id + ": transparent background")
		var entry := [id, "diplomacy", "urgent", "Başlık", "Açıklama", func() -> void: clicked.append(id)]
		var tile := alerts._tile(entry)
		eq(tile.custom_minimum_size, Vector2(62, 62), id + ": dimensions unchanged")
		eq(tile.get_theme_constant("icon_max_width"), 54, id + ": icon allocation unchanged")
		eq(tile.tooltip_text, "Başlık\nAçıklama", id + ": tooltip preserved")
		check(tile.has_meta("urgent"), id + ": urgency preserved")
		check(not tile.has_meta("bar"), id + ": bottom strip removed")
		var overlay := tile.get_meta("level_overlay") as Panel
		check(overlay != null, id + ": subtle level overlay")
		eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, id + ": overlay does not intercept clicks")
		var style := tile.get_theme_stylebox("normal") as StyleBoxTexture
		check(style != null and style.texture == TopBar.sheet("btn_square"), id + ": new UI frame")
		tile.pressed.emit()
		eq(clicked.back(), id, id + ": correct action")
		tile.free()
	alerts.free()

func test_attention_priority_and_quiet_intervals() -> void:
	var profiles := [
		["event", "urgent", 2.8, 0.5],
		["research", "warn", 7.0, 0.5],
		["wings", "info", 12.0, 0.5],
		["recruit", "info", 20.0, 0.5],
	]
	for spec: Array in profiles:
		var profile := AlertBar.attention_profile(spec[0], spec[1])
		near(profile.x, spec[2], 0.001, spec[0] + ": period")
		near(profile.y, spec[3], 0.001, spec[0] + ": active duration")
		near(AlertBar.attention_opacity(0, profile), 1, 0.001, "starts visible")
		near(AlertBar.attention_opacity(0.125, profile), 0.725, 0.001, "dims gently")
		near(AlertBar.attention_opacity(0.25, profile), 0.45, 0.001, "remains visible at minimum")
		near(AlertBar.attention_opacity(0.375, profile), 0.725, 0.001, "fades back in")
		near(AlertBar.attention_opacity(profile.y, profile), 1, 0.001, "fully restored")
		near(AlertBar.attention_opacity((profile.x + profile.y) * 0.5, profile), 1, 0.001, "stays visible between blinks")
		near(AlertBar.attention_opacity(profile.x + 0.25, profile), 0.45, 0.001, "repeats on schedule")
	eq(AlertBar.attention_profile("recruit", "urgent"), AlertBar.ATTENTION["urgent"], "urgency overrides recruit exception")

func test_opacity_blinks_without_layout_or_colour_changes() -> void:
	var alerts := AlertBar.new()
	var entry := ["recruit", "army", "info", "Title", "Body", func() -> void: pass]
	var tile := alerts._tile(entry)
	alerts.add_child(tile)
	alerts._animate_urgency(10.0)
	eq(tile.modulate, Color.WHITE, "recruit stays visible for most of its cycle")
	alerts._animate_urgency(10.25)
	near(tile.modulate.a, 0.45, 0.001, "whole tile dims on schedule")
	check(tile.visible, "opacity only; layout space and hit area retained")
	eq(tile.custom_minimum_size, Vector2(62, 62), "dimensions retained")
	var replacement := alerts._tile(entry)
	near(replacement.modulate.a, tile.modulate.a, 0.001, "count/text rebuild preserves opacity phase")
	replacement.free()
	for frame in 600:
		alerts._animate_urgency(1.0 / 30.0)
		eq(tile.self_modulate, Color.WHITE, "no extra brightness effect")
		check(tile.modulate.a >= 0.4499 and tile.modulate.a <= 1, "never disappears")
		near(tile.modulate.r, 1.0, 0.001, "no animated colour shift")
	alerts.free()

func test_no_glow_and_static_colour_overlay() -> void:
	var alerts := AlertBar.new()
	var tile := alerts._tile(["event", "diplomacy", "urgent", "Title", "Body", func() -> void: pass])
	alerts.add_child(tile)
	var overlay := tile.get_meta("level_overlay") as Panel
	var wash := overlay.get_theme_stylebox("panel") as StyleBoxFlat
	check(not tile.has_meta("attention_glow"), "glow removed")
	lt(wash.bg_color.a, 0.1, "subtle static tint only")
	alerts._animate_urgency(0.25)
	eq(overlay.modulate, Color.WHITE, "overlay fades through parent, not a separate effect")
	near(tile.modulate.a, 0.45, 0.001, "icon, box and overlay dim together")
	alerts.free()
