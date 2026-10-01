class_name MapTooltip
extends PanelContainer
## Harita üzerindeki bölge için gecikmesiz, karar vermeye yarayan stratejik bilgi kartı.
## Kara bölgesi, deniz bölgesi (ülkelere göre hâkimiyet payı, filolar, nakliye riski), filo, rota ve Ctrl basılıyken ülke
## kartı (lider portresi, ideoloji, ikonlu göstergeler, savaşlar, ulusal durumlar, program). Sayılar iyi/kötü renklenir.

const IDEO_COLORS := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("8a6a3a"), "neutrality": Color("8a8a7a")}
const WIDTH := 440.0
const SEA_ART_DIR := "res://assets/ui/seascapes/"
static var _sea_art_cache := {}

var _flag: TextureRect
var _title: Label
var _subtitle: Label
var _extra: VBoxContainer          ## ülke/deniz kartlarının ikonlu parçaları (her gösterişte yeniden kurulur)
var _political: RichTextLabel
var _facts: RichTextLabel
var _economy: RichTextLabel
var _military: RichTextLabel
var _hint: Label
var _shown_key := ""               ## aynı ülke/deniz kartı yeniden kurulmasın (fare her kıpırdadığında)
var order_eta := ""                 ## tümen seçiliyken: bu bölgeye tahmini varış (kartın altında)
var order_odds: Dictionary = {}     ## tümen seçiliyken düşman bölgesinde: saldırı tahmini (Military.attack_estimate)
var _shown_ms := 0
var _reflow_pending := false

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
	_political = _section(v, 17)                # sahiplik / kısa açıklama: başlığın hemen altında
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 6)
	_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_extra)
	_facts = _section(v, 16)
	_economy = _section(v, 16)
	_military = _section(v, 16)
	_hint = UiTheme.make_label("", 14, UiTheme.ACCENT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = WIDTH
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	v.add_child(_hint)
	visible = false

## Renkli metin bölümü (sayılar _show_sections'ta iyi/kötü renklenir)
func _section(parent: VBoxContainer, font_size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH   # sarmalama genişliği sabit: yerleşimden önce yükseklik binlerce satıra fırlıyordu (dev boş kart)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", UiTheme.fs(font_size))
	l.add_theme_color_override("default_color", UiTheme.TEXT)
	l.add_theme_constant_override("line_separation", 2)
	parent.add_child(l)
	return l

func _clear_extra() -> void:
	for ch in _extra.get_children():
		_extra.remove_child(ch)
		ch.queue_free()

func show_province(pid: int, screen_pos: Vector2) -> void:
	var p := World.province(pid)
	if p == null:
		visible = false
		return
	var key := "p%d:%s:%s" % [pid, order_eta, _odds_key()]
	if key == _shown_key and visible and Time.get_ticks_msec() - _shown_ms < 500:
		_position_card(screen_pos)       # aynı bölge: kart yeniden kurulmaz
		return
	_shown_key = key
	_shown_ms = Time.get_ticks_msec()
	_clear_extra()
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
	var rel_col := UiTheme.GOOD if owner and owner.tag == World.player_tag else UiTheme.TEXT_DIM
	if owner and Diplomacy.are_enemies(World.player_tag, owner.tag):
		relation = tr("TIPMAP_ENEMY")
		rel_col = UiTheme.BAD
	elif owner and owner.tag != World.player_tag and Diplomacy.are_allies(World.player_tag, owner.tag):
		relation = tr("CTRY_ALLY")
		rel_col = UiTheme.GOOD
	_political.text = "%s  ·  %s" % [owner.display_name() if owner else "—", _c(relation, rel_col)]
	if controller and owner and controller.tag != owner.tag:
		_political.text += "\n%s: %s" % [tr("TIPMAP_CONTROLLER"), _c(controller.display_name(), UiTheme.BAD if Diplomacy.are_enemies(World.player_tag, controller.tag) else UiTheme.ACCENT)]

	# kıyı / liman / nehir: sahiplik satırının altında kısa etiketler
	var tags: Array[String] = []
	if p.coastal:
		tags.append(tr("TIPMAP_COASTAL"))
	if p.city and p.city.is_port:
		tags.append(tr("TIPMAP_PORT_CITY"))
	if not p.river_adjacent.is_empty():
		tags.append(tr("TIPMAP_RIVER"))
	if not tags.is_empty():
		_political.text += "\n" + _c("  ·  ".join(tags), UiTheme.TEXT_DIM)
	if p.city and Game.is_key_city(p.city.id):
		_political.text += "\n" + _c(tr("TIPMAP_KEY_CITY") % p.city.victory_points, UiTheme.ACCENT)
	_facts.text = ""
	_economy.text = ""
	_military.text = ""
	_ground_cells(p, st)
	_region_cells(p, st)
	_force_rows(p)
	if owner and owner.tag != World.player_tag:
		_hint.text = tr("TIPMAP_LAND_HINT") + "\n" + tr("CTRY_HOLD_CTRL")
		if order_eta != "":
			_hint.text = order_eta + "\n" + _hint.text
		_show_sections()
		return
	_hint.text = tr("TIPMAP_LAND_HINT")
	if order_eta != "":
		_hint.text = order_eta + "\n" + _hint.text
	_show_sections()

## Arazi ve hava: askerin burada ne yaşayacağı — arazi, hava (çamur / kış), yürüyüş hızı, buraya saldırının cezası, cephe
## genişliği, ikmal; altında nehir / çıkarma cezası ve hava üstünlüğü
func _ground_cells(p: Province, st: StateRegion) -> void:
	var me := World.player_tag
	_heading(tr("TIPMAP_H_GROUND"))
	var g := _grid(3)
	var tinfo: Dictionary = Military.terrain.get(p.terrain, Military.terrain.get("plains", {"move": 1.0, "attack": 0.0, "width": 180}))
	_cell(g, UiTheme.icon_or("tip_terrain", "army"), tr("TIPMAP_TERRAIN"), tr("TERRAIN_" + p.terrain), UiTheme.TEXT)
	var winter := Military.winter_level(p.id)
	var mud := Military.mud_level(p.id)
	var wkey := "TIPMAP_W_CLEAR"
	var wcol := UiTheme.GOOD
	if winter >= 1.0:
		wkey = "TIPMAP_W_HARD_WINTER"
		wcol = UiTheme.BAD
	elif winter > 0.0:
		wkey = "TIPMAP_W_WINTER"
		wcol = Color(0.93, 0.78, 0.4)
	elif mud > 0.0:
		wkey = "TIPMAP_W_MUD"
		wcol = Color(0.93, 0.78, 0.4)
	_cell(g, UiTheme.icon_or("tip_weather", "focus_sov_winter"), tr("TIPMAP_WEATHER"), tr(wkey), wcol)
	# yürüyüş: arazi × altyapı × mevsim (hareketle aynı çarpanlar; yakıt, ikmal ve bütünlük tümene göre)
	var move := float(tinfo["move"]) * (1.0 + st.building_level("infrastructure") * 0.05) * (1.0 - mud * 0.45 - winter * 0.25)
	_cell(g, UiTheme.icon_or("tip_movement", "equipment_motorized_equipment"), tr("TIPMAP_MOVE"), "%d%%" % roundi(move * 100.0),
		_ratio_color(move, 0.95, 0.7))
	var atk := float(tinfo["attack"]) - Military.season_attack_malus(p.id)
	_cell(g, UiTheme.icon_or("tip_attack", "battle"), tr("TIPMAP_ATTACK_IN"), ("%+d%%" % roundi(atk * 100.0)) if absf(atk) > 0.004 else "0%",
		_ratio_color(1.0 + atk, 0.99, 0.8))
	_cell(g, UiTheme.icon_or("tip_frontage", "equipment_infantry_equipment"), tr("TIPMAP_FRONTAGE"), str(int(tinfo["width"])), UiTheme.TEXT)
	var sup_txt := tr("TIPMAP_SUPPLY_PEACE")
	var sup_col := UiTheme.TEXT_DIM
	if Military._supplied.has(me):
		var ok: bool = (Military._supplied[me] as Dictionary).has(p.id)
		sup_txt = tr("TIPMAP_SUPPLY_OK") if ok else tr("TIPMAP_SUPPLY_NO")
		sup_col = UiTheme.GOOD if ok else UiTheme.BAD
	_cell(g, UiTheme.icon("supply"), tr("TIPMAP_SUPPLY"), sup_txt, sup_col)
	if not p.river_adjacent.is_empty():
		_line(tr("TIPMAP_RIVER_NOTE") % absi(roundi(Military.river_attack * 100.0)), UiTheme.TEXT_DIM, 13)
	if p.coastal:
		_line(tr("TIPMAP_SEA_NOTE") % absi(roundi(Military.amphibious_attack * 100.0)), UiTheme.TEXT_DIM, 13)
	if Diplomacy.at_war(me):
		var air := Air.superiority(p.id, me)
		_line(tr("TIPMAP_AIR") % roundi(air * 100.0), _ratio_color(air, 0.55, 0.45), 13)

## Bölge: nüfus, zafer puanı, altyapı, yapı yuvası; yapılar ve kaynaklar ikonlu
func _region_cells(p: Province, st: StateRegion) -> void:
	_heading(tr("TIPMAP_H_REGION"))
	var g := _grid(3)
	_cell(g, UiTheme.icon("manpower"), tr("UI_POPULATION"), UiTheme.format_number(st.population), UiTheme.TEXT)
	if p.city and p.city.victory_points > 0:
		_cell(g, UiTheme.icon("map_capital" if p.city.is_capital else "map_city"), tr("TIPMAP_VICTORY_POINTS"), str(p.city.victory_points), UiTheme.ACCENT)
	if Military.state_fogged(st) or not Economy.SHOW_BUILDINGS:
		return                       # sisteyse keşfedilmeden yalnız şehir; altyapı, yapılar, kaynaklar bilinmez
	var infra := st.building_level("infrastructure")
	var imax := int((Economy.defs.get("infrastructure", {}) as Dictionary).get("max", 5))
	_cell(g, UiTheme.building_icon("infrastructure"), Economy.building_name("infrastructure"), "%d / %d" % [infra, imax], _ratio_color(float(infra) / maxf(imax, 1), 0.6, 0.2))
	_cell(g, UiTheme.icon("construction"), tr("UI_SLOTS"), "%d / %d" % [st.used_slots(), st.building_slots], UiTheme.TEXT)
	var bg: GridContainer = null
	for b: String in ["civilian_factory", "military_factory", "dockyard", "synthetic_refinery", "air_base", "naval_base", "anti_air"]:
		var lv := st.building_level(b)
		if lv <= 0:
			continue
		if bg == null:
			bg = _grid(3)
		_cell(bg, UiTheme.building_icon(b), Economy.building_name(b), str(lv), UiTheme.ACCENT)
	if st.damage >= 0.01:
		_line(tr("TIPMAP_BOMB_DAMAGE") % roundi(st.damage * 100.0), UiTheme.BAD, 14)
	var rg: GridContainer = null
	for res: String in st.resources:
		if int(st.resources[res]) <= 0:
			continue
		if rg == null:
			rg = _grid(3)
		_cell(rg, UiTheme.resource_icon(res), tr("RES_" + res), str(int(st.resources[res])), UiTheme.TEXT)

## Bölgedeki birlikler: ülke başına tümen (eğitimdekiler ayrıca), süren muharebe
func _force_rows(p: Province) -> void:
	var forces: Dictionary = {}
	var training: Dictionary = {}
	# savaş sisi: görünmeyen düşman bölgesinde düşman tümenleri sayılmaz, boş olup olmadığı da söylenmez
	var pc := World.controller_tag(p.id)
	var fog := not Military.is_visible(p.id) and pc != World.player_tag and not Diplomacy.are_allies(pc, World.player_tag)
	for d: Division in Military.by_province.get(p.id, []):
		if Military.hidden(d):
			fog = true
			continue
		forces[d.owner] = int(forces.get(d.owner, 0)) + 1
		if d.training > 0:
			training[d.owner] = int(training.get(d.owner, 0)) + 1
	_heading(tr("TIPMAP_DIVISIONS"))
	if fog:
		_line(tr("TIPMAP_FOG"), UiTheme.TEXT_DIM, 14)
	elif forces.is_empty():
		_line(tr("TIPMAP_NO_DIVISIONS"), UiTheme.TEXT_DIM, 14)
	for tag: String in forces:
		var c: Country = World.countries.get(tag)
		if c == null:
			continue
		var text := "%s  %d" % [c.display_name(), int(forces[tag])]
		if int(training.get(tag, 0)) > 0:
			text += tr("TIPMAP_TRAINING") % int(training[tag])
		_flag_row(c, text, _side_color(tag))
	if Military.battles.has(p.id):
		var b: Dictionary = Military.battles[p.id]
		var ar: float = b.get("att_ratio", 0.5)
		var dr: float = b.get("def_ratio", 0.5)
		var share := ar / maxf(ar + dr, 0.001)
		_line(tr("TIPMAP_BATTLE") % [roundi(share * 100.0), 100 - roundi(share * 100.0)], UiTheme.ACCENT, 14)
	_odds_rows()

func _odds_key() -> String:
	if order_odds.is_empty():
		return ""
	if order_odds.has("empty"):
		return "e"
	if order_odds.has("unknown"):
		return "u"
	return "%d:%d" % [roundi(float(order_odds["ratio"]) * 100.0), roundi(float(order_odds["hours"]))]

## Seçili tümenlerle bu bölgeye saldırı tahmini: karar (umutsuz … ezici), taraflar, önce çözülen tarafın süresi ve
## tahmini en çok değiştiren etkenler (bizim için + iyi, − kötü)
func _odds_rows() -> void:
	if order_odds.is_empty():
		return
	_heading(tr("TIPMAP_ODDS"))
	if order_odds.has("empty"):
		_line(tr("ODDS_EMPTY"), UiTheme.GOOD, 14)
		return
	if order_odds.has("unknown"):
		_line(tr("ODDS_UNKNOWN"), UiTheme.TEXT_DIM, 14)
		return
	var r: float = order_odds["ratio"]
	var lvl := 0 if r < 0.5 else (1 if r < 0.8 else (2 if r < 1.25 else (3 if r < 2.0 else 4)))
	var col := UiTheme.BAD if lvl <= 1 else (Color(0.93, 0.78, 0.4) if lvl == 2 else UiTheme.GOOD)
	var verdict := UiTheme.make_label(tr("ODDS_%d" % lvl), 17, col)
	verdict.add_theme_font_override("font", UiTheme.bold_font())
	verdict.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(verdict)
	_line(tr("ODDS_SIDES") % [int(order_odds["att"]), int(order_odds["def"])], UiTheme.TEXT_DIM, 13)
	var h: float = order_odds["hours"]
	var when: String = tr("ODDS_HOURS") % maxi(1, roundi(h)) if h < 48.0 else tr("ODDS_DAYS") % roundi(h / 24.0)
	_line((tr("ODDS_DEF_BREAKS") if r >= 1.0 else tr("ODDS_ATT_BREAKS")) % when, col, 14)
	for f: Array in (order_odds["factors"] as Array).slice(0, 6):
		var fk: String = f[0]
		var v: float = f[1]
		var label := tr("ODDS_F_" + fk)
		if fk == "terrain":
			label = label % tr("TERRAIN_" + String(order_odds.get("terrain_id", "plains")))
		_line("%s  %s%d%%" % [label, "+" if v > 0.0 else "−", roundi(absf(v) * 100.0)], UiTheme.GOOD if v > 0.0 else UiTheme.BAD, 14)

## Kartta 3 sütunlu ikonlu hücre ızgarası
func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(g)
	return g

func _show_water(p: Province) -> void:
	_flag.texture = null
	_title.text = Navy.zone_name(p.id) if p.type == Province.Type.SEA else tr("UI_LAKE")
	_subtitle.text = tr("TIPMAP_NAVAL_REGION") if p.type == Province.Type.SEA else tr("TERRAIN_lake")
	_political.text = ""
	_economy.text = ""
	_military.text = ""
	var land_edges := 0
	for n: int in p.adjacent:
		var neighbor := World.province(n)
		if neighbor and neighbor.is_land():
			land_edges += 1
	_facts.text = ""
	var seascape := _sea_art(p) if p.type == Province.Type.SEA else null
	if seascape:
		var photo := TextureRect.new()
		photo.texture = seascape
		photo.custom_minimum_size = Vector2(WIDTH, 118)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.clip_contents = true
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_extra.add_child(photo)
	var ports := 0
	for n: int in p.adjacent:
		var q := World.province(n)
		if q and q.city and q.city.is_port:
			ports += 1
	var g := _grid(3)
	var winter := Military.winter_level(p.id)
	_cell(g, UiTheme.icon_or("tip_weather", "focus_sov_winter"), tr("TIPMAP_WEATHER"),
		tr("TIPMAP_W_WINTER_SEA") if winter > 0.0 else tr("TIPMAP_W_CLEAR"), Color(0.93, 0.78, 0.4) if winter > 0.0 else UiTheme.GOOD)
	_cell(g, UiTheme.icon_or("tip_coast", "map_port"), tr("TIPMAP_COASTS"), str(land_edges), UiTheme.TEXT)
	_cell(g, UiTheme.icon("map_port"), tr("TIPMAP_PORTS"), str(ports), UiTheme.TEXT)
	if p.type == Province.Type.SEA and Diplomacy.at_war(World.player_tag):
		var air := Air.superiority(p.id, World.player_tag)
		_line(tr("TIPMAP_AIR") % roundi(air * 100.0), _ratio_color(air, 0.55, 0.45), 13)
	if p.type == Province.Type.SEA:
		_sea_control(p.id)
	_hint.text = tr("TIPMAP_WATER_HINT")
	if order_eta != "":
		_hint.text = order_eta + "\n" + _hint.text
	_show_sections()

## Önce ilgili su bölgesinin özel görseli; yoksa tarihî deniz havzası için ortak görsel.
func _sea_art(p: Province) -> Texture2D:
	var basin := _sea_basin(p.lonlat.x, p.lonlat.y)
	var key := "%s:%d" % [basin, p.id]
	if _sea_art_cache.has(key):
		return _sea_art_cache[key]
	var custom_path := SEA_ART_DIR + "sea_%05d.png" % p.id
	var basin_path := SEA_ART_DIR + basin + ".png"
	var path := custom_path if ResourceLoader.exists(custom_path) else (basin_path if ResourceLoader.exists(basin_path) else "")
	if path == "":
		_sea_art_cache[key] = null
		return null
	# büyük resim arka planda yüklenir (eşzamanlı yükleme ilk üzerine gelişte kareyi ~150 ms donduruyordu); hazır olana
	# dek kart resimsiz, hazır olunca bir sonraki gösterimde
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
		return null
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var tex: Texture2D = ResourceLoader.load_threaded_get(path)
		_sea_art_cache[key] = tex
		return tex
	if st == ResourceLoader.THREAD_LOAD_FAILED:
		_sea_art_cache[key] = null
	return null

static func _sea_basin(lon: float, lat: float) -> String:
	if lat >= 66.0:
		return "arctic"
	if lat <= -48.0:
		return "southern_ocean"
	if lon >= 10.0 and lon <= 31.0 and lat >= 53.0 and lat <= 66.0:
		return "baltic"
	if lon >= -5.0 and lon <= 15.0 and lat >= 50.0 and lat <= 62.0:
		return "north_sea"
	if lon >= 27.0 and lon <= 42.0 and lat >= 40.0 and lat <= 47.0:
		return "black_sea"
	if lon >= -7.0 and lon <= 37.0 and lat >= 30.0 and lat <= 47.0:
		return "mediterranean"
	if lon >= 32.0 and lon <= 44.0 and lat >= 12.0 and lat <= 30.0:
		return "red_sea"
	if lon >= -90.0 and lon <= -58.0 and lat >= 8.0 and lat <= 30.0:
		return "caribbean"
	if lon >= -75.0 and lon <= 25.0:
		return "atlantic"
	if lon >= 25.0 and lon <= 130.0:
		return "indian_ocean"
	return "pacific"

## Deniz hâkimiyeti: bölgede görevli filoların gücüne göre ülke payları (renkli çubuk + satırlar), bizim tarafın payı,
## nakliye riski, bölgedeki filolar
func _sea_control(pid: int) -> void:
	var m: Dictionary = Navy._control_map().get(pid, {})
	var me := World.player_tag
	_heading(tr("SEA_CONTROL_TITLE"))
	var total := 0.0
	for t: String in m:
		total += float(m[t])
	if total <= 0.0:
		_line(tr("SEA_NO_CONTROL"), UiTheme.TEXT_DIM)
	else:
		var tags: Array = m.keys()
		tags.sort_custom(func(x: String, y: String) -> bool: return float(m[x]) > float(m[y]))
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 0)
		bar.custom_minimum_size = Vector2(WIDTH, 12)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_extra.add_child(bar)
		for t: String in tags:
			var seg := ColorRect.new()
			seg.color = World.countries[t].color if World.countries.has(t) else Color.GRAY
			seg.custom_minimum_size = Vector2(maxf(2.0, WIDTH * float(m[t]) / total), 12)
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(seg)
		for t: String in tags.slice(0, 5):
			var c: Country = World.countries.get(t)
			if c == null:
				continue
			_flag_row(c, "%s  %d%%" % [c.display_name(), roundi(float(m[t]) / total * 100.0)], _side_color(t))
		var ctl := Navy.sea_control(pid, me)
		if ctl.x + ctl.y > 0.0:
			var share := roundi(ctl.x / (ctl.x + ctl.y) * 100.0)
			_line(tr("SEA_OUR_SIDE") % [share, 100 - share], UiTheme.GOOD if share >= 50 else UiTheme.BAD)
	var risky := Navy.hostile_sea(pid, me)
	_line(tr("SEA_TRANSPORT_RISK") if risky else tr("SEA_TRANSPORT_SAFE"), UiTheme.BAD if risky else UiTheme.GOOD)
	var here: Array[Fleet] = []
	for f in Navy.fleets:
		if f.location == pid or (f.zone_center > 0 and not f.in_port() and Navy.in_zone(f.zone_center, pid) and f.mission != Fleet.Mission.PORT):
			here.append(f)
	if not here.is_empty():
		_heading(tr("TIPMAP_FLEETS"))
		for f in here.slice(0, 5):
			_flag_row(World.countries[f.owner], "%s  ·  %d %s  ·  %s" % [f.name, f.total(), tr("SEA_SHIPS"), tr("MISSION_%d" % int(f.mission))], _side_color(f.owner))

## Oyuncuya göre taraf rengi: biz/müttefik yeşil, düşman kırmızı, diğerleri düz
func _side_color(tag: String) -> Color:
	var me := World.player_tag
	if tag == me or Diplomacy.are_allies(tag, me):
		return UiTheme.GOOD
	if Diplomacy.are_enemies(tag, me):
		return UiTheme.BAD
	return UiTheme.TEXT

# ------------------------------------------------------------------ kart parçaları
func _heading(text: String) -> void:
	var l := UiTheme.make_label(text.to_upper(), 13, UiTheme.ACCENT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(l)

func _line(text: String, col: Color, size := 15) -> void:
	var l := UiTheme.make_label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(l)

func _flag_row(c: Country, text: String, col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := TextureRect.new()
	f.texture = FlagFactory.get_flag(c)
	f.custom_minimum_size = Vector2(24, 16)
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(f)
	var l := UiTheme.make_label(text, 15, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	_extra.add_child(hb)

## İkonlu gösterge hücresi: ikon + küçük başlık + renkli değer
func _cell(grid: GridContainer, icon: Texture2D, caption: String, value: String, col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		var ic := UiTheme.icon_texture(icon, 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var cl := UiTheme.make_label(caption, 11, UiTheme.TEXT_DIM)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cl)
	var vl := UiTheme.make_label(value, 16, col)
	vl.add_theme_font_override("font", UiTheme.bold_font())
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vl)
	grid.add_child(hb)

static func _ratio_color(v: float, good: float, bad: float) -> Color:
	return UiTheme.GOOD if v >= good else (UiTheme.BAD if v < bad else Color(0.93, 0.78, 0.4))

## Metinde renk işareti: colorize'dan sağ çıkar (renk kodundaki rakamlar harfe çevrilir, sayı sanılmaz),
## _show_sections'ta _decode ile renge döner
static func _c(text: String, col: Color) -> String:
	var enc := ""
	for ch in col.to_html(false):
		enc += char(ch.unicode_at(0) + 65) if ch >= "0" and ch <= "9" else ch
	return "\u0001" + enc + "\u0002" + text + "\u0003"

static func _decode(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == "\u0001" and i + 7 < s.length():
			var hx := ""
			for k in 6:
				var e := s[i + 1 + k]
				hx += char(e.unicode_at(0) - 65) if e >= "q" and e <= "z" else e
			out += "[color=#" + hx + "]"
			i += 8
			continue
		out += "[/color]" if ch == "\u0003" else ch
		i += 1
	return out

## Ctrl basılıyken bir ülkenin üzerinde: ülkenin genel durumu (eyalet paneli gibi ikonlu). Ctrl + tık o ülkenin
## siyaset ekranını açar (birlik seçiliyken Ctrl + tık hareket emridir: can_open false).
func show_country(tag: String, screen_pos: Vector2, can_open := true) -> void:
	var c: Country = World.countries.get(tag)
	if c == null:
		visible = false
		return
	var key := "c%s%d" % [tag, int(can_open)]
	if key == _shown_key and visible and Time.get_ticks_msec() - _shown_ms < 1000:
		_position_card(screen_pos)
		return
	_shown_key = key
	_shown_ms = Time.get_ticks_msec()
	_clear_extra()
	var por := UiTheme.portrait(c)
	_flag.texture = FlagFactory.get_flag(c)
	_title.text = c.display_name()
	_subtitle.text = ("%s  ·  %s" % [tr("IDEOLOGY_" + c.ideology), c.party_name()]) if c.party_name() != "" else tr("IDEOLOGY_" + c.ideology)
	var me := World.player_tag
	# lider: portre + ad + ilişki + ittifak + ideoloji çubuğu
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(head)
	var frame := PanelContainer.new()
	frame.theme_type_variation = "SlotGold"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(frame)
	var pt := TextureRect.new()
	pt.texture = por if por else FlagFactory.get_flag(c)
	pt.custom_minimum_size = Vector2(64, 80) if por else Vector2(84, 56)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if por else TextureRect.STRETCH_SCALE
	pt.clip_contents = true
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pt)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(info)
	var ln := UiTheme.make_label(c.leader_name(), 18, UiTheme.TEXT)
	ln.add_theme_font_override("font", UiTheme.bold_font())
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(ln)
	var rel := tr("CTRY_US")
	var rel_col := UiTheme.ACCENT
	if tag != me:
		if Diplomacy.are_enemies(me, tag):
			rel = tr("CTRY_ENEMY")
			rel_col = UiTheme.BAD
		elif Diplomacy.are_allies(me, tag):
			rel = tr("CTRY_ALLY")
			rel_col = UiTheme.GOOD
		else:
			rel = tr("CTRY_NEUTRAL")
			rel_col = UiTheme.TEXT_DIM
	var rl := UiTheme.make_label(rel, 15, rel_col)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(rl)
	if c.faction != "":
		var fl := UiTheme.make_label(Politics.faction_display(c.faction), 14, UiTheme.ACCENT)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(fl)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.custom_minimum_size.y = 8
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(bar)
	for i: String in IDEO_COLORS:
		var v := float(c.popularity.get(i, 0.0))
		if v <= 0.0:
			continue
		var seg := ColorRect.new()
		seg.color = IDEO_COLORS[i]
		seg.custom_minimum_size = Vector2(maxf(2.0, 290.0 * v), 8)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(seg)
	var pop := UiTheme.make_label(tr("CTRY_POPULARITY") % [tr("IDEOLOGY_" + c.ideology), roundi(float(c.popularity.get(c.ideology, 0.0)) * 100)], 12, UiTheme.TEXT_DIM)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(pop)
	# ikonlu göstergeler (iyi yeşil, kötü kırmızı; güçler bizimkine göre)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.add_child(g)
	var stab := Politics.stability(c)
	var ws := Politics.war_support(c)
	_cell(g, UiTheme.icon("stability"), tr("POL_STAB_SHORT"), "%d%%" % roundi(stab * 100), _ratio_color(stab, 0.5, 0.3))
	_cell(g, UiTheme.icon("war_support"), tr("POL_WS_SHORT"), "%d%%" % roundi(ws * 100), _ratio_color(ws, 0.5, 0.3))
	_cell(g, UiTheme.icon("political_power"), tr("POL_PP_SHORT"), "%d" % int(c.political_power), UiTheme.TEXT)
	_cell(g, UiTheme.icon("manpower"), tr("UI_POPULATION"), UiTheme.format_number(c.population), UiTheme.TEXT)
	var me_c := World.player()
	_cell(g, UiTheme.building_icon("civilian_factory"), tr("CTRY_CIV"), "%d" % Economy.count(c, "civilian_factory"),
		_versus(Economy.count(c, "civilian_factory"), Economy.count(me_c, "civilian_factory") if me_c else 0, tag == me))
	_cell(g, UiTheme.building_icon("military_factory"), tr("CTRY_MIL"), "%d" % Economy.count(c, "military_factory"),
		_versus(Economy.count(c, "military_factory"), Economy.count(me_c, "military_factory") if me_c else 0, tag == me))
	var ships := 0
	var my_ships := 0
	for t: String in Navy.SHIP_TYPES:
		ships += Navy.ship_count(tag, t)
		my_ships += Navy.ship_count(me, t)
	_cell(g, UiTheme.icon("army"), tr("CTRY_DIVS"), "%d" % Military.country_divisions(tag).size(),
		_versus(Military.country_divisions(tag).size(), Military.country_divisions(me).size(), tag == me))
	_cell(g, UiTheme.icon("navy"), tr("CTRY_SHIPS"), "%d" % ships, _versus(ships, my_ships, tag == me))
	_cell(g, UiTheme.icon("air"), tr("CTRY_PLANES"), "%d" % Air.planes(tag), _versus(Air.planes(tag), Air.planes(me), tag == me))
	# savaşlar ve gerekçeler
	var enemies := Diplomacy.enemies_of(tag)
	if not enemies.is_empty():
		var names: Array[String] = []
		for t: String in enemies.slice(0, 4):
			names.append(World.countries[t].display_name() if World.countries.has(t) else t)
		_line(tr("CTRY_AT_WAR") % (", ".join(names) + (" +%d" % (enemies.size() - 4) if enemies.size() > 4 else "")), UiTheme.BAD)
	else:
		_line(tr("CTRY_AT_PEACE"), UiTheme.GOOD)
	if not c.war_goals.is_empty():
		var gl: Array[String] = []
		for t: String in c.war_goals:
			gl.append(World.countries[t].display_name() if World.countries.has(t) else t)
		_line(tr("CTRY_GOALS_ON") % ", ".join(gl.slice(0, 4)), UiTheme.BAD if me in c.war_goals else Color(0.93, 0.78, 0.4))
	# ulusal durumlar (ikonlar; olumsuz olanlar kırmızı çerçeve)
	if not c.spirits.is_empty():
		var sp := HFlowContainer.new()
		sp.add_theme_constant_override("h_separation", 4)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_extra.add_child(sp)
		for id: String in c.spirits.slice(0, 9):
			var def: Dictionary = Politics.spirits.get(id, Politics.decisions.get(id, {}))
			var negative := false
			for k: String in def.get("mods", {}):
				if float(def["mods"][k]) < 0.0 and k != "consumer_goods_mod":
					negative = true
			var tex := UiTheme.spirit_icon(id)
			var s := PanelLayout.slot(tex if tex else UiTheme.icon("stability"), 34, "", "SlotBad" if negative else "Slot")
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sp.add_child(s)
	# sürdürülen program
	if c.focus_current != "":
		var fo := Politics.focus_def(c, c.focus_current)
		if not fo.is_empty():
			var fr := HBoxContainer.new()
			fr.add_theme_constant_override("separation", 8)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_extra.add_child(fr)
			var ftex := UiTheme.focus_icon(c.focus_current)
			var fi := UiTheme.icon_texture(ftex if ftex else UiTheme.icon("politics"), 26)
			fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.add_child(fi)
			var fv := VBoxContainer.new()
			fv.add_theme_constant_override("separation", 1)
			fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.add_child(fv)
			var days := float(fo["days"])
			var fl2 := UiTheme.make_label(tr("CTRY_FOCUS") % [Politics.loc(fo["name"]), maxi(0, int(days - c.focus_progress))], 14, UiTheme.TEXT)
			fl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fv.add_child(fl2)
			fv.add_child(PanelLayout.bar(clampf(c.focus_progress / maxf(days, 1.0), 0.0, 1.0), UiTheme.ACCENT, 300.0, 4.0))
	_political.text = ""
	_facts.text = ""
	_economy.text = ""
	_military.text = ""
	_hint.text = tr("CTRY_HINT") if can_open else tr("CTRY_HINT_ORDER")
	_show_sections()
	_position_card(screen_pos)

## Başka bir ülkenin gücü bizimkine göre: bizden belirgin güçlüyse kırmızı, zayıfsa yeşil (kendi ülkemizde düz)
static func _versus(theirs: int, ours: int, same: bool) -> Color:
	if same or ours <= 0 and theirs <= 0:
		return UiTheme.TEXT
	if float(theirs) > float(ours) * 1.3:
		return UiTheme.BAD
	if float(theirs) * 1.3 < float(ours):
		return UiTheme.GOOD
	return UiTheme.TEXT

## Filo sayacı üzerindeyken
func show_fleet(f: Fleet, screen_pos: Vector2) -> void:
	_shown_key = ""
	_clear_extra()
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

## Haritada yapı rozetinin üstündeyken: yapının adı, eyaleti, seviyesi, süren inşaatı ve ülkedeki toplamı
func show_building(sid: int, building: String, screen_pos: Vector2) -> void:
	_shown_key = ""
	_clear_extra()
	var st: StateRegion = World.states[sid]
	var owner: Country = World.countries.get(st.owner)
	_flag.texture = FlagFactory.get_flag(owner) if owner else null
	_title.text = Economy.building_name(building)
	_subtitle.text = "%s · %s" % [st.display_name(), owner.display_name()] if owner else st.display_name()
	_political.text = tr("BDESC_" + building)
	var mx := int((Economy.defs.get(building, {}) as Dictionary).get("max", 0))
	_facts.text = tr("TIPMAP_BUILD_LEVEL") % [st.building_level(building), mx]
	var queued := 0
	var first: ConstructionProject = null
	if owner:
		for pr: ConstructionProject in owner.construction_queue:
			if pr.state_id == sid and pr.building == building:
				queued += 1
				if first == null:
					first = pr
	_economy.text = ""
	if first:
		_economy.text = tr("TIPMAP_BUILD_QUEUE") % [queued, roundi(first.fraction() * 100.0)]
		if first.days_left() >= 0:
			_economy.text += tr("TIPMAP_BUILD_DAYS") % first.days_left()
	_military.text = ""
	if building == "air_base":
		var wings := 0
		for w: AirWing in Air.wings:
			if w.base == sid:
				wings += 1
		if wings > 0:
			_military.text = tr("TIPMAP_BUILD_WINGS") % wings
	elif owner:
		_military.text = tr("TIPMAP_BUILD_TOTAL") % [owner.display_name(), Economy.count(owner, building)]
	_hint.text = tr("TIPMAP_BUILD_HINT") if st.owner == World.player_tag else ""
	_show_sections()
	_position_card(screen_pos)

## Yollar modunda rota üzerindeyken (ticaret / filo / hava)
func show_route(r: Dictionary, screen_pos: Vector2) -> void:
	_shown_key = ""
	_clear_extra()
	for l: Control in [_political, _facts, _economy, _military, _hint]:
		l.set("text", "")
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
	for l: RichTextLabel in [_political, _facts, _economy, _military]:
		if l.text != "":
			l.text = _decode(UiTheme.colorize(l.text))
		l.visible = l.text != ""
	for l: Label in [_subtitle, _hint]:
		l.visible = l.text != ""
	_extra.visible = _extra.get_child_count() > 0

func _position_card(screen_pos: Vector2) -> void:
	reset_size()
	var vp := get_viewport_rect().size
	var pos := screen_pos + Vector2(22, 24)
	pos.x = clampf(pos.x, 8.0, vp.x - maxf(size.x, custom_minimum_size.x) - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - size.y - 8.0)
	position = pos
	visible = true
	if not _reflow_pending:
		# yeni eklenen parçaların boyu bir kare sonra kesinleşir: kart ekrandan taşmasın diye yeniden yerleştir
		_reflow_pending = true
		(func() -> void:
			_reflow_pending = false
			if visible:
				reset_size()
				position.y = clampf(position.y, 8.0, get_viewport_rect().size.y - size.y - 8.0)
				position.x = clampf(position.x, 8.0, get_viewport_rect().size.x - size.x - 8.0)).call_deferred()
