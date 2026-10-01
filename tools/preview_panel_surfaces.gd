extends SceneTree
## Draws actual theme surfaces side by side at identical sizes, before/after.
func _init() -> void:
	await process_frame
	var ui: Script = load("res://game/ui/ui_theme.gd")
	DisplayServer.window_set_size(Vector2i(1440, 920))
	root.content_scale_size = Vector2i(1440, 920)
	var bg := ColorRect.new()
	bg.size = Vector2(1440, 920)
	bg.color = Color("101614")
	root.add_child(bg)
	for i in 2:
		var x := 24 + i * 708
		var label := Label.new()
		label.text = "ÖNCE — GERİLEN DOKU" if i == 0 else "SONRA — SABİT ÖLÇEKLİ DOKU"
		label.position = Vector2(x, 20)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color("e0b85e"))
		bg.add_child(label)
		for sample in [["panel", Vector2(x, 65), Vector2(680, 580), 16], ["panel_flat", Vector2(x, 662), Vector2(430, 226), 14], ["header", Vector2(x + 442, 662), Vector2(238, 60), 8], ["strip", Vector2(x + 442, 738), Vector2(238, 150), 12]]:
			var p := Panel.new()
			var style: StyleBoxTexture = ui.legacy_skin(sample[0], sample[3], 14)
			if i == 0:
				style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
				style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			p.add_theme_stylebox_override("panel", style)
			p.position = sample[1]
			p.size = sample[2]
			bg.add_child(p)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/previews/panel_surfaces")
	root.get_texture().get_image().save_png("res://art/previews/panel_surfaces/before_after.png")
	print("Panel surface comparison saved")
	quit()
