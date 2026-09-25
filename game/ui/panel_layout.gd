class_name PanelLayout
extends RefCounted
## Layout helpers using the existing panel textures, typography and colours.

static func section(parent: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 28
	var label := UiTheme.make_label(text, 16, UiTheme.ACCENT)
	row.add_child(label)
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
	parent.add_child(row)

static func grid() -> GridContainer:
	var result := GridContainer.new()
	result.columns = 2
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("h_separation", 10)
	result.add_theme_constant_override("v_separation", 10)
	return result

static func card(button: Button, width: int = 238, height: int = 84) -> void:
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_constant_override("h_separation", 12)

static func fit_scroll(panel: Control, scroll: ScrollContainer, preferred: float) -> void:
	# Fit the scrollable body, keeping the existing title and summary visible.
	var fixed := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var available := panel.get_viewport_rect().size.y - panel.position.y - 22.0
	scroll.custom_minimum_size.y = clampf(available - fixed, 100.0, preferred)
	panel.size.y = panel.get_combined_minimum_size().y
