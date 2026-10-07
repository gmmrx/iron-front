class_name CommandPanelSkin
extends RefCounted
## The user's October panel references, scoped to framed game panels (never HUD/nav).
const ASSETS := "res://assets/ui/command_panels/"
const Surface = preload("res://game/ui/command_panel_surface.gd")
static var _theme: Theme
static var _textures := {}

## Keep the generated nine-slice metalwork; only tabs add a legible state wash
## and a physical underline. Focus is an independent transparent outline.
class TabSurface extends "res://game/ui/command_panel_surface.gd":
	@export var fill := Color.TRANSPARENT
	@export var edge := Color.TRANSPARENT
	@export var edge_width := 0.0
	@export var underline := Color.TRANSPARENT
	@export var underline_height := 0.0
	func _draw(canvas: RID, rect: Rect2) -> void:
		super._draw(canvas, rect)
		if not rect.has_area(): return
		var inner := rect.grow(-3.0)
		if fill.a > 0.0 and inner.has_area(): RenderingServer.canvas_item_add_rect(canvas, inner, fill)
		if edge.a > 0.0 and edge_width > 0.0:
			var outline := rect.grow(-maxf(1.0, edge_width * 0.5))
			var points := [outline.position, Vector2(outline.end.x, outline.position.y), outline.end, Vector2(outline.position.x, outline.end.y)]
			for i in 4:
				RenderingServer.canvas_item_add_line(canvas, points[i], points[(i + 1) % 4], edge, edge_width, true)
		if underline.a > 0.0 and underline_height > 0.0 and rect.size.x > 12.0:
			RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position.x + 6.0, rect.end.y - underline_height - 3.0, rect.size.x - 12.0, underline_height), underline)

static func tab_box(state: String) -> StyleBox:
	var tab := TabSurface.new()
	tab.set_content_margin_all(12)
	tab.content_margin_bottom = 15
	if state == "focus":
		tab.edge = Color("fff0bc")
		tab.edge_width = 2.0
		return tab
	var selected := state in ["pressed", "hover_pressed"]
	var artwork := box("selected" if selected else "button", 12)
	tab.surface = artwork.surface
	tab.source_inset = artwork.source_inset
	tab.display_inset = artwork.display_inset
	tab.tint = Color(0.65, 0.68, 0.70)
	tab.fill = Color(0.055, 0.078, 0.082, 0.35)
	tab.edge = Color("716044")
	tab.edge_width = 1.0
	match state:
		"hover":
			tab.tint = Color(0.92, 0.90, 0.84)
			tab.fill = Color(0.25, 0.19, 0.11, 0.28)
			tab.edge = Color("c0a06a")
			tab.edge_width = 1.5
		"pressed", "hover_pressed":
			tab.tint = Color.WHITE
			tab.fill = Color(0.435, 0.322, 0.188, 0.86) if state == "pressed" else Color(0.514, 0.376, 0.224, 0.90)
			tab.edge = Color("dfb872") if state == "pressed" else Color("f1d49a")
			tab.edge_width = 2.0
			tab.underline = Color("f4d48d")
			tab.underline_height = 4.0
		"disabled":
			tab.tint = Color(0.48, 0.53, 0.55)
			tab.fill = Color(0.055, 0.078, 0.082, 0.50)
			tab.edge = Color("455051")
	return tab

## Reuse the readable HUD pictograms; only dossiers get the new generated emblems.
static func icon(name: String) -> Texture2D:
	if name in ["research", "diplomacy"]:
		if not _textures.has(name): _textures[name] = load(ASSETS + name + "_v3.png")
		return _textures[name]
	var sheet_icons := {"politics": "icon_political_power", "political_power": "icon_political_power",
		"focus": "icon_political_power", "stability": "icon_stability", "war_support": "icon_war_support",
		"army": "icon_army", "navy": "icon_navy", "air": "icon_air", "manpower": "icon_manpower",
		"building_civilian_factory": "icon_factory", "states": "icon_factory"}
	return TopBar.sheet(sheet_icons[name]) if sheet_icons.has(name) else UiTheme.trimmed(UiTheme.icon(name))

static func illustration(name: String) -> Texture2D:
	# The dossier portrait plates are intentionally distinct from tiny HUD symbols.
	return UiTheme._painted_icon(name) if UiTheme.PAINTED_ATLAS.has(name) else UiTheme.icon(name)

