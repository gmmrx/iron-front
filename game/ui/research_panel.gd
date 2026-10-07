class_name ResearchPanel
extends PanelContainer
## Research projects share the existing research queue and save data. The catalog
## selects a dossier; only the explicit dossier action starts/cancels a project.

const NODE := Vector2(156, 214)

## Original artwork stays uncropped in a full-width top band. Its capped height
## keeps cards compact while reserving readable name/status space underneath.
class ProjectCard extends Button:
	const FRAME := 4.0
	const CAPTION_HEIGHT := 98.0
	const THUMBNAIL_HEIGHT := 108.0
	var thumbnail: TextureRect
	func _ready() -> void:
		resized.connect(_fit_thumbnail)
		_fit_thumbnail()
	func _fit_thumbnail() -> void:
		if thumbnail == null: return
		var side := minf(THUMBNAIL_HEIGHT, maxf(size.x, custom_minimum_size.x) - FRAME * 2.0)
		thumbnail.custom_minimum_size.y = side
		custom_minimum_size.y = side + CAPTION_HEIGHT + FRAME * 2.0
const CAT_ICON := {"governance": "politics", "infantry": "equipment_infantry_equipment",
	"artillery": "equipment_artillery_equipment", "armor": "equipment_medium_tank_equipment",
	"air": "air", "naval": "navy", "industry": "building_civilian_factory",
	"electronics": "research", "doctrine": "army"}
const BRANCHES := {"governance": ["governance"], "all": [], "army": ["infantry", "artillery", "armor"],
	"navy": ["naval"], "air": ["air"], "industry": ["industry", "electronics"], "doctrine": ["doctrine"]}

