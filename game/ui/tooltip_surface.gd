extends StyleBox
## Keep the source art's full corner brackets inside a compact 14px UI border.
var texture: Texture2D = preload("res://assets/ui/selection_reference/panel.png")

func _init() -> void:
	set_content_margin_all(22)

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _draw(canvas_item: RID, rect: Rect2) -> void:
	var source := texture.get_size()
	var cut := 80.0
	var edge := minf(14.0, minf(rect.size.x, rect.size.y) * 0.5)
	var sx := [0.0, cut, source.x - cut, source.x]
	var sy := [0.0, cut, source.y - cut, source.y]
	var dx := [rect.position.x, rect.position.x + edge, rect.end.x - edge, rect.end.x]
	var dy := [rect.position.y, rect.position.y + edge, rect.end.y - edge, rect.end.y]
	for y in 3:
		for x in 3:
			if x == 1 and y == 1:
				# Preserve the grain's aspect instead of pulling a square texture into a thin card.
				var inner := Rect2(dx[1], dy[1], dx[2] - dx[1], dy[2] - dy[1])
				var tile := (source - Vector2.ONE * cut * 2.0) * 0.5
				for ty in ceili(inner.size.y / tile.y):
					for tx in ceili(inner.size.x / tile.x):
						var offset := Vector2(tx, ty) * tile
						var extent := (inner.size - offset).min(tile)
						texture.draw_rect_region(canvas_item, Rect2(inner.position + offset, extent), Rect2(Vector2.ONE * cut, extent * 2.0))
				continue
			texture.draw_rect_region(canvas_item,
				Rect2(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y]),
				Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y]))
