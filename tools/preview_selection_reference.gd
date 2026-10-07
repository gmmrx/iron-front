extends SceneTree
## Isolated live UI preview; intentionally does not load or modify the map renderer.
func _init() -> void:
	await process_frame
	root.get_node("Game").new_game()
	TranslationServer.set_locale("tr")
	var ui: Script = load("res://game/ui/ui_theme.gd")
	var selection_script: Script = load("res://game/ui/country_select.gd")
	var tooltip_script: Script = load("res://game/ui/hover_tooltip.gd")
	var map_tip_script: Script = load("res://game/ui/map_tooltip.gd")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(1920, 1080)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.theme = ui.get_theme()
	root.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("202a28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(backdrop)
	var selection: Control = selection_script.new()
	canvas.add_child(selection)
	var tooltip: Control = tooltip_script.new()
	canvas.add_child(tooltip)
	tooltip.set_process(false)
	tooltip._set_content("İkmal durumu\nBirliklerin savaş gücü, malzeme ve ikmal erişimine bağlıdır.\nİkmal yollarını ve bağlantılı limanları kontrol edin.")
	tooltip.position = Vector2(64, 340)
	tooltip.show()
	var map_tip: Control = map_tip_script.new()
	canvas.add_child(map_tip)
	var capital: int = root.get_node("World").capital_province("TUR")
	map_tip.show_province(capital, Vector2(42, 570))
	DirAccess.make_dir_recursive_absolute("res://art/previews/selection_reference")
	for entry: Array in [["empty", ""], ["turkey", "TUR"], ["germany", "GER"]]:
		if entry[1] != "":
			selection.select(entry[1])
		for frame in 45:
			await process_frame
		selection.modulate.a = 1.0
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/previews/selection_reference/" + entry[0] + ".png")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	tooltip.hide()
	map_tip.hide()
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/selection_reference/compact.png")
	print("SELECTION_REFERENCE_PREVIEW saved")
	canvas.queue_free()
	await process_frame
	quit()
