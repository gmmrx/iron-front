extends SceneTree
## Actual UnitLayer textures, enlarged for art inspection; no duplicate card renderer.
const TYPES := ["infantry", "medium_armor", "plane", "ship", "motorized", "light_armor", "artillery", "anti_tank", "submarine"]
const NAMES := ["Piyade", "Orta tank", "Avcı uçağı", "Gemi", "Motorlu birlik", "Hafif tank", "Topçu", "Tanksavar", "Denizaltı — mevcut ikon"]

func _init() -> void:
	await process_frame
	var unit_layer: Script = load("res://game/map/unit_layer.gd")
	var ui_theme: Script = load("res://game/ui/ui_theme.gd")
	root.get_node("Game").new_game()
	root.get_node("World").start_game("TUR")
	DisplayServer.window_set_size(Vector2i(1380, 920))
	root.content_scale_size = Vector2i(1380, 920)
	var bg := ColorRect.new()
	bg.color = Color("18201e")
	bg.size = Vector2(1380, 920)
	root.add_child(bg)
	var title := Label.new()
	title.text = "IRON FRONT  /  BİRLİK KARTLARI"
	title.position = Vector2(36, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("d0bb8c"))
	bg.add_child(title)
	for i in TYPES.size():
		var p := Vector2(24 + (i % 3) * 452, 82 + (i / 3) * 270)
		var tex := TextureRect.new()
		tex.texture = unit_layer.plate_tex("TUR", false, TYPES[i])
		tex.position = p
		tex.size = Vector2(432, 200)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.add_child(tex)
		var num := Label.new()
		num.text = "75" if TYPES[i] == "plane" else "12"
		num.add_theme_font_override("font", ui_theme.bold_font())
		num.add_theme_font_size_override("font_size", 65)
		num.add_theme_color_override("font_color", Color("f3ead0"))
		num.position = p + Vector2(320, 88)
		num.size = Vector2(74, 90)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bg.add_child(num)
		var name_label := Label.new()
		name_label.text = NAMES[i]
		name_label.position = p + Vector2(0, 206)
		name_label.size = Vector2(432, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color("c8ad72"))
		bg.add_child(name_label)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://art/previews/unit_cards")
	img.save_png("res://art/previews/unit_cards/cards_in_engine.png")
	print("Unit cards preview saved")
	quit()
