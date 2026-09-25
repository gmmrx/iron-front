class_name MapTooltip
extends PanelContainer
## Harita üzerindeki bölge için gecikmesiz, karar vermeye yarayan stratejik bilgi kartı.

var _flag: TextureRect
var _title: Label
var _subtitle: Label
var _political: Label
var _facts: Label
var _economy: Label
var _military: Label
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 420.0
	add_theme_stylebox_override("panel", UiTheme.textured("tooltip", 10, 13))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(44, 28)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_flag)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UiTheme.make_label("", 22, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_subtitle = UiTheme.make_label("", 15, UiTheme.TEXT_DIM)
	titles.add_child(_title)
	titles.add_child(_subtitle)
	head.add_child(titles)
	v.add_child(head)

	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	_political = _section(v, 17, UiTheme.TEXT)
	_facts = _section(v, 16, UiTheme.TEXT)
	_economy = _section(v, 16, UiTheme.TEXT)
	_military = _section(v, 16, UiTheme.TEXT)
	_hint = _section(v, 14, UiTheme.ACCENT)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	visible = false

func _section(parent: VBoxContainer, font_size: int, color: Color) -> Label:
	var l := UiTheme.make_label("", font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 392.0   # sarmalama genişliği sabit: yerleşimden önce yükseklik binlerce satıra fırlıyordu (dev boş kart)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func show_province(pid: int, screen_pos: Vector2) -> void:
	var p := World.province(pid)
	if p == null:
		visible = false
		return
	if p.is_land():
		_show_land(p)
	else:
		_show_water(p)
	_position_card(screen_pos)

func _show_land(p: Province) -> void:
	var st := World.state_of_province(p.id)
	if st == null:
		visible = false
		return
	var owner: Country = World.countries.get(st.owner)
	var controller: Country = World.controller_of(p.id)
	if controller == null:
		controller = owner
	_flag.texture = FlagFactory.get_flag(owner) if owner else null
	_title.text = p.city.display_name() if p.city else st.display_name()
	_subtitle.text = (tr("TIPMAP_CITY_IN") % st.display_name()) if p.city else tr("TIPMAP_STATE")

	var relation := tr("TIPMAP_OURS") if owner and owner.tag == World.player_tag else tr("TIPMAP_FOREIGN")
	if owner and Diplomacy.are_enemies(World.player_tag, owner.tag):
		relation = tr("TIPMAP_ENEMY")
	_political.text = "%s  ·  %s" % [owner.display_name() if owner else "—", relation]
	if controller and owner and controller.tag != owner.tag:
		_political.text += "\n%s: %s" % [tr("TIPMAP_CONTROLLER"), controller.display_name()]

	var terrain := tr("TERRAIN_" + p.terrain)
	var geography := terrain
	if p.coastal:
		geography += "  ·  " + tr("TIPMAP_COASTAL")
	if not p.river_adjacent.is_empty():
		geography += "  ·  " + tr("TIPMAP_RIVER")
	_facts.text = "%s\n%s: #%d  ·  %s km²\n%s: %s  ·  %s: %d" % [
		geography, tr("UI_PROVINCE_ID"), p.id, UiTheme.format_number(p.area_km2),
		tr("UI_POPULATION"), UiTheme.format_number(st.population), tr("TIPMAP_CONNECTIONS"), p.adjacent.size()]
	if p.city:
		_facts.text += "\n%s: %d" % [tr("TIPMAP_VICTORY_POINTS"), p.city.victory_points]
		if p.city.is_port:
			_facts.text += "  ·  " + tr("TIPMAP_PORT_CITY")

	var build_lines: Array[String] = []
	build_lines.append("%s: %d/%d  ·  %s: %d" % [tr("UI_SLOTS"), st.used_slots(), st.building_slots,
			Economy.building_name("infrastructure"), st.building_level("infrastructure")])
	var buildings: Array[String] = []
	for b: String in ["civilian_factory", "military_factory", "dockyard", "air_base", "naval_base", "anti_air", "synthetic_refinery"]:
		var level := st.building_level(b)
		if level > 0:
			buildings.append("%s %d" % [Economy.building_name(b), level])
	if not buildings.is_empty():
		build_lines.append("%s: %s" % [tr("TIPMAP_BUILDINGS"), ", ".join(buildings)])
	var resources: Array[String] = []
	for res: String in st.resources:
		if int(st.resources[res]) > 0:
			resources.append("%s %d" % [tr("RES_" + res), int(st.resources[res])])
	if not resources.is_empty():
		build_lines.append("%s: %s" % [tr("UI_RESOURCES"), ", ".join(resources)])
	_economy.text = "\n".join(build_lines)

	var forces: Dictionary = {}
	for d: Division in Military.by_province.get(p.id, []):
		forces[d.owner] = int(forces.get(d.owner, 0)) + 1
	var force_parts: Array[String] = []
	for tag: String in forces:
		var country: Country = World.countries.get(tag)
		force_parts.append("%s %d" % [country.display_name() if country else tag, int(forces[tag])])
	_military.text = (tr("TIPMAP_DIVISIONS") + ": " + ", ".join(force_parts)) if not force_parts.is_empty() else tr("TIPMAP_NO_DIVISIONS")
	_hint.text = tr("TIPMAP_LAND_HINT")
	_show_sections()

func _show_water(p: Province) -> void:
	_flag.texture = null
	_title.text = Navy.zone_name(p.id) if p.type == Province.Type.SEA else tr("UI_LAKE")
	_subtitle.text = tr("TIPMAP_NAVAL_REGION") if p.type == Province.Type.SEA else tr("TERRAIN_lake")
	_political.text = tr("TIPMAP_INTERNATIONAL_WATERS") if p.type == Province.Type.SEA else ""
	var land_edges := 0
	for n: int in p.adjacent:
		var neighbor := World.province(n)
		if neighbor and neighbor.is_land():
			land_edges += 1
	_facts.text = "%s: #%d  ·  %s km²\n%s: %d  ·  %s: %d" % [tr("UI_PROVINCE_ID"), p.id,
		UiTheme.format_number(p.area_km2), tr("TIPMAP_CONNECTIONS"), p.adjacent.size(), tr("TIPMAP_COASTS"), land_edges]
	_economy.text = ""
	_military.text = tr("TIPMAP_NAVAL_HINT")
	if p.type == Province.Type.SEA:
		var here: Array[String] = []
		for f in Navy.fleets:
			if f.location == p.id or (f.zone_center > 0 and not f.in_port() and Navy.in_zone(f.zone_center, p.id) and f.mission != Fleet.Mission.PORT):
				here.append("%s (%s, %d)" % [f.name, World.countries[f.owner].display_name(), f.total()])
		var ctl := Navy.sea_control(p.id, World.player_tag)
		var lines: Array[String] = []
		if not here.is_empty():
			lines.append(tr("TIPMAP_FLEETS") + ": " + ", ".join(here.slice(0, 4)))
		if ctl.x + ctl.y > 0.0:
			lines.append(tr("TIPMAP_SEA_CONTROL") % [roundi(ctl.x / (ctl.x + ctl.y) * 100.0)])
		if not lines.is_empty():
			_economy.text = "\n".join(lines)
	_hint.text = tr("TIPMAP_WATER_HINT")
	_show_sections()

## Filo sayacı üzerindeyken
func show_fleet(f: Fleet, screen_pos: Vector2) -> void:
	var owner: Country = World.countries[f.owner]
	_flag.texture = FlagFactory.get_flag(owner)
	_title.text = f.name
	_subtitle.text = owner.display_name()
	var parts: Array[String] = []
	for t: String in Navy.SHIP_TYPES:
		if int(f.ships.get(t, 0)) > 0:
			parts.append("%s %d" % [tr("SHIPS_" + t), int(f.ships[t])])
	_political.text = "  ·  ".join(parts)
	_facts.text = tr("TIPMAP_FLEET_MISSION") % [tr("MISSION_%d" % int(f.mission)), Navy.zone_name(f.zone_center)]
	_economy.text = "%s: %d%%" % [tr("NAVY_ORG"), roundi(f.org * 100.0)]
	_military.text = tr("NAVY_IN_COMBAT") if f.in_combat else (tr("NAVY_RETURNING") if f.returning else "")
	_hint.text = tr("TIPMAP_FLEET_HINT") if f.owner == World.player_tag else ""
	_show_sections()
	_position_card(screen_pos)

## Yollar modunda rota üzerindeyken (ticaret / filo / hava)
func show_route(r: Dictionary, screen_pos: Vector2) -> void:
	for l: Label in [_political, _facts, _economy, _military, _hint]:
		l.text = ""
	match String(r["kind"]):
		"trade":
			var a: Country = World.countries[r["from"]]
			var b: Country = World.countries[r["to"]]
			_flag.texture = FlagFactory.get_flag(a)
			_title.text = tr("ROUTE_TRADE")
			_subtitle.text = "%s → %s" % [a.display_name(), b.display_name()]
			var parts: Array[String] = []
			var res: Dictionary = r["res"]
			for k: String in res:
				parts.append("%s %s" % [tr("RES_" + k), str(roundi(float(res[k])))])
			_political.text = tr("ROUTE_GOODS") % "  ·  ".join(parts)
			_facts.text = tr("ROUTE_DIST_SEA" if bool(r["sea"]) else "ROUTE_DIST_LAND") % roundi(float(r["km"]))
			if bool(r["sea"]):
				_economy.text = tr("ROUTE_CONVOY") % roundi(Economy.convoy_factor(b) * 100.0)
				if int(r["risk"]) > 0:
					_military.text = tr("ROUTE_RISK") % int(r["risk"])
			_hint.text = tr("ROUTE_HINT")
		"fleet":
			var f: Fleet = r["fleet"]
			_flag.texture = FlagFactory.get_flag(World.countries[f.owner])
			_title.text = f.name
			_subtitle.text = tr("ROUTE_FLEET_TO") % Navy.zone_name(f.path[f.path.size() - 1] if not f.path.is_empty() else f.location)
			_facts.text = tr("ROUTE_ETA") % [roundi(float(r["km"])), float(r["eta"])]
			_economy.text = tr("TIPMAP_FLEET_MISSION") % [tr("MISSION_%d" % int(f.mission)), Navy.zone_name(f.zone_center)]
		"air":
			var w: AirWing = r["wing"]
			_flag.texture = FlagFactory.get_flag(World.countries[w.owner])
			_title.text = w.name
			_subtitle.text = tr("ROUTE_AIR") % Air.zone_name(w.zone)
			_facts.text = "%s · %d" % [tr("AIR_MISSION_%d" % int(w.mission)), w.planes]
	_show_sections()
	_position_card(screen_pos)

func _show_sections() -> void:
	for l: Label in [_subtitle, _political, _facts, _economy, _military, _hint]:
		l.visible = l.text != ""

func _position_card(screen_pos: Vector2) -> void:
	reset_size()
	var vp := get_viewport_rect().size
	var pos := screen_pos + Vector2(22, 24)
	pos.x = clampf(pos.x, 8.0, vp.x - maxf(size.x, custom_minimum_size.x) - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - size.y - 8.0)
	position = pos
	visible = true
