class_name UiTheme
extends RefCounted
## Oyunun görsel dili: koyu çelik paneller, pirinç kenarlıklar, parşömen tonlu yazı.

const PANEL_BG := Color(0.075, 0.085, 0.082, 0.95)
const PANEL_BG_LIGHT := Color(0.13, 0.145, 0.135, 0.97)
const BORDER := Color("8c7a4b")
const BORDER_DIM := Color("4a4332")
const TEXT := Color("e8dfc8")
const TEXT_DIM := Color("a39a84")
const ACCENT := Color("e0b85e")
const GOOD := Color("93cf7e")
const BAD := Color("e0674f")

static var _theme: Theme
static var _title_font: Font
static var _bold_font: Font
static var _painted_sheet_cache: Dictionary = {}
static var _painted_icon_cache: Dictionary = {}

## El boyamasi ikon atlaslari. Her sayfa 3x2 adet 512px hucreden olusur.
## Eski parlak/oyuncak gorunumlu 3B ikonlar yalnizca son care olarak tutulur.
const PAINTED_ATLAS: Dictionary = {
	"building_civilian_factory": ["content_a", 0],
	"building_military_factory": ["content_a", 1],
	"building_dockyard": ["content_a", 2],
	"building_infrastructure": ["content_a", 3],
	"building_air_base": ["content_a", 4],
	"building_naval_base": ["content_a", 5],
	"building_anti_air": ["content_b", 0],
	"building_synthetic_refinery": ["content_b", 1],
	"resource_oil": ["content_b", 2],
	"resource_steel": ["content_b", 3],
	"resource_aluminium": ["content_b", 4],
	"resource_tungsten": ["content_b", 5],
	"resource_chromium": ["content_c", 0],
	"resource_rubber": ["content_c", 1],
	"equipment_infantry_equipment": ["content_c", 2],
	"equipment_support_equipment": ["content_c", 3],
	"equipment_artillery_equipment": ["content_c", 4],
	"equipment_anti_tank_equipment": ["content_c", 5],
	"equipment_anti_air_equipment": ["content_d", 0],
	"equipment_motorized_equipment": ["content_d", 1],
	"equipment_light_tank_equipment": ["content_d", 2],
	"equipment_medium_tank_equipment": ["content_d", 3],
	"equipment_fighter_equipment": ["content_d", 4],
	"equipment_cas_equipment": ["content_d", 5],
	"equipment_tactical_bomber_equipment": ["content_e", 0],
	"equipment_convoy": ["content_e", 1],
	"equipment_destroyer": ["content_e", 2],
	"equipment_submarine": ["content_e", 3],
	"equipment_cruiser": ["content_e", 4],
	"equipment_battleship": ["content_e", 5],
	"focus_tur_kemalism": ["turkey_a", 0],
	"focus_tur_montreux": ["turkey_a", 1],
	"focus_tur_five_year": ["turkey_a", 2],
	"focus_tur_karabuk": ["turkey_a", 3],
	"focus_tur_sumerbank": ["turkey_a", 4],
	"focus_tur_railways": ["turkey_a", 5],
	"focus_tur_second_plan": ["turkey_b", 0],
	"focus_tur_village": ["turkey_b", 1],
	"focus_tur_nuri": ["turkey_b", 2],
	"focus_tur_army": ["turkey_b", 3],
	"focus_tur_thrace": ["turkey_b", 4],
	"focus_tur_hatay": ["turkey_b", 5],
	"focus_tur_balkan": ["turkey_c", 0],
	"focus_tur_saadabad": ["turkey_c", 1],
	"focus_tur_neutral": ["turkey_c", 2],
	"focus_tur_allies": ["turkey_c", 3],
	"focus_tur_axis": ["turkey_c", 4],
	"focus_tur_mosul": ["turkey_c", 5],
	"focus_tur_aegean": ["turkey_d", 0],
	"focus_g_industry": ["turkey_d", 1],
	"focus_g_construction": ["turkey_d", 2],
	"focus_g_research": ["turkey_d", 3],
	"focus_g_arms": ["turkey_d", 4],
	"focus_g_infra": ["turkey_d", 5],
	"focus_g_army": ["turkey_e", 0],
	"focus_g_doctrine": ["turkey_e", 1],
	"focus_g_equipment": ["turkey_e", 2],
	"focus_g_air": ["turkey_e", 3],
	"focus_g_air2": ["turkey_e", 4],
	"focus_g_navy": ["turkey_e", 5],
	"focus_g_politics": ["turkey_f", 0],
	"focus_g_unity": ["turkey_f", 1],
	"focus_g_propaganda": ["turkey_f", 2],
	"spirit_kemalist_reforms": ["turkey_f", 3],
	"spirit_armed_neutrality": ["turkey_f", 4],
	"spirit_village_institutes": ["turkey_f", 5],
	"tech_infantry_weapons_1": ["tech_a", 0],
	"tech_infantry_weapons_2": ["tech_a", 1],
	"tech_infantry_weapons_3": ["tech_a", 2],
	"tech_support_weapons": ["tech_a", 3],
	"tech_artillery_1": ["tech_a", 4],
	"tech_artillery_2": ["tech_a", 5],
	"tech_artillery_3": ["tech_b", 0],
	"tech_anti_tank_1": ["tech_b", 1],
	"tech_motorization": ["tech_b", 2],
	"tech_light_tank_2": ["tech_b", 3],
	"tech_medium_tank_1": ["tech_b", 4],
	"tech_medium_tank_2": ["tech_b", 5],
	"tech_fighter_1": ["tech_c", 0],
	"tech_fighter_2": ["tech_c", 1],
	"tech_cas_1": ["tech_c", 2],
	"tech_bomber_1": ["tech_c", 3],
	"tech_destroyer_1": ["tech_c", 4],
	"tech_submarine_1": ["tech_c", 5],
	"tech_cruiser_1": ["tech_d", 0],
	"tech_battleship_1": ["tech_d", 1],
	"tech_industry_1": ["tech_d", 2],
	"tech_industry_2": ["tech_d", 3],
	"tech_industry_3": ["tech_d", 4],
	"tech_construction_1": ["tech_d", 5],
	"tech_construction_2": ["tech_e", 0],
	"tech_synthetic_oil": ["tech_e", 1],
	"tech_radio": ["tech_e", 2],
	"tech_radar_1": ["tech_e", 3],
	"tech_computing_1": ["tech_e", 4],
	"tech_doctrine_1": ["tech_e", 5],
	"tech_doctrine_2": ["tech_f", 0],
	"tech_doctrine_3": ["tech_f", 1],
	"tech_doctrine_4": ["tech_f", 2],
	"political_power": ["tech_f", 3],
	"stability": ["tech_f", 4],
	"war_support": ["tech_f", 5],
	"advisor_air_chief": ["politics_a", 0],
	"advisor_armaments_organizer": ["politics_a", 1],
	"advisor_army_chief": ["politics_a", 2],
	"advisor_captain_of_industry": ["politics_a", 3],
	"advisor_navy_chief": ["politics_a", 4],
	"advisor_propaganda_minister": ["politics_a", 5],
	"advisor_research_director": ["politics_b", 0],
	"advisor_silent_workhorse": ["politics_b", 1],
	"decision_emergency_industry": ["politics_b", 2],
	"decision_propaganda_campaign": ["politics_b", 3],
	"decision_war_bonds": ["politics_b", 4],
	"event_access_request": ["politics_b", 5],
	"event_anschluss": ["politics_c", 0],
	"event_call_to_arms": ["politics_c", 1],
	"event_faction_invite": ["politics_c", 2],
	"event_hatay_question": ["politics_c", 3],
	"event_news_war": ["politics_c", 4],
	"event_sudeten": ["politics_c", 5],
	"law_civilian_economy": ["politics_d", 0],
	"law_early_mobilization": ["politics_d", 1],
	"law_partial_mobilization": ["politics_d", 2],
	"law_war_economy": ["politics_d", 3],
	"law_total_mobilization": ["politics_d", 4],
	"law_disarmed_nation": ["politics_d", 5],
	"law_volunteer_only": ["politics_e", 0],
	"law_limited_conscription": ["politics_e", 1],
	"law_extensive_conscription": ["politics_e", 2],
	"law_service_by_requirement": ["politics_e", 3],
	"law_free_trade": ["politics_e", 4],
	"law_export_focus": ["politics_e", 5],
	"law_limited_exports": ["politics_f", 0],
	"law_closed_economy": ["politics_f", 1],
	"spirit_british_empire": ["politics_f", 2],
	"spirit_fascist_state": ["politics_f", 3],
	"spirit_five_year_plan": ["politics_f", 4],
	"spirit_great_purge": ["politics_f", 5],
	"spirit_industrial_drive": ["politics_g", 0],
	"spirit_maginot_mentality": ["politics_g", 1],
	"spirit_military_modernization": ["politics_g", 2],
	"spirit_national_unity": ["politics_g", 3],
	"spirit_rearmament": ["politics_g", 4],
	"spirit_spanish_civil_war": ["politics_g", 5],
	"spirit_war_propaganda": ["politics_h", 0],
	"event_white_peace": ["politics_h", 1],
	"focus_chi_army": ["focus_a", 0],
	"focus_chi_industry": ["focus_a", 1],
	"focus_chi_united_front": ["focus_a", 2],
	"focus_eng_guarantee": ["focus_a", 3],
	"focus_eng_navy": ["focus_a", 4],
	"focus_eng_radar": ["focus_a", 5],
	"focus_eng_rearm": ["focus_b", 0],
	"focus_fra_guarantee": ["focus_b", 1],
	"focus_fra_maginot": ["focus_b", 2],
	"focus_fra_mobilize": ["focus_b", 3],
	"focus_ger_anschluss": ["focus_b", 4],
	"focus_ger_balkans": ["focus_b", 5],
	"focus_ger_barbarossa": ["focus_c", 0],
	"focus_ger_bohemia": ["focus_c", 1],
	"focus_ger_danzig": ["focus_c", 2],
	"focus_ger_denmark": ["focus_c", 3],
	"focus_ger_four_year": ["focus_c", 4],
	"focus_ger_molotov": ["focus_c", 5],
	"focus_ger_pact_steel": ["focus_d", 0],
	"focus_ger_rhineland": ["focus_d", 1],
	"focus_ger_sudeten": ["focus_d", 2],
	"focus_ger_west": ["focus_d", 3],
	"focus_ita_albania": ["focus_d", 4],
	"focus_ita_greece": ["focus_d", 5],
	"focus_ita_mare": ["focus_e", 0],
	"focus_ita_war": ["focus_e", 1],
	"focus_jap_army": ["focus_e", 2],
	"focus_jap_manchuria": ["focus_e", 3],
	"focus_jap_marco_polo": ["focus_e", 4],
	"focus_jap_navy": ["focus_e", 5],
	"focus_jap_strike_south": ["focus_f", 0],
	"focus_jap_tripartite": ["focus_f", 1],
	"focus_sov_baltic": ["focus_f", 2],
	"focus_sov_defense": ["focus_f", 3],
	"focus_sov_plan": ["focus_f", 4],
	"focus_sov_poland": ["focus_f", 5],
	"focus_sov_purge": ["focus_g", 0],
	"focus_sov_winter": ["focus_g", 1],
	"focus_usa_arsenal": ["focus_g", 2],
	"focus_usa_new_deal": ["focus_g", 3],
	"focus_usa_rearm": ["focus_g", 4],
	"focus_usa_two_ocean": ["focus_g", 5],
	"air": ["navigation_a", 0],
	"army": ["navigation_a", 1],
	"construction": ["navigation_a", 2],
	"diplomacy": ["navigation_a", 3],
	"factory": ["navigation_a", 4],
	"manpower": ["navigation_a", 5],
	"military_factory": ["navigation_b", 0],
	"navy": ["navigation_b", 1],
	"politics": ["navigation_b", 2],
	"production": ["navigation_b", 3],
	"research": ["navigation_b", 4],
	"trade": ["navigation_b", 5],
}

