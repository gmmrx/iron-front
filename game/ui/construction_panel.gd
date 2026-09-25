class_name ConstructionPanel
extends PanelContainer
## İnşaat ekranı (türün klasikleri "Construction"): bina seç, haritada eyalete tıkla -> kuyruk.

signal building_selected(building: String)

const ORDER := ["civilian_factory", "military_factory", "dockyard", "infrastructure", "air_base", "naval_base", "anti_air", "synthetic_refinery"]

var selected := ""
var _buttons := {}
var _cells: Array[Label] = []
var _queue_box: VBoxContainer
var _queue_head: PanelContainer
var _message: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_queue_box = PanelLayout.frame(self, tr("CONSTRUCTION_TITLE"), "construction", 500.0)
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["building_civilian_factory", tr("CON_CELL_CIV"), tr("CON_CELL_CIV_TIP")],
		["production", tr("CON_CELL_CONSUMER"), tr("CON_CELL_CONSUMER_TIP")],
		["construction", tr("CON_CELL_FREE"), tr("CON_CELL_FREE_TIP")],
		["stability", tr("CON_CELL_SPEED"), tr("CON_CELL_SPEED_TIP")]])
	PanelLayout.section(top, tr("CON_BUILDINGS"))
	var grid := PanelLayout.grid(4)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for b in ORDER:
		var btn := PanelLayout.tile(UiTheme.building_icon(b), Economy.building_name(b), UiTheme.format_number(Economy.defs[b]["cost"]),
			"%s\n%s\n\n%s" % [Economy.building_name(b), tr("BDESC_" + b), tr("TIP_BUILD_COST") % UiTheme.format_number(Economy.defs[b]["cost"])])
		btn.toggle_mode = true
		btn.button_group = group
		btn.toggled.connect(func(on: bool) -> void: _on_toggle(b, on))
		grid.add_child(btn)
		_buttons[b] = btn
	top.add_child(grid)
	_message = UiTheme.make_label(tr("CONSTRUCTION_HINT"), 15, UiTheme.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_message)
	_queue_head = PanelLayout.section(top, tr("CONSTRUCTION_QUEUE"))
	Economy.construction_changed.connect(func(tag: String) -> void:
		if tag == World.player_tag and visible:
			refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	World.player_changed.connect(func(_t: String) -> void: refresh())

func open() -> void:
	visible = true
	refresh()

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
	if c == null or _cells.is_empty():
		return
	var civ := Economy.count(c, "civilian_factory")
	_cells[0].text = str(civ)
	_cells[1].text = str(Economy.consumer_goods_factories(c))
	_cells[2].text = str(Economy.available_civilian(c))
	_cells[2].add_theme_color_override("font_color", UiTheme.GOOD if Economy.available_civilian(c) > 0 else UiTheme.BAD)
	var sp := c.mod("construction_speed") + Politics.stability_output_penalty(c)
	_cells[3].text = ("+" if sp >= 0 else "") + "%d%%" % roundi(sp * 100)
	_cells[3].add_theme_color_override("font_color", UiTheme.GOOD if sp >= 0 else UiTheme.BAD)
	(_queue_head.get_child(0) as Label).text = (tr("CONSTRUCTION_QUEUE") + "  (%d)" % c.construction_queue.size()).to_upper()
	for ch in _queue_box.get_children():
		ch.queue_free()
	if c.construction_queue.is_empty():
		PanelLayout.empty(_queue_box, tr("CON_QUEUE_EMPTY"))
	for i in c.construction_queue.size():
		_row(c, i)

func _row(c: Country, i: int) -> void:
	var p := c.construction_queue[i]
	var st: StateRegion = World.states[p.state_id]
	var tip := tr("TIP_PROJECT") % [Economy.building_name(p.building), st.display_name(), roundi(p.fraction() * 100), p.assigned_factories]
	var col := PanelLayout.row(_queue_box, UiTheme.building_icon(p.building), Economy.building_name(p.building), st.display_name(), tip,
		"Row" if p.assigned_factories > 0 else "Slot")
	col.add_child(PanelLayout.progress(p.fraction(), UiTheme.ACCENT if p.assigned_factories > 0 else UiTheme.TEXT_DIM))
	var days := p.days_left()
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 15:
		if k >= p.assigned_factories:
			break
		var dot := UiTheme.icon_texture(UiTheme.building_icon("civilian_factory"), 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(dot)
	var dl := UiTheme.make_label("  " + tr("CONSTRUCTION_ROW") % [p.assigned_factories, ("%d" % days) if days >= 0 else "—"], 13, UiTheme.TEXT_DIM)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(dl)
	col.add_child(info)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.add_child(UiTheme.icon_button("up", tr("TIP_QUEUE_UP"), func() -> void: Economy.move_project(c, i, -1), 24))
	hb.add_child(UiTheme.icon_button("down", tr("TIP_QUEUE_DOWN"), func() -> void: Economy.move_project(c, i, 1), 24))
	hb.add_child(UiTheme.icon_button("close", tr("TIP_QUEUE_REMOVE"), func() -> void: Economy.remove_project(c, i), 24))
	btns.add_child(hb)
	PanelLayout.row_action(col, btns)