var _slots: GridContainer
var _speed: Label
var _nodes := {} # real technology ID -> selectable card Button
var _branch := "governance"
var _tabs: Array[Button] = []
var _catalog: VBoxContainer
var _detail: VBoxContainer
var _detail_actions: VBoxContainer
var _catalog_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _selected := ""
var _resize_pending := false
var _confirmation: ConfirmationDialog
var _pending_project := ""
var _start_button: Button
var _pending_project_focus := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	var body := PanelLayout.frame(self, tr("RESEARCH_TITLE"), "research", -1.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(get_meta("scroll") as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var top := PanelLayout.fixed(self)
	var rack := HBoxContainer.new()
	rack.add_theme_constant_override("separation", 12)
	top.add_child(rack)
	var head := VBoxContainer.new()
	head.custom_minimum_size.x = 144
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rack.add_child(head)
	var sec := UiTheme.make_label(tr("RES_ACTIVE_PROJECTS"), 16, UiTheme.ACCENT)
	sec.add_theme_font_override("font", UiTheme.bold_font())
	head.add_child(sec)
	_speed = UiTheme.make_label("", 13, UiTheme.TEXT_DIM)
	_speed.tooltip_text = tr("RES_SPEED_TIP")
	head.add_child(_speed)
	_slots = PanelLayout.grid(4)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_child(_slots)
	var filters := HBoxContainer.new()
	filters.name = "ResearchTabs"
	filters.add_theme_constant_override("separation", 6)
	top.add_child(filters)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	var names := ["RES_GOVERNANCE", "RES_ALL_PROJECTS", "RES_ARMY", "RES_NAVY", "RES_AIR", "RES_INDUSTRY", "RES_DOCTRINE"]
	var icons := ["politics", "research", "army", "navy", "air", "building_civilian_factory", "equipment_support_equipment"]
	var index := 0
	for branch: String in BRANCHES:
		var tab := Button.new()
		tab.name = "ResearchTab_" + branch
		tab.theme_type_variation = "Tab"
		tab.toggle_mode = true
		tab.button_group = tab_group
		tab.focus_mode = Control.FOCUS_ALL
		tab.text = tr(names[index])
		tab.tooltip_text = tab.text
		tab.icon = CommandPanelSkin.icon(icons[index])
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 28)
		tab.add_theme_font_size_override("font_size", UiTheme.fs(18))
		tab.custom_minimum_size.y = 56
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void: _set_branch(branch))
		filters.add_child(tab)
		_tabs.append(tab)
		index += 1
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	_catalog_scroll = _scroll_column(columns, "ResearchCatalog", 1.7)
	_catalog = VBoxContainer.new()
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog.add_theme_constant_override("separation", 14)
	_catalog_scroll.add_child(_catalog)
	var dossier_column := VBoxContainer.new()
	dossier_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_column.add_theme_constant_override("separation", 10)
	columns.add_child(dossier_column)
	_detail_scroll = _scroll_column(dossier_column, "ResearchDossier", 1.0)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail)
	_detail_actions = VBoxContainer.new()
	_detail_actions.name = "ResearchActions"
	_detail_actions.add_theme_constant_override("separation", 5)
	dossier_column.add_child(_detail_actions)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = tr("RES_CONFIRM_TITLE")
	_confirmation.dialog_autowrap = true
	_confirmation.theme = CommandPanelSkin.get_theme().duplicate()
	_confirmation.theme.set_stylebox("panel", "AcceptDialog", CommandPanelSkin.box("panel", 18))
	var window_border := ThemeDB.get_default_theme().get_stylebox("embedded_border", "Window").duplicate()
	if window_border is StyleBoxFlat:
		window_border.bg_color = Color("101719")
		window_border.border_color = Color("887045")
	_confirmation.theme.set_stylebox("embedded_border", "Window", window_border)
	_confirmation.theme.set_stylebox("embedded_unfocused_border", "Window", window_border)
	_confirmation.theme.set_color("title_color", "Window", UiTheme.ACCENT)
	_confirmation.ok_button_text = tr("RES_START_PROJECT")
	_confirmation.cancel_button_text = tr("RES_CONFIRM_CANCEL")
	_confirmation.confirmed.connect(_confirm_project)
	_confirmation.get_ok_button().set_meta("audio_silent", true)
	Audio.ui_bind(_confirmation.get_cancel_button(), "ui_close")
	add_child(_confirmation)
	Research.research_changed.connect(func(tag: String) -> void:
		if visible and tag == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	# Only viewport changes, never our minimum-size/resized signal (rebuild loop).
	get_viewport().size_changed.connect(_queue_layout_refresh)

func _scroll_column(parent: Container, node_name: String, ratio: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = ratio
	parent.add_child(scroll)
	DragScroll.attach(scroll)
	return scroll

func _queue_layout_refresh() -> void:
	if not visible or _resize_pending: return
	_resize_pending = true
	_finish_layout_refresh.call_deferred()

func _finish_layout_refresh() -> void:
	_resize_pending = false
	if visible: refresh()

func _set_branch(branch: String) -> void:
	if not BRANCHES.has(branch): return
	_branch = branch
	_catalog_scroll.scroll_vertical = 0
	_catalog_scroll.remove_meta("scroll_restore_value")
	refresh()

func open() -> void:
	visible = true
	refresh.call_deferred()

func close() -> void:
	visible = false
	_pending_project = ""
	_pending_project_focus = ""
	_confirmation.hide()

func refresh() -> void:
	var c := World.player()
	if c == null: return
	var focused := get_viewport().gui_get_focus_owner()
	var focused_project := ""
	if focused != null:
		for id: String in _nodes:
			var old_card: Control = _nodes[id]
			if focused == old_card or old_card.is_ancestor_of(focused):
				focused_project = id
				break
	elif _nodes.has(_pending_project_focus):
		# Two same-frame daily/research refreshes can happen before the first
		# deferred restore. Carry only a promise captured from a real card focus.
		focused_project = _pending_project_focus
	_pending_project_focus = focused_project
	var scroll_y := int(_catalog_scroll.get_meta("scroll_restore_value", _catalog_scroll.scroll_vertical))
	var detail_y := int(_detail_scroll.get_meta("scroll_restore_value", _detail_scroll.scroll_vertical))
	_clear(_catalog)
	_nodes.clear()
	_refresh_slots()
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(BRANCHES.keys()[i] == _branch)
	var cats: Array = Research.categories.keys()
	if cats.has("governance"):
		cats.erase("governance")
		cats.push_front("governance")
	var viewport := get_viewport_rect().size
	var catalog_width := maxf((viewport.x - 186.0) * 1.7 / 2.7 - 24.0, NODE.x)
	# A wide but short screen must not show only artwork with every title below
	# the fold. Reserve the fixed HUD/rack, section heading and caption first.
	var target_width := clampf(viewport.y - 554.0, NODE.x, 290.0)
	var capacity := maxi(1, int((catalog_width + 10.0) / (NODE.x + 10.0)))
	var count := clampi(ceili((catalog_width + 10.0) / (target_width + 10.0)), 1, mini(capacity, 6))
	for cat: String in cats:
		if _branch != "all" and cat not in BRANCHES[_branch]: continue
		var section := CommandPanelSkin.section(_catalog, Research.category_name(cat), CAT_ICON.get(cat, "research"))
		var grid := PanelLayout.grid(count)
		grid.name = "ResearchGrid_" + cat
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		section.add_child(grid)
		var ids: Array[String] = []
		for id: String in Research.techs:
			if Research.techs[id]["cat"] == cat and not Research.techs[id].get("repeat", false):
				ids.append(id)
		if cat != "governance":
			ids.sort_custom(func(a: String, b: String) -> bool:
				return int(Research.techs[a]["year"]) < int(Research.techs[b]["year"]) if Research.techs[a]["year"] != Research.techs[b]["year"] else a < b)
		if cat != "governance": ids.append(Research.next_repeat(c, cat))
		for id: String in ids:
			var card := _project_card(c, id)
			grid.add_child(card)
			_nodes[id] = card
	if not _nodes.has(_selected):
		_selected = ""
		for id: String in _nodes:
			if Research.can_research(c, id):
				_selected = id
				break
		if _selected == "" and not _nodes.is_empty(): _selected = _nodes.keys()[0]
	_refresh_detail()
	for id: String in _nodes: _nodes[id].set_pressed_no_signal(id == _selected)
	_catalog_scroll.set_meta("scroll_restore_value", scroll_y)
	_detail_scroll.set_meta("scroll_restore_value", detail_y)
	_restore_scroll.call_deferred(weakref(_catalog_scroll), scroll_y)
	_restore_scroll.call_deferred(weakref(_detail_scroll), detail_y)
	if focused_project != "" and _nodes.has(focused_project):
		_restore_project_focus.call_deferred(weakref(_nodes[focused_project]), focused_project)
	else:
		_pending_project_focus = ""
	PanelLayout.queue_fit(self)

func _restore_project_focus(reference: WeakRef, id: String) -> void:
	if _pending_project_focus != id: return
	var card := reference.get_ref() as Control
	if not is_instance_valid(card) or card.is_queued_for_deletion() or _nodes.get(id) != card: return
	_pending_project_focus = ""
	if not card.is_inside_tree() or not card.is_visible_in_tree(): return
	# A user may move into a branch tab/dossier while layout is pending; never
	# steal that newer focus. Restoring focus is inspection, not activation.
	if card.get_viewport().gui_get_focus_owner() == null: card.grab_focus()

static func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func _restore_scroll(reference: WeakRef, value: int, after_layout := false) -> void:
	var scroll := reference.get_ref() as ScrollContainer
	if not is_instance_valid(scroll) or scroll.is_queued_for_deletion(): return
	if not after_layout:
		ResearchPanel._restore_scroll.call_deferred(reference, value, true)
		return
	# A branch/selection change may cancel or replace this deferred restoration.
	if int(scroll.get_meta("scroll_restore_value", -1)) != value: return
	scroll.scroll_vertical = value
	scroll.remove_meta("scroll_restore_value")

func _project_card(c: Country, id: String) -> Button:
	var card := ProjectCard.new()
	card.set_meta("audio_silent", true)
	card.name = "Project_" + id
	card.custom_minimum_size = NODE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.toggle_mode = true
	card.clip_contents = true
	card.set_meta("tech_id", id)
	card.tooltip_text = _project_tip(c, id)
	var running := _active(c, id)
	var done := id in c.research_done
	var style := "selected" if running else ("good" if done else "card")
	card.add_theme_stylebox_override("normal", CommandPanelSkin.box(style, 4))
	card.add_theme_stylebox_override("hover", CommandPanelSkin.box("hover", 4))
	card.add_theme_stylebox_override("pressed", CommandPanelSkin.box("selected", 4))
	card.add_theme_stylebox_override("hover_pressed", CommandPanelSkin.box("selected", 4))
	card.add_theme_stylebox_override("focus", CommandPanelSkin.tab_box("focus"))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 4)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)
	var art := TextureRect.new()
	art.name = "Thumbnail"
	art.texture = _tech_icon(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.y = ProjectCard.THUMBNAIL_HEIGHT
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.thumbnail = art
	stack.add_child(art)
	var caption := MarginContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caption.add_theme_constant_override("margin_left", 10)
	caption.add_theme_constant_override("margin_right", 10)
	caption.add_theme_constant_override("margin_top", 8)
	caption.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(caption)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 6)
	caption.add_child(text)
	var title := UiTheme.make_label(Research.tech_name(id), 18, UiTheme.TEXT)
	title.name = "ProjectTitle"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.y = 48
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var status := tr("RES_DONE") if done else (tr("RES_RUNNING") if running else "%d %s" % [ceili(Research.days_needed(c, id)), tr("UI_DAYS")])
	if _current_government(c, id): status = tr("RES_CURRENT_GOVERNMENT")
	var label := UiTheme.make_label(status, 14, UiTheme.GOOD if done else (UiTheme.ACCENT if running else UiTheme.TEXT_DIM))
	label.name = "ProjectStatus"
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(label)
	if running: text.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 4))
	card.pressed.connect(func() -> void:
		Audio.research_cue(id, "select")
		_selected = id
		for key: String in _nodes: _nodes[key].set_pressed_no_signal(key == id)
		_detail_scroll.scroll_vertical = 0
		_detail_scroll.remove_meta("scroll_restore_value")
		_refresh_detail())
	return card