## Ikincil icerik ayni sanatsal dilde, anlamca en yakin ozgun illüstrasyonu kullanir.
## Boylece arastirma, yasa, danisman ve olay ekranlarinda eski 3B rozetler gorunmez.
const PAINTED_ALIASES: Dictionary = {
	"political_power": "focus_g_politics", "politics": "focus_g_politics",
	"stability": "focus_g_unity", "war_support": "focus_g_propaganda",
	"manpower": "focus_g_army", "research": "focus_g_research",
	"construction": "focus_g_construction", "production": "focus_g_industry",
	"trade": "resource_steel", "factory": "building_civilian_factory",
	"military_factory": "building_military_factory", "army": "focus_g_army",
	"air": "focus_g_air", "navy": "focus_g_navy", "diplomacy": "focus_tur_balkan",

	"advisor_air_chief": "focus_g_air", "advisor_armaments_organizer": "focus_g_arms",
	"advisor_army_chief": "focus_g_army", "advisor_captain_of_industry": "focus_g_industry",
	"advisor_navy_chief": "focus_g_navy", "advisor_propaganda_minister": "focus_g_propaganda",
	"advisor_research_director": "focus_g_research", "advisor_silent_workhorse": "focus_g_politics",
	"decision_emergency_industry": "focus_g_industry", "decision_propaganda_campaign": "focus_g_propaganda",
	"decision_war_bonds": "focus_g_arms",

	"law_civilian_economy": "focus_g_industry", "law_early_mobilization": "focus_g_arms",
	"law_partial_mobilization": "focus_g_arms", "law_war_economy": "focus_g_industry",
	"law_total_mobilization": "focus_g_arms", "law_disarmed_nation": "spirit_armed_neutrality",
	"law_volunteer_only": "focus_g_army", "law_limited_conscription": "focus_g_army",
	"law_extensive_conscription": "focus_g_army", "law_service_by_requirement": "focus_g_army",
	"law_free_trade": "resource_steel", "law_export_focus": "resource_oil",
	"law_limited_exports": "focus_g_industry", "law_closed_economy": "focus_tur_neutral",

	"event_access_request": "focus_tur_balkan", "event_anschluss": "focus_tur_axis",
	"event_call_to_arms": "focus_g_army", "event_faction_invite": "focus_tur_allies",
	"event_hatay_question": "focus_tur_hatay", "event_news_war": "focus_g_propaganda",
	"event_sudeten": "focus_tur_thrace", "event_white_peace": "spirit_armed_neutrality",

	"spirit_british_empire": "focus_g_navy", "spirit_fascist_state": "focus_tur_axis",
	"spirit_five_year_plan": "focus_tur_five_year", "spirit_great_purge": "focus_g_army",
	"spirit_industrial_drive": "focus_g_industry", "spirit_maginot_mentality": "focus_tur_thrace",
	"spirit_military_modernization": "focus_g_equipment", "spirit_national_unity": "focus_g_unity",
	"spirit_rearmament": "focus_g_arms", "spirit_spanish_civil_war": "focus_g_army",
	"spirit_war_propaganda": "focus_g_propaganda",

	"tech_anti_tank_1": "equipment_anti_tank_equipment",
	"tech_artillery_1": "equipment_artillery_equipment", "tech_artillery_2": "equipment_artillery_equipment",
	"tech_artillery_3": "equipment_artillery_equipment", "tech_battleship_1": "equipment_battleship",
	"tech_bomber_1": "equipment_tactical_bomber_equipment", "tech_cas_1": "equipment_cas_equipment",
	"tech_computing_1": "focus_g_research", "tech_construction_1": "focus_g_construction",
	"tech_construction_2": "focus_g_infra", "tech_cruiser_1": "equipment_cruiser",
	"tech_destroyer_1": "equipment_destroyer", "tech_doctrine_1": "focus_g_doctrine",
	"tech_doctrine_2": "focus_g_doctrine", "tech_doctrine_3": "focus_g_doctrine",
	"tech_doctrine_4": "focus_g_doctrine", "tech_fighter_1": "equipment_fighter_equipment",
	"tech_fighter_2": "focus_g_air2", "tech_industry_1": "building_civilian_factory",
	"tech_industry_2": "building_military_factory", "tech_industry_3": "focus_g_industry",
	"tech_infantry_weapons_1": "equipment_infantry_equipment",
	"tech_infantry_weapons_2": "equipment_support_equipment",
	"tech_infantry_weapons_3": "focus_g_equipment", "tech_light_tank_2": "equipment_light_tank_equipment",
	"tech_medium_tank_1": "equipment_medium_tank_equipment", "tech_medium_tank_2": "focus_g_arms",
	"tech_motorization": "equipment_motorized_equipment", "tech_radar_1": "building_anti_air",
	"tech_radio": "focus_g_research", "tech_submarine_1": "equipment_submarine",
	"tech_support_weapons": "equipment_support_equipment", "tech_synthetic_oil": "building_synthetic_refinery",

	"focus_chi_army": "focus_g_army", "focus_chi_industry": "focus_g_industry",
	"focus_chi_united_front": "focus_tur_balkan", "focus_eng_guarantee": "focus_tur_allies",
	"focus_eng_navy": "focus_g_navy", "focus_eng_radar": "focus_g_research",
	"focus_eng_rearm": "focus_g_arms", "focus_fra_guarantee": "focus_tur_allies",
	"focus_fra_maginot": "focus_tur_thrace", "focus_fra_mobilize": "focus_g_army",
	"focus_ger_anschluss": "focus_tur_axis", "focus_ger_balkans": "focus_tur_balkan",
	"focus_ger_barbarossa": "focus_g_army", "focus_ger_bohemia": "focus_tur_thrace",
	"focus_ger_danzig": "focus_tur_mosul", "focus_ger_denmark": "focus_tur_aegean",
	"focus_ger_four_year": "focus_tur_five_year", "focus_ger_molotov": "focus_tur_saadabad",
	"focus_ger_pact_steel": "focus_tur_axis", "focus_ger_rhineland": "focus_tur_thrace",
	"focus_ger_sudeten": "focus_tur_hatay", "focus_ger_west": "focus_g_army",
	"focus_ita_albania": "focus_tur_aegean", "focus_ita_greece": "focus_tur_aegean",
	"focus_ita_mare": "focus_g_navy", "focus_ita_war": "focus_g_army",
	"focus_jap_army": "focus_g_army", "focus_jap_manchuria": "focus_tur_mosul",
	"focus_jap_marco_polo": "focus_g_army", "focus_jap_navy": "focus_g_navy",
	"focus_jap_strike_south": "focus_g_navy", "focus_jap_tripartite": "focus_tur_axis",
	"focus_sov_baltic": "focus_tur_aegean", "focus_sov_defense": "focus_tur_thrace",
	"focus_sov_plan": "focus_tur_five_year", "focus_sov_poland": "focus_g_army",
	"focus_sov_purge": "focus_g_politics", "focus_sov_winter": "focus_g_army",
	"focus_usa_arsenal": "focus_g_arms", "focus_usa_new_deal": "focus_g_politics",
	"focus_usa_rearm": "focus_g_equipment", "focus_usa_two_ocean": "focus_g_navy",
}

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func title_font() -> Font:
	if _title_font == null:
		var v := FontVariation.new()
		v.base_font = load("res://assets/fonts/CinzelVariable.ttf")
		v.variation_opentype = {"wght": 700}
		_title_font = v
	return _title_font

