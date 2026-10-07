extends SceneTree

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1100, 700))
	root.content_scale_size = Vector2i(1100, 700)
	var ui: Script = load("res://game/ui/ui_theme.gd")
	var canvas := Control.new()
	canvas.theme = ui.get_theme()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("473b30")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var path: Array[Vector2] = []
	for i in 60:
		var t := float(i) / 59.0
		path.append(Vector2(970 - 860 * t, 265 - sin(t * PI * 0.65) * 140))
	var shape: PackedVector2Array = load("res://game/map/order_arrow_shape.gd").contour(path, 58)
	for outline in Geometry2D.offset_polygon(shape, 3.2, Geometry2D.JOIN_ROUND):
		var border := Polygon2D.new()
		border.polygon = outline
		border.color = Color("21100b")
		border.vertex_colors = _arrow_alpha(outline, border.color)
		canvas.add_child(border)
	var fill := Polygon2D.new()
	fill.polygon = shape
	fill.color = Color("73180d")
	fill.vertex_colors = _arrow_alpha(shape, fill.color)
	canvas.add_child(fill)
	var tip: Control = load("res://game/ui/hover_tooltip.gd").new()
	canvas.add_child(tip)
	tip.set_process(false)
	tip._set_content("Harekât emri\nSeçili tümenler hedef bölgeye ilerler.\nDüşman bölgesine verilen emir taarruz başlatır.\nKısayol: Sağ tık")
	tip.position = Vector2(80, 350)
	tip.show()
	var compact: Control = load("res://game/ui/hover_tooltip.gd").new()
	canvas.add_child(compact)
	compact.set_process(false)
	compact._set_content("İkmal\nBirliklerin malzeme ve erzak durumu.")
	compact.position = Vector2(590, 350)
	compact.show()
	var icon_names := ["port", "airbase", "city", "capital"]
	var labels := ["Liman", "Hava üssü", "Şehir", "Başkent"]
	for i in icon_names.size():
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/map/" + icon_names[i] + ".svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(110 + 235 * i, 585)
		icon.size = Vector2(32, 32)
		canvas.add_child(icon)
		var label: Label = ui.make_label(labels[i], 18)
		label.position = icon.position + Vector2(42, 5)
		canvas.add_child(label)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/previews/arrow_tooltip")
	root.get_texture().get_image().save_png("res://art/previews/arrow_tooltip/preview.png")
	canvas.queue_free()
	await process_frame
	quit()

func _arrow_alpha(polygon: PackedVector2Array, ink: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	for p in polygon:
		var progress := clampf((970.0 - p.x) / 860.0, 0.0, 1.0)
		colors.append(Color(ink, 0.60 * lerpf(0.22, 1.0, smoothstep(0.0, 0.22, progress))))
	return colors