static func box(kind := "card", inset := 10) -> StyleBox:
	var sb := Surface.new()
	sb.set_content_margin_all(inset)
	var asset := "inset_v3"
	sb.source_inset = Vector4(24, 24, 24, 24)
	sb.display_inset = Vector4(4, 4, 4, 4)
	match kind:
		"panel":
			asset = "window_v3"
			sb.source_inset = Vector4(40, 40, 40, 40)
			sb.display_inset = Vector4(16, 16, 16, 16)
		"header", "section":
			asset = "header_sheet_v3"
			# First generated strip only; the white atlas gutters are never drawn.
			sb.region = Rect2(2, 3, 2168, 154)
			sb.source_inset = Vector4(16, 12, 16, 12)
			sb.display_inset = Vector4(3, 2, 3, 3)
			sb.tint = Color(0.66, 0.68, 0.68)
		"selected":
			asset = "selected_v3"
			sb.source_inset = Vector4(36, 36, 36, 36)
			sb.display_inset = Vector4(5, 5, 5, 5)
		"hover":
			asset = "button_v3"
			sb.tint = Color(1.18, 1.14, 1.03)
		"disabled":
			asset = "button_v3"
			sb.tint = Color(0.62, 0.65, 0.67)
		"inset":
			sb.tint = Color(0.70, 0.74, 0.76)
		"button":
			asset = "button_v3"
		"good":
			sb.tint = Color(0.76, 0.91, 0.72)
		"bad":
			sb.tint = Color(0.98, 0.75, 0.67)
	if not _textures.has(asset): _textures[asset] = load(ASSETS + asset + ".png")
	sb.surface = _textures[asset]
	return sb

static func get_theme() -> Theme:
	if _theme != null: return _theme
	_theme = UiTheme.get_theme().duplicate()
	for type: String in ["PanelContainer", "Panel"]:
		_theme.set_stylebox("panel", type, box("card"))
	for spec: Array in [["Header", "header", 12], ["Section", "section", 8],
		["PanelFlat", "card", 12], ["Row", "card", 8], ["Cell", "card", 8],
		["Strip", "card", 10], ["Slot", "inset", 8], ["SlotGold", "selected", 8],
		["SlotGood", "good", 8], ["SlotBad", "bad", 8], ["CellRow", "inset", 6], ["CellAlt", "card", 6]]:
		_theme.set_stylebox("panel", spec[0], box(spec[1], spec[2]))
	for type: String in ["Button", "MenuButton", "OptionButton", "Card", "Tab", "MenuTile"]:
		for state: Array in [["normal", "button"], ["hover", "hover"], ["pressed", "selected"],
			["hover_pressed", "selected"], ["disabled", "disabled"]]:
			_theme.set_stylebox(state[0], type, box(state[1], 10))
		_theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		_theme.set_font("font", type, _theme.default_font)
		_theme.set_color("font_color", type, Color("eee6d3"))
		_theme.set_color("font_disabled_color", type, Color("899295"))
	# Tab is its own variation; never recolor ordinary buttons/cards/navigation.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_theme.set_stylebox(state, "Tab", tab_box(state))
	_theme.set_font("font", "Tab", UiTheme.bold_font())
	_theme.set_font_size("font_size", "Tab", UiTheme.fs(19))
	for spec: Array in [["font_color", "d9d0bb"], ["font_hover_color", "f9edcf"], ["font_pressed_color", "fff3ce"],
		["font_hover_pressed_color", "fff8dc"], ["font_focus_color", "fff0bc"], ["font_disabled_color", "899295"],
		["icon_normal_color", "b6a277"], ["icon_hover_color", "efd49b"], ["icon_pressed_color", "ffe3a1"],
		["icon_hover_pressed_color", "ffedbd"], ["icon_focus_color", "ffe3a1"], ["icon_disabled_color", "728080"]]:
		_theme.set_color(spec[0], "Tab", Color(spec[1]))
	_theme.set_stylebox("normal", "LineEdit", box("inset", 10))
	_theme.set_stylebox("read_only", "LineEdit", box("inset", 10))
	_theme.set_stylebox("focus", "LineEdit", box("selected", 10))
	return _theme

static func apply(panel: PanelContainer) -> void:
	panel.theme = get_theme()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.add_theme_stylebox_override("panel", box("panel", 16))
	panel.set_meta("command_skin", true)

## A complete inset section; callers add real content to the returned VBox.
static func section(parent: Container, title: String, icon := "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "PanelFlat"
	card.add_theme_stylebox_override("panel", box("card", 0))
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)
	var head := PanelContainer.new()
	head.theme_type_variation = "Section"
	stack.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	head.add_child(row)
	if icon != "":
		row.add_child(UiTheme.icon_texture(CommandPanelSkin.icon(icon), 27))
	var label := UiTheme.make_label(title.to_upper(), 17, Color("e7c47e"))
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	stack.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	return content
