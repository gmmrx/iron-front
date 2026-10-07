class_name ForceSelectionCard
extends PanelContainer
## A selection surface, never an order button. Operational controls belong in
## content below the header and cannot bubble into the selection callback.

signal selection_requested

class SelectionBox extends Button:
	var partial := false
	func _draw() -> void:
		var rect := Rect2((size - Vector2(20, 20)) * 0.5, Vector2(20, 20))
		var ink := Color("e9cb84") if button_pressed or partial else Color("8e999b")
		draw_rect(rect, Color("111a1e"), true)
		draw_rect(rect, ink, false, 1.5)
		if partial:
			draw_line(rect.position + Vector2(4, 10), rect.position + Vector2(16, 10), ink, 3.0, true)
		elif button_pressed:
			draw_polyline(PackedVector2Array([rect.position + Vector2(4, 10), rect.position + Vector2(8, 14), rect.position + Vector2(16, 5)]), ink, 2.5, true)

var content: VBoxContainer
var header: HBoxContainer
var toggle_button: SelectionBox
var select_button: Button
var title_label: Label
var subtitle_label: Label
var _icon: TextureRect
var _compact := false

func _init() -> void:
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	toggle_button = checkbox(false, func() -> void: selection_requested.emit()) as SelectionBox
	toggle_button.name = "SelectionCheckbox"
	header.add_child(toggle_button)
	select_button = Button.new()
	# The selection owner emits the unit/fleet/wing cue, not a second UI click.
	select_button.set_meta("audio_silent", true)
	select_button.name = "SelectionHeader"
	select_button.focus_mode = Control.FOCUS_ALL
	select_button.custom_minimum_size.y = 158
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["normal", "hover", "pressed"]:
		select_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	select_button.add_theme_stylebox_override("focus", CommandPanelSkin.box("hover", 0))
	select_button.pressed.connect(func() -> void: selection_requested.emit())
	header.add_child(select_button)
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select_button.add_child(row)
	_icon = UiTheme.icon_texture(null, 74)
	_icon.name = "ForceThumbnail"
	_icon.custom_minimum_size = Vector2(0, 74)
	_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_icon)
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 2)
	row.add_child(labels)
	title_label = UiTheme.make_label("", 17, UiTheme.TEXT)
	title_label.add_theme_font_override("font", UiTheme.bold_font())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(title_label)
	subtitle_label = UiTheme.make_label("", 13, UiTheme.TEXT_DIM)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.max_lines_visible = 1
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(subtitle_label)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func configure(title: String, subtitle: String, texture: Texture2D, selected: bool, partial := false) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	_icon.texture = UiTheme.trimmed(texture) if texture else null
	select_button.tooltip_text = title + ("\n" + subtitle if subtitle != "" else "")
	set_selected(selected, partial)

func set_selected(selected: bool, partial := false) -> void:
	apply(self, selected, partial, 8 if _compact else 10)
	toggle_button.set_pressed_no_signal(selected)
	toggle_button.partial = partial
	toggle_button.queue_redraw()
	toggle_button.tooltip_text = tr("FORCE_PARTIAL") if partial else tr("FORCE_DESELECT" if selected else "FORCE_SELECT")
	title_label.add_theme_color_override("font_color", UiTheme.ACCENT if selected or partial else UiTheme.TEXT)

## Two-column roster mode. Selection semantics/audio remain with the owner;
## operational controls live in a separate, full-width selected-unit dossier.
func set_compact(on := true) -> void:
	_compact = on
	set_meta("force_compact", on)
	custom_minimum_size.y = 116.0 if on else 0.0
	content.add_theme_constant_override("separation", 4 if on else 10)
	header.add_theme_constant_override("separation", 5 if on else 8)
	select_button.custom_minimum_size.y = 126.0 if on else 158.0
	toggle_button.custom_minimum_size = Vector2(28, 28) if on else Vector2(34, 34)
	_icon.custom_minimum_size = Vector2(0, 60 if on else 74)
	(select_button.get_child(0) as VBoxContainer).add_theme_constant_override("separation", 4)
	title_label.custom_minimum_size.x = 1
	subtitle_label.custom_minimum_size.x = 1
	title_label.add_theme_font_size_override("font_size", UiTheme.fs(16 if on else 17))
	subtitle_label.add_theme_font_size_override("font_size", UiTheme.fs(12 if on else 13))
	set_selected(bool(get_meta("force_selected", false)), bool(get_meta("force_partial", false)))

static func apply(panel: PanelContainer, selected: bool, partial := false, inset := 10) -> void:
	panel.add_theme_stylebox_override("panel", CommandPanelSkin.box("selected" if selected or partial else "card", inset))
	panel.set_meta("force_selected", selected)
	panel.set_meta("force_partial", partial)

static func checkbox(selected: bool, pressed: Callable, tip := "", partial := false) -> Button:
	var button := SelectionBox.new()
	button.set_meta("audio_silent", true)
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	button.partial = partial
	button.custom_minimum_size = Vector2(34, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tip if tip != "" else TranslationServer.translate("FORCE_DESELECT" if selected else "FORCE_SELECT")
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state: String in ["normal", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", CommandPanelSkin.box("hover", 0))
	button.add_theme_stylebox_override("focus", CommandPanelSkin.box("selected", 0))
	button.pressed.connect(pressed)
	return button
