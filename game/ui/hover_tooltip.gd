class_name HoverTooltip
extends PanelContainer
## Bütün UI kontrollerinin tooltip_text içeriğini gecikmesiz, hiyerarşik bir bilgi kartına dönüştürür.

var _title: Label
var _body: Label
var _shortcut: Label
var _target: Control
var _source_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 100
	custom_minimum_size.x = 400.0
	add_theme_stylebox_override("panel", UiTheme.textured("tooltip", 10, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = UiTheme.make_label("", 20, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	_body = UiTheme.make_label("", 16, UiTheme.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 3)
	v.add_child(_body)
	_shortcut = UiTheme.make_label("", 14, UiTheme.ACCENT)
	_shortcut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_shortcut)
	# satır kaydıran etiketlere sabit genişlik: yoksa kart kelime kelime daralıp ekran boyu uzar
	for l: Label in [_title, _body, _shortcut]:
		l.custom_minimum_size.x = 372.0
	visible = false

func _process(_delta: float) -> void:
	var control := get_viewport().gui_get_hovered_control()
	while control and control.tooltip_text == "":
		control = control.get_parent() as Control
	if control == null or control == self or is_ancestor_of(control) or control.tooltip_text == "":
		_target = null
		visible = false
		return
	if control != _target or control.tooltip_text != _source_text:
		_target = control
		_source_text = control.tooltip_text
		_set_content(_source_text)
		visible = true
	_position_at_mouse()

func _set_content(text: String) -> void:
	var lines := text.split("\n")
	while not lines.is_empty() and String(lines[0]).strip_edges() == "":
		lines.remove_at(0)
	_title.text = String(lines[0]).strip_edges() if not lines.is_empty() else ""
	if not lines.is_empty():
		lines.remove_at(0)
	var shortcut := ""
	if not lines.is_empty():
		var last := String(lines[lines.size() - 1]).strip_edges()
		if last.begins_with("Shortcut:") or last.begins_with("Kısayol:"):
			shortcut = last
			lines.remove_at(lines.size() - 1)
	while not lines.is_empty() and String(lines[0]).strip_edges() == "":
		lines.remove_at(0)
	_body.text = "\n".join(lines).strip_edges()
	_body.visible = _body.text != ""
	_shortcut.text = shortcut
	_shortcut.visible = shortcut != ""
	reset_size()

func _position_at_mouse() -> void:
	var vp := get_viewport_rect().size
	var pos := get_viewport().get_mouse_position() + Vector2(20, 22)
	var card_size := Vector2(maxf(size.x, custom_minimum_size.x), size.y)
	# ekranın alt kısmındaki düğmeler (harita modları vb.): kart düğmenin üstünde açılır, altına taşmaz
	if _target and _target.get_global_rect().position.y > vp.y * 0.6:
		pos.y = _target.get_global_rect().position.y - card_size.y - 10.0
	pos.x = clampf(pos.x, 8.0, vp.x - card_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - card_size.y - 8.0)
	position = pos
