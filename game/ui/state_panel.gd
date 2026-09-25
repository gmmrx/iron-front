class_name StatePanel
extends PanelContainer
## Seçili eyalet/bölge bilgi paneli (sol).

var _title: Label
var _flag: TextureRect
var _owner: Label
var _rows: Dictionary = {}   ## anahtar -> değer Label'ı
var _play_btn: Button
var _diplo_btn: Button
signal diplomacy_requested(tag: String)
var _buildings: VBoxContainer
var _state_id := 0
var _province_id := 0

func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 122)
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var head := HBoxContainer.new()
	_title = UiTheme.make_label("", 24, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), func() -> void: World.select_province(0)))
	v.add_child(head)
	v.add_child(HSeparator.new())

	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 10)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(45, 30)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	owner_row.add_child(_flag)
	_owner = UiTheme.make_label("", 20)
	_owner.add_theme_font_override("font", UiTheme.bold_font())
	owner_row.add_child(_owner)
	v.add_child(owner_row)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for key in ["UI_POPULATION", "UI_MANPOWER", "UI_VICTORY_POINTS", "UI_LARGEST_CITY", "UI_AREA", "UI_PROVINCES", "UI_STATE_ID"]:
		_add_row(grid, key)
	v.add_child(grid)

	v.add_child(HSeparator.new())
	var sub := UiTheme.make_label(tr("UI_SELECTED_PROVINCE"), 16, UiTheme.TEXT_DIM)
	v.add_child(sub)
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 24)
	for key in ["UI_CITY", "UI_TERRAIN", "UI_COASTAL", "UI_PROVINCE_AREA", "UI_PROVINCE_ID"]:
		_add_row(grid2, key)
	v.add_child(grid2)

	v.add_child(HSeparator.new())
	v.add_child(UiTheme.make_label(tr("UI_BUILDINGS"), 16, UiTheme.TEXT_DIM))
	_buildings = VBoxContainer.new()
	_buildings.add_theme_constant_override("separation", 3)
	v.add_child(_buildings)

	_play_btn = Button.new()
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.pressed.connect(_on_play_pressed)
	v.add_child(_play_btn)
	_diplo_btn = Button.new()
	_diplo_btn.text = tr("UI_DIPLOMACY_BTN")
	_diplo_btn.icon = UiTheme.icon("diplomacy")
	_diplo_btn.add_theme_constant_override("icon_max_width", 22)
	_diplo_btn.focus_mode = Control.FOCUS_NONE
	_diplo_btn.pressed.connect(func() -> void: diplomacy_requested.emit(World.states[_state_id].owner))
	v.add_child(_diplo_btn)

	World.selection_changed.connect(_on_selection)
	World.daily_update.connect(_refresh)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _refresh())
	World.player_changed.connect(func(_t: String) -> void: _refresh())

func _add_row(grid: GridContainer, key: String) -> void:
	grid.add_child(UiTheme.make_label(tr(key), 17, UiTheme.TEXT_DIM))
	var val := UiTheme.make_label("", 17)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(val)
	_rows[key] = val

func _on_selection(pid: int) -> void:
	var p := World.province(pid)
	_province_id = pid
	_state_id = p.state_id if p else 0
	visible = _state_id > 0
	if visible:
		for p2 in get_parent().get_children():
			if p2 != self and (p2 is ConstructionPanel or p2 is ProductionPanel or p2 is PoliticsPanel or p2 is TradePanel or p2 is ArmyPanel or p2 is ResearchPanel or p2 is DiplomacyPanel) and p2.visible:
				p2.close()
		_refresh()

func _refresh() -> void:
	if _state_id == 0:
		return
	var st: StateRegion = World.states[_state_id]
	var c: Country = World.countries[st.owner]
	var p := World.province(_province_id)
	_title.text = st.display_name()
	_flag.texture = FlagFactory.get_flag(c)
	_owner.text = c.display_name()
	_rows["UI_POPULATION"].text = UiTheme.format_number(st.population)
	_rows["UI_MANPOWER"].text = UiTheme.format_number(int(st.population * 0.015))
	_rows["UI_VICTORY_POINTS"].text = str(st.victory_points())
	var big := st.largest_city()
	_rows["UI_LARGEST_CITY"].text = big.display_name() if big else "—"
	_rows["UI_CITY"].text = (p.city.display_name() + (" (%s)" % tr("UI_PORT") if p.city.is_port else "")) if p.city else "—"
	_rows["UI_AREA"].text = "%s km²" % UiTheme.format_number(st.area_km2)
	_rows["UI_PROVINCES"].text = str(st.provinces.size())
	_rows["UI_STATE_ID"].text = "#%d" % st.id
	_rows["UI_TERRAIN"].text = tr("TERRAIN_" + p.terrain)
	_rows["UI_COASTAL"].text = tr("UI_YES") if p.coastal else tr("UI_NO")
	_rows["UI_PROVINCE_AREA"].text = "%s km²" % UiTheme.format_number(p.area_km2)
	_rows["UI_PROVINCE_ID"].text = "#%d" % p.id
	for child in _buildings.get_children():
		child.queue_free()
	_buildings.add_child(UiTheme.make_label("%s: %s  ·  %s: %d/%d" % [tr("UI_CATEGORY"), tr("CAT_" + st.category), tr("UI_SLOTS"), st.used_slots(), st.building_slots], 15, UiTheme.TEXT_DIM))
	for b: String in ["civilian_factory", "military_factory", "dockyard", "synthetic_refinery", "infrastructure", "air_base", "naval_base", "anti_air"]:
		var lv := st.building_level(b)
		if lv > 0:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.add_child(UiTheme.icon_texture(UiTheme.building_icon(b), 34))
			var building_name := UiTheme.make_label(Economy.building_name(b), 16)
			building_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(building_name)
			row.add_child(UiTheme.make_label(str(lv), 16, UiTheme.ACCENT))
			_buildings.add_child(row)
	for r: String in st.resources:
		var resource_row := HBoxContainer.new()
		resource_row.add_theme_constant_override("separation", 6)
		resource_row.add_child(UiTheme.icon_texture(UiTheme.resource_icon(r), 34))
		var resource_name := UiTheme.make_label(tr("RES_" + r), 16)
		resource_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_row.add_child(resource_name)
		resource_row.add_child(UiTheme.make_label(str(st.resources[r]), 16, UiTheme.ACCENT))
		_buildings.add_child(resource_row)
	_play_btn.text = tr("UI_PLAY_AS") % c.display_name()
	_play_btn.visible = st.owner != World.player_tag and not World.in_game
	_diplo_btn.visible = st.owner != World.player_tag and World.in_game
	var ctl := World.controller_of(_province_id)
	if ctl and ctl.tag != st.owner:
		_rows["UI_PROVINCE_ID"].text = "#%d · %s" % [p.id, tr("UI_OCCUPIED") % ctl.display_name()]

func _on_play_pressed() -> void:
	if _state_id > 0:
		World.set_player(World.states[_state_id].owner)
