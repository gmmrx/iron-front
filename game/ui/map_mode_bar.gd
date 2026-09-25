class_name MapModeBar
extends PanelContainer
## Harita modu seçici (sağ alt).

signal mode_selected(mode: int)

var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -12
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var group := ButtonGroup.new()
	var keys := ["MAPMODE_POLITICAL", "MAPMODE_TERRAIN", "MAPMODE_STATES", "MAPMODE_ROUTES"]
	for i in keys.size():
		var b := Button.new()
		b.text = tr(keys[i])
		b.tooltip_text = tr("TIP_" + keys[i]) + "  (F%d)" % (i + 1)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = i == 0
		var idx := i
		b.pressed.connect(func() -> void: mode_selected.emit(idx))
		row.add_child(b)
		_buttons.append(b)

func set_mode(mode: int) -> void:
	if mode >= 0 and mode < _buttons.size():
		_buttons[mode].button_pressed = true