func _refresh_detail() -> void:
	_clear(_detail)
	_clear(_detail_actions)
	_start_button = null
	var c := World.player()
	if c == null or not Research.techs.has(_selected): return
	var id := _selected
	var t: Dictionary = Research.techs[id]
	var body := CommandPanelSkin.section(_detail, tr("RES_PROJECT_DOSSIER"), CAT_ICON.get(t["cat"], "research"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	body.add_child(head)
	head.add_child(UiTheme.icon_texture(_tech_icon(id), 96))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	var title := _paragraph(Research.tech_name(id), 22, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.bold_font())
	col.add_child(title)
	col.add_child(_paragraph(Research.category_name(t["cat"]), 14, UiTheme.TEXT_DIM))
	if not Research.is_government_project(id): col.add_child(UiTheme.make_label(str(int(t["year"])), 16, UiTheme.TEXT_DIM))
	var running := _active(c, id)
	var done := id in c.research_done
	var days := _remaining(c, id) if running else Research.days_needed(c, id)
	PanelLayout.stat(body, tr("RES_DURATION"), "%d %s" % [ceili(days), tr("UI_DAYS")], "", UiTheme.ACCENT)
	if running: body.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 6))
	if Research.is_government_project(id):
		var summary := Research.project_summary(c, id)
		var target: String = summary["target_ideology"]
		if target != "": body.add_child(_paragraph(tr("RES_GOVERNMENT_RESULT") % tr("IDEOLOGY_" + target), 17, UiTheme.TEXT))
		body.add_child(_paragraph(summary["description"], 16, UiTheme.TEXT_DIM))
		PanelLayout.stat(body, tr("RES_UPFRONT_COST"), "%d %s" % [roundi(summary["political_power_cost"]), tr("POL_PP_SHORT")], Research.project_costs_text(c, id), UiTheme.ACCENT)
		body.add_child(_paragraph(tr("RES_TRANSITION_EFFECTS"), 16, UiTheme.ACCENT))
		var mods: Dictionary = summary["temporary_mods"]
		for key: String in ["stability", "war_support", "political_power_gain"]:
			var value := roundi(float(mods.get(key, 0)) * 100)
			var amount := (tr("RES_CHANGE_POINTS") % value) if key != "political_power_gain" else "%+d%%" % value
			PanelLayout.stat(body, tr("MOD_" + key), amount, "", Color("cfaaa0"))
		body.add_child(_paragraph(tr("RES_REQUIREMENTS"), 16, UiTheme.ACCENT))
		body.add_child(_paragraph(tr("RES_GOVERNMENT_REQUIREMENTS") % roundi(float(summary["minimum_stability"]) * 100), 15, UiTheme.TEXT_DIM))
		body.add_child(_paragraph(tr("RES_CALENDAR_RULE"), 13, UiTheme.TEXT_DIM))
	else:
		body.add_child(_paragraph(tr("RES_EFFECTS"), 16, UiTheme.ACCENT))
		var effects := Politics.describe_mods(t.get("effects", {}))
		for unlock: String in t.get("unlock", []):
			if effects != "": effects += "\n"
			effects += tr("RESEARCH_UNLOCK") % Economy.equipment_name(unlock)
		body.add_child(_paragraph(effects if effects != "" else tr("RES_UNLOCK_NEXT"), 17, UiTheme.TEXT))
		var reqs: Array = t.get("req", [])
		if not reqs.is_empty():
			var names := PackedStringArray()
			for req: String in reqs: names.append(("✓ " if req in c.research_done else "• ") + Research.tech_name(req))
			body.add_child(_paragraph(tr("RES_REQUIREMENTS"), 16, UiTheme.ACCENT))
			body.add_child(_paragraph("\n".join(names), 15, UiTheme.TEXT_DIM))
		var ahead := maxi(int(t["year"]) - GameClock.year, 0)
		if ahead > 0 and not done:
			body.add_child(_paragraph(tr("RESEARCH_AHEAD") % [ahead, roundi(ahead * Research.AHEAD_PENALTY * 100)], 15, UiTheme.ACCENT))
	var reason: String = Research.can_start_reason(c, id) if not running and not done else ""
	if reason != "": body.add_child(_paragraph(reason, 15, UiTheme.TEXT_DIM))
	_start_button = Button.new()
	# Successful start/cancel cues come from the core research signals.
	_start_button.set_meta("audio_silent", true)
	_start_button.name = "ResearchProjectAction"
	_start_button.text = tr("RES_CANCEL_PROJECT") if running else (tr("RES_DONE") if done else tr("RES_START_PROJECT"))
	if _current_government(c, id): _start_button.text = tr("RES_CURRENT_GOVERNMENT")
	_start_button.custom_minimum_size.y = 48
	_start_button.add_theme_font_size_override("font_size", UiTheme.fs(18))
	_start_button.disabled = done or (not running and reason != "")
	_start_button.tooltip_text = reason
	_start_button.pressed.connect(_activate_selected)
	_detail_actions.add_child(_start_button)
	if running and Research.is_government_project(id):
		_detail_actions.add_child(_paragraph(tr("RES_CANCEL_NO_REFUND"), 13, UiTheme.TEXT_DIM))

