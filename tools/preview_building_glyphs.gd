extends SceneTree
## Isolated art export: does not load or change map badge sizes, placement, or bindings.
const DIR := "res://assets/ui/building_glyphs_gold_v2/"
const IDS := ["civilian_factory", "military_factory", "anti_air", "naval_base"]
const NAMES := ["Sivil fabrika", "Askerî fabrika", "Uçaksavar", "Deniz üssü"]

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(940, 400))
	root.content_scale_size = Vector2i(940, 400)
	var bg := ColorRect.new()
	bg.color = Color("111c1c")
	bg.size = Vector2(940, 400)
	root.add_child(bg)
	var heading := Label.new()
	heading.text = "YAPI İKONLARI  /  AÇIK ALTIN SİLÜET"
	heading.position = Vector2(30, 20)
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color("f1dfa5"))
	bg.add_child(heading)
	for i in IDS.size():
		var image := Image.new()
		var svg := FileAccess.get_file_as_string(DIR + IDS[i] + ".svg")
		assert(image.load_svg_from_string(svg, 4.0) == OK)
		assert(image.get_size() == Vector2i(1024, 1024))
		assert(image.detect_alpha() != Image.ALPHA_NONE)
		assert(image.save_png(DIR + IDS[i] + ".png") == OK)
		var texture := ImageTexture.create_from_image(image)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(32 + i * 230, 78)
		icon.size = Vector2(186, 186)
		bg.add_child(icon)
		var label := Label.new()
		label.text = NAMES[i]
		label.position = Vector2(12 + i * 230, 275)
		label.size = Vector2(220, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color("f1dfa5"))
		bg.add_child(label)
		var small := TextureRect.new()
		small.texture = texture
		small.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		small.position = Vector2(101 + i * 230, 327)
		small.size = Vector2(48, 48)
		bg.add_child(small)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/previews/building_glyphs_gold_v2")
	root.get_texture().get_image().save_png("res://art/previews/building_glyphs_gold_v2/preview.png")
	print("PASS: 4 SVG + 4 transparent 1024px PNG exports. No map settings changed.")
	quit()
