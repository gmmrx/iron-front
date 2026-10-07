extends StyleBox
## Nine-slice the actual generated artwork; source corners never stretch with a panel.
@export var surface: Texture2D
@export var region := Rect2()
@export var source_inset := Vector4(24, 24, 24, 24)
@export var display_inset := Vector4(6, 6, 6, 6)
@export var tint := Color.WHITE

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _draw(canvas: RID, rect: Rect2) -> void:
	if surface == null or not rect.has_area(): return
	var src := region if region.has_area() else Rect2(Vector2.ZERO, surface.get_size())
	var dx := [rect.position.x, rect.position.x + display_inset.x, rect.end.x - display_inset.z, rect.end.x]
	var dy := [rect.position.y, rect.position.y + display_inset.y, rect.end.y - display_inset.w, rect.end.y]
	var sx := [src.position.x, src.position.x + source_inset.x, src.end.x - source_inset.z, src.end.x]
	var sy := [src.position.y, src.position.y + source_inset.y, src.end.y - source_inset.w, src.end.y]
	for y in 3:
		for x in 3:
			var dest := Rect2(Vector2(dx[x], dy[y]), Vector2(dx[x + 1] - dx[x], dy[y + 1] - dy[y]))
			if dest.has_area():
				surface.draw_rect_region(canvas, dest,
					Rect2(Vector2(sx[x], sy[y]), Vector2(sx[x + 1] - sx[x], sy[y + 1] - sy[y])), tint)
