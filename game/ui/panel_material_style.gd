extends StyleBox
## Material surface and original frame are independent: grain never stretches, corners never scale.
const TEXEL_SCALE := 0.75
const SURFACE_TINT := Color(0.70, 0.73, 0.80, 1.0)
@export var frame: StyleBoxTexture
@export var surface: Texture2D
@export var lighting: GradientTexture2D
@export var surface_tint := SURFACE_TINT
@export var draw_center := true

func configure(original: StyleBoxTexture, material_texture: Texture2D, kind := "panel") -> void:
	frame = original.duplicate()
	frame.draw_center = false
	surface = material_texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_content_margin(side, original.get_content_margin(side))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.018))
	ramp.set_color(1, Color(0, 0, 0, 0.10))
	if kind not in ["panel", "panel_flat", "strip"]:
		# Reuse the authored state's colour/light range, not a new UI palette.
		var source := original.texture.get_image()
		if source.is_compressed():
			source.decompress()
		var upper := _row_colour(source, int(original.get_texture_margin(SIDE_TOP)) + 1)
		var lower := _row_colour(source, source.get_height() - int(original.get_texture_margin(SIDE_BOTTOM)) - 2)
		var mean := upper.lerp(lower, 0.5)
		surface_tint = Color(mean.r / 0.189, mean.g / 0.196, mean.b / 0.188, 1)
		var top_light := maxf(upper.get_luminance() - mean.get_luminance(), 0.0)
		var bottom_dark := maxf(mean.get_luminance() - lower.get_luminance(), 0.0)
		if upper.get_luminance() >= lower.get_luminance():
			ramp.set_color(0, Color(1, 1, 1, top_light / maxf(1.0 - mean.get_luminance(), 0.01)))
			ramp.set_color(1, Color(0, 0, 0, bottom_dark / maxf(mean.get_luminance(), 0.01)))
		else:
			ramp.set_color(0, Color(0, 0, 0, (mean.get_luminance() - upper.get_luminance()) / maxf(mean.get_luminance(), 0.01)))
			ramp.set_color(1, Color(1, 1, 1, (lower.get_luminance() - mean.get_luminance()) / maxf(1.0 - mean.get_luminance(), 0.01)))
		# Keep only actual border pixels; the old 6–8px inner texture must not stretch.
		frame.set_texture_margin_all(3 if kind.begins_with("slot") or kind in ["header", "section", "tooltip"] else 2)
	lighting = GradientTexture2D.new()
	lighting.gradient = ramp
	lighting.width = 4
	lighting.height = 256
	lighting.fill_from = Vector2(0, 0)
	lighting.fill_to = Vector2(0, 1)

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO # StyleBox derives layout minimum from current content margins, including duplicates.

func _row_colour(image: Image, y: int) -> Color:
	var colour := Color(0, 0, 0, 0)
	var begin := image.get_width() / 4
	var end := image.get_width() * 3 / 4
	for x in range(begin, end):
		colour += image.get_pixel(x, clampi(y, 0, image.get_height() - 1))
	return colour / float(end - begin)

func _draw(canvas_item: RID, rect: Rect2) -> void:
	if frame == null or surface == null:
		return
	var left := frame.get_texture_margin(SIDE_LEFT)
	var top := frame.get_texture_margin(SIDE_TOP)
	var inner := Rect2(rect.position + Vector2(left, top), rect.size - Vector2(
		left + frame.get_texture_margin(SIDE_RIGHT), top + frame.get_texture_margin(SIDE_BOTTOM)))
	if draw_center and inner.has_area():
		var tile := surface.get_size() * TEXEL_SCALE
		for y in ceili(inner.size.y / tile.y):
			for x in ceili(inner.size.x / tile.x):
				var offset := Vector2(x, y) * tile
				var extent := (inner.size - offset).min(tile)
				surface.draw_rect_region(canvas_item, Rect2(inner.position + offset, extent),
					Rect2(Vector2.ZERO, extent / TEXEL_SCALE), surface_tint)
		lighting.draw_rect(canvas_item, inner, false)
	frame.draw(canvas_item, rect)
