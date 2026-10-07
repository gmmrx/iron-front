class_name ConstructionPanel
extends PanelContainer
## Bina seçimi ve öncelik kuyruğu: iki okunur sütun; inşaat yalnız harita tıklamasıyla başlar.

signal building_selected(building: String)

const ORDER := ["civilian_factory", "military_factory", "infrastructure", "air_base", "naval_base", "anti_air"]

var selected := ""
var _buttons := {}
var _checks := {}
var _building_grid: GridContainer
var _cells: Array[Label] = []
var _queue_box: VBoxContainer
var _queue_head: PanelContainer
var _message: Label
var _catalog_scroll: ScrollContainer
var _queue_scroll: ScrollContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	var body := PanelLayout.frame(self, tr("CONSTRUCTION_TITLE"), "construction", 720.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.minimum_size_changed.connect(func() -> void:
		if visible: PanelLayout.queue_fit(self))
	(get_meta("scroll") as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var top := PanelLayout.fixed(self)
	_cells = PanelLayout.info_cells(top, [
		["building_civilian_factory", tr("CON_CELL_CIV"), tr("CON_CELL_CIV_TIP")],
		["production", tr("CON_CELL_CONSUMER"), tr("CON_CELL_CONSUMER_TIP")],
		["construction", tr("CON_CELL_FREE"), tr("CON_CELL_FREE_TIP")],
		["stability", tr("CON_CELL_SPEED"), tr("CON_CELL_SPEED_TIP")]])
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var catalog := VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.size_flags_stretch_ratio = 1.06
	catalog.add_theme_constant_override("separation", 9)
	columns.add_child(catalog)
	PanelLayout.section(catalog, tr("CON_BUILDINGS"))
	_catalog_scroll = _scroll_column(catalog, "ConstructionCatalog")
	_building_grid = PanelLayout.grid(2)
	_building_grid.add_theme_constant_override("h_separation", 9)
	_building_grid.add_theme_constant_override("v_separation", 9)
	_catalog_scroll.add_child(_building_grid)
	for b: String in _building_order():
		var button := _building_card(b)
		_building_grid.add_child(button)
		_buttons[b] = button
	_message = UiTheme.make_label(tr("CONSTRUCTION_HINT"), 14, UiTheme.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.max_lines_visible = 3
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message.custom_minimum_size.x = 1
	_message.custom_minimum_size.y = 43
	catalog.add_child(_message)
	var queue := VBoxContainer.new()
	queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue.add_theme_constant_override("separation", 9)
	columns.add_child(queue)
	_queue_head = PanelLayout.section(queue, tr("CONSTRUCTION_QUEUE"))
	_queue_scroll = _scroll_column(queue, "ConstructionQueue")
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 10)
	_queue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_scroll.add_child(_queue_box)
	Economy.construction_changed.connect(func(tag: String) -> void:
		if tag == World.player_tag and visible:
			refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	World.player_changed.connect(func(_t: String) -> void:
		if selected != "": _set_selection("")
		refresh())

func _scroll_column(parent: Container, node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	DragScroll.attach(scroll)
	return scroll

func _building_order() -> Array[String]:
	var result: Array[String] = []
	for b: String in ORDER:
		if Economy.defs.has(b): result.append(b)
	# Only expose definitions the current economy actually supports; disabled ship/fuel systems stay absent.
	for b: String in Economy.defs:
		var definition: Dictionary = Economy.defs[b]
		if b not in result and float(definition.get("cost", 0.0)) > 0.0 and int(definition.get("max", 0)) > 0:
			result.append(b)
	return result

func _building_card(b: String) -> Button:
	var button := Button.new()
	button.name = "Build_" + b
	button.theme_type_variation = "Card"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(190, 104)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("building_id", b)
	button.set_meta("construction_selected", false)
	var cost := UiTheme.format_number(Economy.defs[b]["cost"])
	button.tooltip_text = "%s\n%s\n\n%s" % [Economy.building_name(b), tr("BDESC_" + b), tr("TIP_BUILD_COST") % cost]
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, CommandPanelSkin.box("selected" if state in ["pressed", "hover_pressed", "focus"] else ("hover" if state == "hover" else "button"), 10))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 10
	row.offset_right = -10
	row.offset_bottom = -10
	button.add_child(row)
	var icon := UiTheme.icon_texture(UiTheme.trimmed(UiTheme.building_icon(b)), 46)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 5)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(labels)
	var title := UiTheme.make_label(Economy.building_name(b), 16, UiTheme.TEXT)
	title.name = "BuildingName"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(title)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(footer)
	var cost_icon := UiTheme.icon_texture(UiTheme.trimmed(UiTheme.building_icon("civilian_factory")), 16)
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(cost_icon)
	var price := UiTheme.make_label(cost, 14, UiTheme.ACCENT)
	price.name = "BuildingCost"
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(price)
	var check := ForceSelectionCard.checkbox(false, func() -> void: pass)
	check.name = "BuildingCheck"
	check.custom_minimum_size = Vector2(26, 26)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.focus_mode = Control.FOCUS_NONE
	footer.add_child(check)
	_checks[b] = check
	button.pressed.connect(func() -> void: _set_selection("" if selected == b else b))
	return button

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false
	if selected != "": _set_selection("")

func _on_toggle(b: String, on: bool) -> void:
	if on:
		_set_selection(b)
	elif selected == b:
		_set_selection("")

func _set_selection(b: String) -> void:
	if b != "" and not _buttons.has(b): return
	var changed := selected != b
	selected = b
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var active := id == selected
		button.set_pressed_no_signal(active)
		button.set_meta("construction_selected", active)
		(_checks[id] as Button).set_pressed_no_signal(active)
		(_checks[id] as Button).queue_redraw()
		(button.find_child("BuildingName", true, false) as Label).add_theme_color_override("font_color", UiTheme.ACCENT if active else UiTheme.TEXT)
	_message.text = tr("CONSTRUCTION_HINT") if selected == "" else tr("CONSTRUCTION_CLICK_STATE") % Economy.building_name(selected)
	_message.tooltip_text = _message.text
	_message.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	if changed: building_selected.emit(selected)

func show_result(err: String) -> void:
	_message.text = tr("CONSTRUCTION_QUEUED") if err == "" else tr(err)
	_message.tooltip_text = _message.text
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
	var scroll_y := int(_queue_scroll.get_meta("scroll_restore_value", _queue_scroll.scroll_vertical))
	for ch in _queue_box.get_children():
		_queue_box.remove_child(ch)
		ch.queue_free()
	if c.construction_queue.is_empty():
		PanelLayout.empty(_queue_box, tr("CON_QUEUE_EMPTY"))
	for i in c.construction_queue.size():
		_row(c, i)
	_queue_scroll.set_meta("scroll_restore_value", scroll_y)
	_restore_queue_scroll.call_deferred()

func _restore_queue_scroll() -> void:
	if not is_instance_valid(_queue_scroll) or not _queue_scroll.has_meta("scroll_restore_value"): return
	_queue_scroll.scroll_vertical = int(_queue_scroll.get_meta("scroll_restore_value"))
	_queue_scroll.remove_meta("scroll_restore_value")

func _row(c: Country, i: int) -> void:
	var p: ConstructionProject = c.construction_queue[i]
	var st: StateRegion = World.states.get(p.state_id)
	var state_name := st.display_name() if st else str(p.state_id)
	var name := Economy.building_name(p.building) if Economy.defs.has(p.building) else p.building.replace("_", " ").capitalize()
	var percent := roundi(p.fraction() * 100)
	var card := PanelContainer.new()
	card.name = "Project_%d" % i
	card.set_meta("construction_project", p)
	card.set_meta("project_index", i)
	card.tooltip_text = tr("TIP_PROJECT") % [name, state_name, percent, p.assigned_factories]
	card.add_theme_stylebox_override("panel", CommandPanelSkin.box("card" if p.assigned_factories > 0 else "inset", 12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_box.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	content.add_child(head)
	var icon := UiTheme.icon_texture(UiTheme.trimmed(UiTheme.building_icon(p.building)), 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 2)
	head.add_child(names)
	var title := UiTheme.make_label(name, 16, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.custom_minimum_size.x = 1
	names.add_child(title)
	var location := UiTheme.make_label(state_name, 14, UiTheme.TEXT_DIM)
	location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location.max_lines_visible = 2
	location.custom_minimum_size.x = 1
	names.add_child(location)
	var priority := UiTheme.make_label("%02d" % (i + 1), 16, UiTheme.ACCENT if p.assigned_factories > 0 else UiTheme.TEXT_DIM)
	priority.add_theme_font_override("font", UiTheme.bold_font())
	priority.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(priority)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 9)
	content.add_child(progress)
	var bar := PanelLayout.progress(p.fraction(), UiTheme.ACCENT if p.assigned_factories > 0 else UiTheme.TEXT_DIM, 9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(bar)
	var percent_label := UiTheme.make_label("%d%%" % percent, 14, UiTheme.ACCENT)
	percent_label.name = "ProjectProgress"
	percent_label.custom_minimum_size.x = 38
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.add_child(percent_label)
	var days := p.days_left() if p.assigned_factories > 0 else -1
	var details := UiTheme.make_label(tr("CONSTRUCTION_ROW") % [p.assigned_factories, str(days) if days >= 0 else "—"], 14, UiTheme.TEXT_DIM)
	details.name = "ProjectAllocation"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 1
	content.add_child(details)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	content.add_child(footer)
	var work := UiTheme.make_label("%s / %s" % [UiTheme.format_number(p.progress), UiTheme.format_number(p.cost)], 13, UiTheme.TEXT_DIM)
	work.name = "ProjectWork"
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	work.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	work.custom_minimum_size.x = 1
	footer.add_child(work)
	footer.add_child(_queue_action("up", tr("TIP_QUEUE_UP"), func() -> void: _operate_project(c, p, -1), i > 0))
	footer.add_child(_queue_action("down", tr("TIP_QUEUE_DOWN"), func() -> void: _operate_project(c, p, 1), i + 1 < c.construction_queue.size()))
	footer.add_child(_queue_action("close", tr("TIP_QUEUE_REMOVE"), func() -> void: _operate_project(c, p, 0, true), true))
	for node: Node in card.find_children("*", "Control", true, false):
		if not node is BaseButton: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _queue_action(icon: String, tip: String, action: Callable, enabled: bool) -> Button:
	var button := UiTheme.icon_button(icon, tip, action, 36)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("queue_action", icon)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, CommandPanelSkin.box("selected" if state in ["pressed", "focus"] else ("hover" if state == "hover" else ("disabled" if state == "disabled" else "button")), 7))
	return button

func _operate_project(c: Country, p: ConstructionProject, delta: int, remove: bool = false) -> void:
	if not World.in_game or c != World.player(): return
	var index := c.construction_queue.find(p)
	if index < 0: return
	if remove: Economy.remove_project(c, index)
	else: Economy.move_project(c, index, delta)
