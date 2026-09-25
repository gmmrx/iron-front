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
	custom_minimum_size = Vector2(600, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	# başlık bandı
	var hp := PanelContainer.new()
	hp.theme_type_variation = "Header"
	v.add_child(hp)
	_title = UiTheme.make_label("", 24, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hp.add_child(_title)
	# resim: altın çerçeveli, geniş
	var pic := PanelContainer.new()
	pic.theme_type_variation = "SlotGold"
	pic.custom_minimum_size = Vector2(0, 220)
	v.add_child(pic)
	_event_icon = TextureRect.new()
	_event_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_event_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_event_icon.custom_minimum_size = Vector2(560, 210)
	_event_icon.clip_contents = true
	pic.add_child(_event_icon)
	_desc = UiTheme.make_label("", 17)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 560
	v.add_child(_desc)
	PanelLayout.section(v, tr("EVENT_CHOICES"))
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
	var pic_tex := UiTheme.event_icon(_current["id"])
	_event_icon.texture = pic_tex if pic_tex else UiTheme.icon("focus_g_politics")
	_title.text = Politics.loc(ev["title"])
	_desc.text = Politics.loc(ev["desc"]) + ("\n\n" + tr("EVENT_FROM") % from.display_name() if from and from.tag != World.player_tag else "")
	for ch in _opts.get_children():
		ch.queue_free()
	var opts: Array = ev["options"]
	for i in opts.size():
		var b := Button.new()
		var eff := Politics.describe_effects(opts[i]["effects"], _current["from"])
		b.text = "▸  " + Politics.loc(opts[i]["name"])
		b.theme_type_variation = "Card"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size = Vector2(560, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = eff if eff != "" else tr("EVENT_NO_EFFECT")
		if not Politics.option_available(World.player(), _current["id"], i):
			b.disabled = true
			var need := ""
			for cond: Dictionary in opts[i]["require"]:
				if cond.has("leader"):
					need = tr("EVENT_NEED_LEADER") % cond["leader"]
			b.tooltip_text = (need if need != "" else tr("EVENT_OPTION_LOCKED")) + "\n\n" + b.tooltip_text
		b.pressed.connect(func() -> void:
			visible = false
			Politics.choose_option(World.player(), _current["id"], i, _current["from"])
			_next())
		_opts.add_child(b)
	visible = true
	GameClock.set_paused(true)
