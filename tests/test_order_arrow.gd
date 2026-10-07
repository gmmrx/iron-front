extends "res://tests/test_case.gd"

func test_arrow_contours() -> void:
	var shape_script := preload("res://game/map/order_arrow_shape.gd")
	var paths: Array = [
		[Vector2.ZERO, Vector2(100, 0)],
		[Vector2.ZERO, Vector2.ZERO, Vector2(2, 1)],
		[Vector2.ZERO, Vector2(40, -12), Vector2(80, -17), Vector2(120, -12)],
		[Vector2.ZERO, Vector2(40, 0), Vector2(40, 40)]]
	for path in paths:
		var typed: Array[Vector2] = []
		typed.assign(path)
		var contour := shape_script.contour(typed, 12)
		gt(Geometry2D.triangulate_polygon(contour).size(), 0, "arrow is a triangulatable solid polygon")
		check(contour.has(typed.back()), "tip reaches destination")
		check(not Geometry2D.offset_polygon(contour, 0.6).is_empty(), "outline exists")
	var empty: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	eq(shape_script.contour(empty, 12).size(), 0, "zero-length route safely ignored")

func test_tooltip_surface() -> void:
	var style := preload("res://game/ui/tooltip_surface.gd").new()
	check(style.texture != null, "uses generated black/gold panel")
	eq(style.get_content_margin(SIDE_LEFT), 22.0, "text clears the 14px frame")

func test_tooltip_shrinks_after_wrap_layout() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var tooltip := HoverTooltip.new()
	tree.root.add_child(tooltip)
	tooltip.set_process(false)
	tooltip._set_content("İkmal\nMalzeme ve erzak durumu.")
	tooltip.show()
	for frame in 5:
		await tree.process_frame
	lt(tooltip.size.y, 220.0, "short tooltip has no oversized empty body")
	tooltip.free()
