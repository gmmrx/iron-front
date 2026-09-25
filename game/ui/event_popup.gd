class_name EventPopup
extends PanelContainer
## Oyuncuya gelen olaylar: başlık, açıklama, seçenekler (etkileri ipucunda). Açıkken oyun duraklar.

var _title: Label
var _event_icon: TextureRect
var _desc: Label
var _opts: VBoxContainer
var _current := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_event_icon = UiTheme.icon_texture(null, 82)
	title_row.add_child(_event_icon)
	_title = UiTheme.make_label("", 28, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_title)
	v.add_child(title_row)
	v.add_child(HSeparator.new())
	_desc = UiTheme.make_label("", 18)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 520
	v.add_child(_desc)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 6)
	v.add_child(_opts)
	Politics.event_fired.connect(func(_t: String, _id: String, _f: String) -> void: _next())

func _next() -> void:
	if visible or Politics.pending_events.is_empty():
		return
	_current = Politics.pending_events.pop_front()
	var ev: Dictionary = Politics.events[_current["id"]]
	var from: Country = World.countries.get(_current["from"])
	_event_icon.texture = UiTheme.event_icon(_current["id"])
	_title.text = Politics.loc(ev["title"])
	_desc.text = Politics.loc(ev["desc"]) + ("\n\n" + tr("EVENT_FROM") % from.display_name() if from else "")
	for ch in _opts.get_children():
		ch.queue_free()
	var opts: Array = ev["options"]
	for i in opts.size():
		var b := Button.new()
		b.text = Politics.loc(opts[i]["name"])
		b.custom_minimum_size.y = 44
		b.focus_mode = Control.FOCUS_NONE
		var eff := Politics.describe_effects(opts[i]["effects"], _current["from"])
		b.tooltip_text = eff if eff != "" else tr("EVENT_NO_EFFECT")
		b.pressed.connect(func() -> void:
			visible = false
			Politics.choose_option(World.player(), _current["id"], i, _current["from"])
			_next())
		_opts.add_child(b)
	visible = true
	GameClock.set_paused(true)
