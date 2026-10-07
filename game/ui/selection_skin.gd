class_name SelectionSkin
extends RefCounted
## Reference-derived surfaces, scoped to country selection and tooltips.
const DIRECTORY := "res://assets/ui/selection_reference/"

static func panel(content: int = 18, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(DIRECTORY + "panel.png")
	# Keep the corner fittings and thin brass edges intact at every panel size.
	style.set_texture_margin_all(32)
	style.set_content_margin_all(content)
	style.modulate_color = tint
	return style

static func button(control: Button, content: int = 10) -> void:
	for entry: Array in [["normal", Color(0.8, 0.8, 0.76)],
			["hover", Color(1.18, 1.12, 0.94)], ["pressed", Color(1.3, 1.16, 0.84)],
			["hover_pressed", Color(1.4, 1.24, 0.9)], ["disabled", Color(0.5, 0.5, 0.48)]]:
		control.add_theme_stylebox_override(entry[0], panel(content, entry[1]))
	control.add_theme_color_override("font_color", Color("e5d5b3"))
	control.add_theme_color_override("font_hover_color", Color("fff0ce"))
	control.add_theme_color_override("font_pressed_color", Color("ffe1a0"))
	control.add_theme_color_override("font_disabled_color", Color("877f6e"))

static func divider() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("62543a")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
