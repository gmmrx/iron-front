class_name Hud
extends CanvasLayer
## Tüm oyun arayüzünün kökü: üst bar, görev çubuğu, sol paneller, tümen paneli, olaylar, bildirimler, menüler.

signal construction_toggled(open: bool)

var root: Control
var top_bar: TopBar
var state_panel: StatePanel
var tooltip: MapTooltip
var ui_tooltip: HoverTooltip
var map_modes: MapModeBar
var construction: ConstructionPanel
var production: ProductionPanel
var politics: PoliticsPanel
var trade: TradePanel
var army: ArmyPanel
var research: ResearchPanel
var diplomacy: DiplomacyPanel
var navy: NavyPanel
var air: AirPanel
var logistics: LogisticsPanel
var focus: FocusPanel
var divisions: DivisionPanel
var events: EventPopup
var feed: NotificationFeed
var pause_menu: PauseMenu
var game_over: GameOverScreen
var task_bar: HBoxContainer
var alerts: AlertBar
var select_box: Panel

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	top_bar = TopBar.new()
	root.add_child(top_bar)
	state_panel = StatePanel.new()
	root.add_child(state_panel)
	map_modes = MapModeBar.new()
	root.add_child(map_modes)
	construction = ConstructionPanel.new()
	production = ProductionPanel.new()
	politics = PoliticsPanel.new()
	trade = TradePanel.new()
	army = ArmyPanel.new()
	research = ResearchPanel.new()
	diplomacy = DiplomacyPanel.new()
	navy = NavyPanel.new()
	air = AirPanel.new()
	logistics = LogisticsPanel.new()
	for p in [construction, production, politics, trade, army, navy, air, research, diplomacy, logistics]:
		root.add_child(p)
		_decorate_side_panel(p)
	focus = FocusPanel.new()
	politics.focus_requested.connect(func() -> void: toggle_focus())
	root.add_child(focus)
	divisions = DivisionPanel.new()
	root.add_child(divisions)
	feed = NotificationFeed.new()
	root.add_child(feed)
	task_bar = top_bar.task_row
	var tasks := [
		["TASK_POLITICS", "politics", toggle_politics, "menu_politics"], ["TASK_FOCUS", "focus_g_unity", toggle_focus, "menu_focus"],
		["TASK_RESEARCH_KEY", "research", toggle_research, "menu_research"], ["TASK_DIPLOMACY_KEY", "diplomacy", toggle_diplomacy, "menu_diplomacy"],
		["TASK_TRADE", "trade", toggle_trade, "menu_trade"], ["CONSTRUCTION_BUTTON", "construction", toggle_construction, "menu_construction"],
		["TASK_PRODUCTION", "production", toggle_production, "menu_production"], ["TASK_ARMY", "army", toggle_army, "menu_army"],
		["TASK_NAVY", "navy", toggle_navy, "menu_navy"], ["TASK_AIR", "air", toggle_air, "menu_air"],
		["TASK_LOGISTICS_KEY", "equipment_motorized_equipment", toggle_logistics, "menu_logistics"]]
	# kare simge düğmeleri: ad ipucunda, kısayol harfi köşede
	for t: Array in tasks:
		var b := Button.new()
		b.icon = UiTheme.icon_or(t[3], t[1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 38)
		for spec: Array in [["normal", "menu_btn"], ["hover", "menu_btn_hover"], ["pressed", "menu_btn_pressed"], ["hover_pressed", "menu_btn_pressed"]]:
			var sb2 := UiTheme.skin(spec[1], 8, 3)
			b.add_theme_stylebox_override(spec[0], sb2)
		b.add_theme_color_override("icon_normal_color", Color(1.25, 1.2, 1.1))
		b.add_theme_color_override("icon_hover_color", Color(1.45, 1.4, 1.3))
		b.add_theme_color_override("icon_pressed_color", UiTheme.ACCENT)
		b.focus_mode = Control.FOCUS_NONE
		var label: String = tr(t[0])
		var tipkey: String = "TIP_" + String(t[0]).replace("_KEY", "")
		b.tooltip_text = "%s\n%s" % [label, tr(tipkey)]
		b.custom_minimum_size = Vector2(54, 46)
		b.pressed.connect(t[2])
		var m := RegEx.create_from_string("\\(([^)]+)\\)").search(label)
		if m:
			var k := UiTheme.make_label(m.get_string(1), 13, Color(1.0, 0.93, 0.75))
			k.add_theme_font_override("font", UiTheme.bold_font())
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			k.position = Vector2(40, 27)
			k.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
			k.add_theme_constant_override("shadow_offset_x", 1)
			k.add_theme_constant_override("shadow_offset_y", 1)
			k.add_theme_constant_override("outline_size", 3)
			k.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			b.add_child(k)
		task_bar.add_child(b)
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(14, 0)
	task_bar.add_child(sep)
	alerts = AlertBar.new()
	alerts.hud = self
	task_bar.add_child(alerts)
	select_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.4, 0.12)
	sb.border_color = Color(1.0, 0.85, 0.4, 0.9)
	sb.set_border_width_all(1)
	select_box.add_theme_stylebox_override("panel", sb)
	select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_box.visible = false
	root.add_child(select_box)
	tooltip = MapTooltip.new()
	root.add_child(tooltip)
	ui_tooltip = HoverTooltip.new()
	root.add_child(ui_tooltip)
	events = EventPopup.new()
	root.add_child(events)
	game_over = GameOverScreen.new()
	root.add_child(game_over)
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	state_panel.diplomacy_requested.connect(func(tag: String) -> void:
		_close_all()
		diplomacy.open_for(tag))

