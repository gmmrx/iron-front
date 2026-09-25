class_name ConstructionPanel
extends PanelContainer
## İnşaat ekranı (türün klasikleri "Construction"): bina seç, haritada eyalete tıkla -> kuyruk.

signal building_selected(building: String)

const ORDER := ["civilian_factory", "military_factory", "dockyard", "infrastructure", "air_base", "naval_base", "anti_air", "synthetic_refinery"]

var selected := ""
var _buttons := {}
var _summary: Label
var _queue_box: VBoxContainer
var _message: Label
var _scroll: ScrollContainer

func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	size = Vector2(480, 760)
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("CONSTRUCTION_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_summary = UiTheme.make_label("", 16, UiTheme.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(HSeparator.new())

	var grid := PanelLayout.grid()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for b in ORDER:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(224, 82)
		btn.text = "%s\n%s" % [Economy.building_name(b), UiTheme.format_number(Economy.defs[b]["cost"])]
		btn.icon = UiTheme.building_icon(b)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("icon_max_width", 68)
		btn.tooltip_text = "%s\n%s\n\n%s" % [Economy.building_name(b), tr("BDESC_" + b), tr("TIP_BUILD_COST") % UiTheme.format_number(Economy.defs[b]["cost"])]
		PanelLayout.card(btn, 238, 88)
		btn.toggled.connect(func(on: bool) -> void: _on_toggle(b, on))
		grid.add_child(btn)
		_buttons[b] = btn
	v.add_child(grid)
	_message = UiTheme.make_label(tr("CONSTRUCTION_HINT"), 15, UiTheme.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message)
	v.add_child(HSeparator.new())
	PanelLayout.section(v, tr("CONSTRUCTION_QUEUE"))

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 360
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_queue_box = VBoxContainer.new()
	_queue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_queue_box)
	v.add_child(scroll)

	Economy.construction_changed.connect(func(tag: String) -> void:
		if tag == World.player_tag and visible:
			refresh())
	World.player_changed.connect(func(_t: String) -> void: refresh())
	get_viewport().size_changed.connect(_fit)

func open() -> void:
	visible = true
	refresh()
	_fit.call_deferred()

func _fit() -> void:
	PanelLayout.fit_scroll(self, _scroll, 300)

func close() -> void:
	visible = false
	if selected != "":
		_buttons[selected].button_pressed = false

func _on_toggle(b: String, on: bool) -> void:
	if on:
		selected = b
	elif selected == b:
		selected = ""
	building_selected.emit(selected)
	_message.text = tr("CONSTRUCTION_HINT") if selected == "" else tr("CONSTRUCTION_CLICK_STATE") % Economy.building_name(selected)
	_message.add_theme_color_override("font_color", UiTheme.TEXT_DIM)

func show_result(err: String) -> void:
	_message.text = tr("CONSTRUCTION_QUEUED") if err == "" else tr(err)
	_message.add_theme_color_override("font_color", UiTheme.GOOD if err == "" else UiTheme.BAD)

func refresh() -> void:
	var c := World.player()
	if c == null:
		return
	_summary.text = tr("CONSTRUCTION_SUMMARY") % [Economy.count(c, "civilian_factory"), Economy.consumer_goods_factories(c), Economy.available_civilian(c)]
	for ch in _queue_box.get_children():
		ch.queue_free()
	for i in c.construction_queue.size():
		_queue_box.add_child(_row(c, i))
	_fit.call_deferred()

func _row(c: Country, i: int) -> Control:
	var p := c.construction_queue[i]
	var st: StateRegion = World.states[p.state_id]
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_style(Color(1, 1, 1, 0.04), UiTheme.BORDER_DIM)
	sb.shadow_size = 0
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var name := UiTheme.make_label("%s — %s" % [Economy.building_name(p.building), st.display_name()], 16)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = 220
	head.add_child(name)
	head.add_child(UiTheme.icon_button("up", tr("TIP_QUEUE_UP"), func() -> void: Economy.move_project(c, i, -1), 26))
	head.add_child(UiTheme.icon_button("down", tr("TIP_QUEUE_DOWN"), func() -> void: Economy.move_project(c, i, 1), 26))
	head.add_child(UiTheme.icon_button("close", tr("TIP_QUEUE_REMOVE"), func() -> void: Economy.remove_project(c, i), 26))
	panel.tooltip_text = tr("TIP_PROJECT") % [Economy.building_name(p.building), st.display_name(), roundi(p.fraction() * 100), p.assigned_factories]
	v.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = p.fraction()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ACCENT if p.assigned_factories > 0 else UiTheme.TEXT_DIM
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)
	var days := p.days_left()
	var info := tr("CONSTRUCTION_ROW") % [p.assigned_factories, ("%d" % days) if days >= 0 else "—"]
	v.add_child(UiTheme.make_label(info, 14, UiTheme.TEXT_DIM))
	return panel