func _activate_selected() -> void:
	var c := World.player()
	if c == null or not Research.techs.has(_selected): return
	if _active(c, _selected):
		Research.cancel(c, _selected)
		refresh()
	elif Research.can_start_reason(c, _selected) == "":
		if Research.is_government_project(_selected):
			_pending_project = _selected
			_confirmation.dialog_text = Research.tech_name(_selected) + "\n\n" + Research.project_costs_text(c, _selected)
			_confirmation.popup_centered(Vector2i(mini(580, int(get_viewport_rect().size.x) - 80), 380))
			Audio.play("ui_open")
		else:
			Research.start(c, _selected)
			refresh()

func _confirm_project() -> void:
	var c := World.player()
	if c != null and _pending_project != "":
		Research.start(c, _pending_project) # Revalidates costs/conditions at confirmation.
	_pending_project = ""
	refresh()

static func _paragraph(text: String, font_size: int, color: Color) -> Label:
	var label := UiTheme.make_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _project_tip(c: Country, id: String) -> String:
	var t: Dictionary = Research.techs[id]
	var tip := Research.tech_name(id)
	if Research.is_government_project(id): return tip + "\n" + Research.project_costs_text(c, id)
	tip += "\n" + Politics.describe_mods(t.get("effects", {}))
	for unlock: String in t.get("unlock", []): tip += "\n" + tr("RESEARCH_UNLOCK") % Economy.equipment_name(unlock)
	var names := PackedStringArray()
	for req: String in t.get("req", []): names.append(Research.tech_name(req))
	if not names.is_empty(): tip += "\n" + tr("RESEARCH_REQ") % ", ".join(names)
	return tip