const SIDE_X := 12.0
const SIDE_Y := 128.0

## Yan paneller: sol kenara sabit, başlıkta kapatma düğmesi, açılırken kayarak gelir
func _decorate_side_panel(p: Control) -> void:
	p.position = Vector2(SIDE_X, SIDE_Y)
	_add_close(p)
	p.visibility_changed.connect(func() -> void:
		if p.visible:
			p.position = Vector2(-p.size.x - 20.0, SIDE_Y)
			p.modulate.a = 0.0
			var tw := p.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "position:x", SIDE_X, 0.22)
			tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18))

func _add_close(p: Control) -> void:
	if p is DiplomacyPanel:
		return          # kendi başlığını her yenilemede kurar
	if p.has_meta("framed"):
		return          # PanelLayout.frame başlığı kendi kapatma düğmesini taşır
	var v := p.get_child(0)
	if v == null or v.get_child_count() == 0 or not v.get_child(0) is Label:
		return
	var title: Label = v.get_child(0)
	var head := HBoxContainer.new()
	v.add_child(head)
	v.move_child(head, 0)
	title.reparent(head)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), func() -> void: close_panels()))

func is_mouse_over_ui() -> bool:
	var c := root.get_viewport().gui_get_hovered_control()
	return c != null and c != root

func _left_panels() -> Array:
	return [construction, production, politics, trade, army, navy, air, research, diplomacy, logistics]

func _close_all() -> void:
	for p in _left_panels():
		if p.visible:
			p.close()
	if focus.visible:
		focus.close()
	state_panel.visible = false

## Sol paneller: aynı anda yalnız biri açık
func _open_only(panel: Control) -> void:
	var was_open := panel.visible
	_close_all()
	if not was_open:
		panel.open()
	construction_toggled.emit(construction.visible)

func any_panel_open() -> bool:
	for p in _left_panels():
		if p.visible:
			return true
	return focus.visible

func close_panels() -> void:
	_close_all()
	construction_toggled.emit(false)

func toggle_construction() -> void: _open_only(construction)
func toggle_production() -> void: _open_only(production)
func toggle_politics() -> void: _open_only(politics)
func toggle_trade() -> void: _open_only(trade)
func toggle_army() -> void: _open_only(army)
func toggle_navy() -> void: _open_only(navy)
func toggle_air() -> void: _open_only(air)
func toggle_logistics() -> void: _open_only(logistics)
## Donanma panelini açık tut (filo seçilince)
func show_navy() -> void:
	if not navy.visible:
		_open_only(navy)
func toggle_research() -> void: _open_only(research)
func toggle_diplomacy() -> void:
	diplomacy.target = ""
	_open_only(diplomacy)
func toggle_focus() -> void:
	var was := focus.visible
	_close_all()
	if not was:
		focus.open()

## Oyun arayüzü yalnız oyun başlayınca görünür (menü/ülke seçiminde gizli)
func set_game_ui_visible(v: bool) -> void:
	top_bar.visible = v
	map_modes.visible = v
	task_bar.visible = v
	feed.visible = v
	if not v:
		_close_all()
