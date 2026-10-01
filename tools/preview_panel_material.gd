extends SceneTree

func _init() -> void:
	await process_frame
	var ui: Script = load("res://game/ui/ui_theme.gd")
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.content_scale_size = Vector2i(1600, 1000)
	var bg := ColorRect.new()
	bg.size = Vector2(1600, 1000)
	bg.color = Color("101614")
	root.add_child(bg)
	for i in 2:
		var x := 24 + i * 788
		var label := Label.new()
		label.text = "ÖNCE / DÖŞENEN ESKİ DOKU" if i == 0 else "YENİ / İNCE METAL YÜZEY"
		label.position = Vector2(x, 18)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("e0b85e"))
		bg.add_child(label)
		var panel := PanelContainer.new()
		panel.theme = ui.get_theme()
		panel.add_theme_stylebox_override("panel", ui.legacy_skin("panel", 16, 14) if i == 0 else ui.material_panel())
		panel.position = Vector2(x, 64)
		panel.size = Vector2(760, 900)
		bg.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 20)
		panel.add_child(body)
		var heading := Label.new()
		heading.text = "ÜRETİM VE LOJİSTİK"
		heading.add_theme_font_override("font", ui.title_font())
		heading.add_theme_font_size_override("font_size", 28)
		heading.add_theme_color_override("font_color", ui.ACCENT)
		body.add_child(heading)
		var sub := Label.new()
		sub.text = "Aynı renkler · Aynı çerçeve · Aynı ölçüler"
		body.add_child(sub)
		var air := Control.new()
		air.custom_minimum_size.y = 260
		body.add_child(air)
		var nested := PanelContainer.new()
		nested.add_theme_stylebox_override("panel", ui.legacy_skin("panel_flat", 14, 12) if i == 0 else ui.material_panel(true))
		body.add_child(nested)
		var text := Label.new()
		text.text = "SANAYİ KAPASİTESİ\n\nAskerî fabrikalar                         24\nÜretim verimliliği                       %78\nGünlük teçhizat                          125"
		text.add_theme_font_size_override("font_size", 24)
		nested.add_child(text)
		var button := Button.new()
		button.text = "Eski buton yüzeyi" if i == 0 else "Yeni buton yüzeyi"
		if i == 0:
			button.add_theme_stylebox_override("normal", ui.legacy_skin("button", 8, 9))
		body.add_child(button)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/previews/panel_material")
	root.get_texture().get_image().save_png("res://art/previews/panel_material/comparison.png")
	# A real full-screen panel, with its existing widgets and layout.
	bg.queue_free()
	await process_frame
	root.get_node("Game").new_game()
	root.get_node("World").start_game("TUR")
	var panel_script: Script = load("res://game/ui/production_panel.gd")
	var actual: PanelContainer = panel_script.new()
	actual.theme = ui.get_theme()
	root.add_child(actual)
	actual.position = Vector2(84, 96)
	actual.open()
	for f in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/panel_material/production.png")
	print("Material comparison and actual production panel saved")
	quit()