static func _tech_icon(id: String) -> Texture2D:
	if Research.is_government_project(id): return load("res://assets/ui/command_panels/statecraft_v1.png")
	if Research.is_repeat(id): return CommandPanelSkin.illustration(CAT_ICON.get(Research.techs[id]["cat"], "research"))
	if UiTheme.PAINTED_ATLAS.has("tech_" + id): return UiTheme._painted_icon("tech_" + id)
	return UiTheme.technology_icon(id)

static func _active(c: Country, id: String) -> bool:
	for entry: Dictionary in c.research_current:
		if entry["tech"] == id: return true
	return false

static func _current_government(c: Country, id: String) -> bool:
	return Research.is_government_project(id) and str(Research.techs[id]["target_ideology"]) == c.ideology

static func _progress(c: Country, id: String) -> float:
	return Research.project_progress(c, id)

static func _remaining(c: Country, id: String) -> float:
	return Research.remaining_days(c, id)

func _refresh_slots() -> void:
	var c := World.player()
	if c == null: return
	_speed.text = tr("RES_SPEED") % roundi((Research.speed(c) - 1.0) * 100)
	_clear(_slots)
	var rack_width := maxf(get_viewport_rect().size.x - 340, 580)
	_slots.columns = clampi(int(rack_width / 270), 1, maxi(c.research_slots, 1))
	for i in c.research_slots:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(0, 76)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 8))
		_slots.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slot.add_child(row)
		var active := i < c.research_current.size()
		var id: String = c.research_current[i]["tech"] if active else ""
		row.add_child(UiTheme.icon_texture(_tech_icon(id) if active else CommandPanelSkin.icon("research"), 48))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := UiTheme.make_label(Research.tech_name(id) if active else tr("RES_AVAILABLE_SLOT") % (i + 1), 16, UiTheme.ACCENT)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(title)
		if active:
			col.add_child(UiTheme.make_label("%d %s" % [ceili(_remaining(c, id)), tr("UI_DAYS")], 13, UiTheme.TEXT_DIM))
			col.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 4))
			var inspect := Button.new()
			inspect.set_meta("audio_silent", true)
			inspect.set_meta("tech_id", id)
			inspect.text = tr("RES_INSPECT")
			inspect.custom_minimum_size = Vector2(64, 40)
			inspect.pressed.connect(func() -> void:
				Audio.research_cue(id, "select")
				_selected = id
				_branch = "all"
				refresh())
			row.add_child(inspect)
		else:
			col.add_child(UiTheme.make_label(tr("RES_CHOOSE_PROJECT"), 13, UiTheme.TEXT_DIM))

static func _progress_back(host: Control, bg: StyleBox, progress: float) -> void:
	var base := Panel.new()
	base.show_behind_parent = true
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.add_theme_stylebox_override("panel", bg)
	host.add_child(base)
	# dolgu: soldan sağa koyulaşan altın geçiş (ilerlemenin ucu en parlak), ucunda ince parlak çizgi
	var fill := TextureRect.new()
	fill.show_behind_parent = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.ACCENT.darkened(0.45), 0.10))
	g.set_color(1, Color(UiTheme.ACCENT.darkened(0.1), 0.42))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	fill.texture = gt
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	if progress < 0.995:
		var edge := ColorRect.new()
		edge.color = Color(UiTheme.ACCENT.lightened(0.2), 0.9)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		edge.offset_left = -2
		fill.add_child(edge)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_left = 0.0
	fill.anchor_right = clampf(progress, 0.0, 1.0)
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	fill.offset_right = -4 if progress >= 0.995 else 0
	host.add_child(fill)