static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	return _bold_font

static func panel_style(bg: Color = PANEL_BG, border: Color = BORDER, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb

## 9-dilim dokulu stil (assets/ui/<name>.png)
static func textured(name: String, margin: int = 12, content: int = 10) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/%s.png" % name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	return sb

static func icon(name: String) -> Texture2D:
	var painted_name: String = name if PAINTED_ATLAS.has(name) else PAINTED_ALIASES.get(name, name)
	if PAINTED_ATLAS.has(painted_name):
		return _painted_icon(painted_name)
	var vector_path := "res://assets/ui/icons/%s.svg" % name
	if ResourceLoader.exists(vector_path):
		return load(vector_path)
	var hd_path := "res://assets/ui/icons_hd/%s.png" % name
	return load(hd_path) if ResourceLoader.exists(hd_path) else null

static func _painted_icon(name: String) -> Texture2D:
	if _painted_icon_cache.has(name):
		return _painted_icon_cache[name]
	var spec: Array = PAINTED_ATLAS[name]
	var sheet_name: String = spec[0]
	var cell: int = spec[1]
	if not _painted_sheet_cache.has(sheet_name):
		_painted_sheet_cache[sheet_name] = load("res://assets/ui/icon_atlases/%s.png" % sheet_name)
	var atlas := AtlasTexture.new()
	atlas.atlas = _painted_sheet_cache[sheet_name]
	atlas.region = Rect2((cell % 3) * 512, floori(float(cell) / 3.0) * 512, 512, 512)
	_painted_icon_cache[name] = atlas
	return atlas

static func building_icon(building: String) -> Texture2D:
	return icon("building_" + building)

static func resource_icon(resource: String) -> Texture2D:
	return icon("resource_" + resource)

static func equipment_icon(equipment: String) -> Texture2D:
	return icon("equipment_" + equipment)

static func focus_icon(focus: String) -> Texture2D:
	return icon("focus_" + focus)

static func technology_icon(technology: String) -> Texture2D:
	return icon("tech_" + technology)

static func spirit_icon(spirit: String) -> Texture2D:
	return icon("spirit_" + spirit)

static func advisor_icon(advisor: String) -> Texture2D:
	return icon("advisor_" + advisor)

static func decision_icon(decision: String) -> Texture2D:
	return icon("decision_" + decision)

static func law_icon(law: String) -> Texture2D:
	return icon("law_" + law)

static func event_icon(event: String) -> Texture2D:
	return icon("event_" + event)

static func icon_texture(tex: Texture2D, side := 28) -> TextureRect:
	var view := TextureRect.new()
	view.texture = tex
	view.custom_minimum_size = Vector2(side, side)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

## Harita masasına uygun yüksek kontrastlı imleç ailesi.
static func install_cursors() -> void:
	var base := load("res://assets/ui/cursors/command.svg") as Texture2D
	var select := load("res://assets/ui/cursors/select.svg") as Texture2D
	var move := load("res://assets/ui/cursors/move.svg") as Texture2D
	var forbidden := load("res://assets/ui/cursors/forbidden.svg") as Texture2D
	Input.set_custom_mouse_cursor(base, Input.CURSOR_ARROW, Vector2(3, 2))
	Input.set_custom_mouse_cursor(select, Input.CURSOR_POINTING_HAND, Vector2(3, 2))
	Input.set_custom_mouse_cursor(move, Input.CURSOR_MOVE, Vector2(12, 12))
	Input.set_custom_mouse_cursor(move, Input.CURSOR_DRAG, Vector2(12, 12))
	Input.set_custom_mouse_cursor(select, Input.CURSOR_CAN_DROP, Vector2(3, 2))
	Input.set_custom_mouse_cursor(forbidden, Input.CURSOR_FORBIDDEN, Vector2(12, 12))
	Input.set_custom_mouse_cursor(move, Input.CURSOR_CROSS, Vector2(12, 12))

## Oyuna özel ikonlu küçük düğme (metin yok) + açıklama
static func icon_button(icon_name: String, tip: String, action: Callable, size: int = 30) -> Button:
	var b := Button.new()
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxTexture = get_theme().get_stylebox(st, "Button").duplicate()
		sb.set_content_margin_all(5)
		b.add_theme_stylebox_override(st, sb)
	if action.is_valid():
		b.pressed.connect(action)
	return b

static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
	t.default_font_size = 18

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	var pnl := textured("panel", 22, 18)
	t.set_stylebox("panel", "PanelContainer", pnl)
	t.set_stylebox("panel", "Panel", pnl)
	for pair: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"],
			["hover_pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		var b := textured(pair[1], 10, 6)
		b.content_margin_left = 12
		b.content_margin_right = 12
		t.set_stylebox(pair[0], "Button", b)
		t.set_stylebox(pair[0], "MenuButton", b)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)

	var tip := textured("tooltip", 10, 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0.9))
	t.set_constant("shadow_offset_x", "TooltipLabel", 1)
	t.set_constant("shadow_offset_y", "TooltipLabel", 2)
	t.set_constant("line_spacing", "TooltipLabel", 4)
	t.set_font_size("font_size", "TooltipLabel", 18)

	var sep := StyleBoxLine.new()
	sep.color = BORDER_DIM
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = BORDER_DIM
	vsep.thickness = 1
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	return t

static func format_number(v: float) -> String:
	var a := absf(v)
	if a >= 1_000_000.0:
		return "%.2fM" % (v / 1_000_000.0)
	if a >= 1_000.0:
		return "%.1fK" % (v / 1_000.0)
	return "%d" % int(v)

static func make_label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
