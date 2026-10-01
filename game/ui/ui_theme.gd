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
	"advisor_air_minister": ["politics_a", 0],
	"advisor_armaments_minister": ["politics_a", 1],
	"advisor_chief_of_general_staff": ["politics_a", 2],
	"advisor_planning_commissioner": ["politics_a", 3],
	"advisor_naval_chief_of_staff": ["politics_a", 4],
	"advisor_information_minister": ["politics_a", 5],
	"advisor_science_council": ["politics_b", 0],
	"advisor_cabinet_secretary": ["politics_b", 1],
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
	"law_peacetime_economy": ["politics_d", 0],
	"law_rearmament": ["politics_d", 2],
	"law_war_economy": ["politics_d", 3],
	"law_total_war": ["politics_d", 4],
	"law_treaty_army": ["politics_d", 5],
	"law_professional_army": ["politics_e", 0],
	"law_one_year_service": ["politics_e", 1],
	"law_two_year_service": ["politics_e", 2],
	"law_reserve_callup": ["politics_e", 3],
	"law_open_markets": ["politics_e", 4],
	"law_clearing_agreements": ["politics_e", 5],
	"law_autarky": ["politics_f", 0],
	"law_trade_monopoly": ["politics_f", 1],
	"spirit_british_empire": ["politics_f", 2],
	"spirit_fascist_state": ["politics_f", 3],
	"spirit_five_year_plan": ["politics_f", 4],
	"spirit_great_purge": ["politics_f", 5],
	"spirit_industrial_drive": ["politics_g", 0],
	"spirit_maginot_mentality": ["politics_g", 1],
	"spirit_military_modernization": ["politics_g", 2],
	"spirit_national_unity": ["politics_g", 3],
	"spirit_rearmament_drive": ["politics_g", 4],
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
	"event_tur_montreux": "focus_tur_montreux", "event_ataturk_death": "focus_tur_kemalism",
	"event_soviet_straits_demand": "focus_sov_defense", "event_rhineland_crisis": "focus_ger_rhineland",
	"event_abdication_crisis": "focus_eng_guarantee", "event_sov_purge_end": "focus_sov_purge",
	"event_election": "focus_g_politics",
	"event_jap_february_26": "focus_jap_army", "event_eng_defence_white_paper": "focus_eng_rearm",
	"event_fra_popular_front": "focus_g_unity", "event_ger_berlin_olympics": "focus_g_propaganda",
	"event_sov_1936_constitution": "focus_sov_plan", "event_chi_xian_incident": "focus_chi_united_front",
	"event_pol_rambouillet_loan": "focus_g_arms", "event_ita_league_sanctions": "focus_ita_war",
	"event_soviet_moscow_talks": "focus_sov_defense",
	"law_levee_en_masse": "event_call_to_arms",
	"spirit_kemalist_officers": "focus_tur_army", "spirit_reform_resistance": "focus_tur_kemalism",
	"spirit_army_in_reorganization": "focus_g_army", "spirit_low_literacy": "focus_tur_village",
	"spirit_first_five_year_plan": "focus_tur_five_year", "spirit_moscow_trials": "focus_sov_purge",
	"spirit_purged_army": "focus_sov_purge", "spirit_king_george_v": "focus_eng_guarantee",
	"spirit_peace_ballot": "focus_fra_maginot", "spirit_cabinet_instability": "focus_g_politics",
	"spirit_laval_deflation": "focus_g_industry", "spirit_victor_emmanuel": "focus_ita_mare",
	"spirit_great_depression": "focus_usa_new_deal", "spirit_state_shintoism": "focus_jap_army",
	"spirit_divided_army_loyalties": "focus_chi_united_front", "spirit_april_constitution": "focus_g_politics",
	"spirit_polarized_republic": "focus_g_propaganda", "spirit_strike_wave": "focus_g_industry",
	"spirit_palace_camarilla": "focus_g_politics", "spirit_treaty_of_trianon": "focus_g_army",
	"spirit_levente": "focus_g_army", "spirit_sudeten_question": "focus_g_unity",
	"spirit_hss_boycott": "focus_g_unity", "spirit_milli_sef": "focus_tur_kemalism",
	"spirit_straits_sovereignty": "focus_tur_montreux", "spirit_blitzkrieg_doctrine": "focus_g_doctrine",
	"spirit_obsolete_army": "focus_g_army", "spirit_italian_army": "focus_ita_war",
	"spirit_expeditionary_doctrine": "focus_g_doctrine",
	"political_power": "focus_g_politics", "politics": "focus_g_politics",
	"stability": "focus_g_unity", "war_support": "focus_g_propaganda",
	"manpower": "focus_g_army", "research": "focus_g_research",
	"construction": "focus_g_construction", "production": "focus_g_industry",
	"trade": "resource_steel", "factory": "building_civilian_factory",
	"military_factory": "building_military_factory", "army": "focus_g_army",
	"air": "focus_g_air", "navy": "focus_g_navy", "diplomacy": "focus_tur_balkan",

	"advisor_air_minister": "focus_g_air", "advisor_armaments_minister": "focus_g_arms",
	"advisor_chief_of_general_staff": "focus_g_army", "advisor_planning_commissioner": "focus_g_industry",
	"advisor_naval_chief_of_staff": "focus_g_navy", "advisor_information_minister": "focus_g_propaganda",
	"advisor_science_council": "focus_g_research", "advisor_cabinet_secretary": "focus_g_politics",
	"decision_emergency_industry": "focus_g_industry", "decision_propaganda_campaign": "focus_g_propaganda",
	"decision_war_bonds": "focus_g_arms",

	"law_peacetime_economy": "focus_g_industry", "law_rearmament": "focus_g_arms",
	"law_war_economy": "focus_g_industry", "law_total_war": "focus_g_arms",
	"law_treaty_army": "spirit_armed_neutrality", "law_professional_army": "focus_g_army",
	"law_one_year_service": "focus_g_army", "law_two_year_service": "focus_g_army",
	"law_reserve_callup": "focus_g_army",
	"law_open_markets": "resource_steel", "law_clearing_agreements": "resource_oil",
	"law_autarky": "focus_g_industry", "law_trade_monopoly": "focus_tur_neutral",

	"event_access_request": "focus_tur_balkan", "event_anschluss": "focus_tur_axis",
	"event_call_to_arms": "focus_g_army", "event_faction_invite": "focus_tur_allies",
	"event_hatay_question": "focus_tur_hatay", "event_news_war": "focus_g_propaganda",
	"event_sudeten": "focus_tur_thrace", "event_white_peace": "spirit_armed_neutrality",

	"spirit_british_empire": "focus_g_navy", "spirit_fascist_state": "focus_tur_axis",
	"spirit_five_year_plan": "focus_tur_five_year", "spirit_great_purge": "focus_g_army",
	"spirit_industrial_drive": "focus_g_industry", "spirit_maginot_mentality": "focus_tur_thrace",
	"spirit_military_modernization": "focus_g_equipment", "spirit_national_unity": "focus_g_unity",
	"spirit_rearmament_drive": "focus_g_arms", "spirit_spanish_civil_war": "focus_g_army",
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

static var _new_icon_cache := {}

static func icon(name: String) -> Texture2D:
	# yeni ikon seti (docs/art/ICON_PROMPTS.md): assets/ui/icons_new/<ad>.png varsa her şeyin önüne geçer
	if _new_icon_cache.has(name):
		if _new_icon_cache[name] != null:
			return _new_icon_cache[name]
	else:
		var np := "res://assets/ui/icons_new/%s.png" % name
		_new_icon_cache[name] = load(np) if ResourceLoader.exists(np) else null
		if _new_icon_cache[name] != null:
			return _new_icon_cache[name]
	var painted_name: String = name if PAINTED_ATLAS.has(name) else PAINTED_ALIASES.get(name, name)
	if PAINTED_ATLAS.has(painted_name):
		return _painted_icon(painted_name)
	var vector_path := "res://assets/ui/icons/%s.svg" % name
	if ResourceLoader.exists(vector_path):
		return load(vector_path)
	var hd_path := "res://assets/ui/icons_hd/%s.png" % name
	return load(hd_path) if ResourceLoader.exists(hd_path) else null

## Lider portresi (docs/art/ICON_PROMPTS.md bölüm 12): 1936 lideri assets/portraits/<TAG>.png, sonradan gelen lider
## assets/portraits/<ad_soyad>.png (ör. ismet_inonu). Yoksa null (çağıran bayrağı gösterir).
static var _portrait_cache := {}
static func portrait(c: Country) -> Texture2D:
	if c == null:
		return null
	var names: Array[String] = [leader_slug(c.leader)]
	if c.leader == c.start_leader:
		names.push_front(c.tag)
	for n in names:
		if not _portrait_cache.has(n):
			var path := "res://assets/portraits/%s.png" % n
			_portrait_cache[n] = load(path) if ResourceLoader.exists(path) else null
		if _portrait_cache[n] != null:
			return _portrait_cache[n]
	return null

const _FOLD := {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u", "é": "e", "è": "e",
	"ê": "e", "ë": "e", "á": "a", "à": "a", "ä": "a", "å": "a", "ā": "a", "ă": "a", "ã": "a", "í": "i", "ï": "i", "ó": "o", "ò": "o",
	"ô": "o", "õ": "o", "ø": "o", "ú": "u", "ù": "u", "ñ": "n", "ś": "s", "š": "s", "ș": "s", "ž": "z", "ź": "z", "ż": "z", "č": "c",
	"ć": "c", "ł": "l", "ř": "r", "ț": "t", "ý": "y", "ő": "o", "ű": "u"}
static func leader_slug(name: String) -> String:
	var s := name.to_lower()
	var out := ""
	for ch in s:
		var code := ch.unicode_at(0)
		if code >= 0x300 and code <= 0x36F:
			continue          # birleşik işaretler (İ -> i + nokta)
		var f: String = _FOLD.get(ch, ch)
		out += f if (f >= "a" and f <= "z") or (f >= "0" and f <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")

## İpucu gövdesi için renklendirme (BBCode): işaretli sayılar iyi ise yeşil, kötü ise kırmızı; "azı iyi" değerlerde
## (süre, tüketim, bedel, gerginlik, ceza, kayıp, teslim) renk ters; ⚠ satırları kırmızı, şart satırları turuncu,
## "Başlık:" satırları soluk altın; işaretsiz sayılar parlak.
const _INVERTED := ["süre", "time", "tüketim", "consumer", "bedel", "cost", "maliyet", "gerginlik", "tension", "ceza",
	"penalty", "kayıp", "loss", "teslim", "surrender", "gecikme", "delay", "yakıt tüketimi", "fuel use", "direniş", "resistance"]
static var _num_re: RegEx
static func colorize(text: String) -> String:
	if _num_re == null:
		_num_re = RegEx.create_from_string("(%\\s?[+\\-−]\\s?\\d[\\d.,]*|[+\\-−]\\s?\\d[\\d.,]*\\s?%?|%\\d[\\d.,]*|\\b\\d[\\d.,]*\\s?%?)")
	var good := GOOD.to_html(false)
	var bad := BAD.to_html(false)
	var out: PackedStringArray = []
	for raw in text.split("\n"):
		var line := String(raw).replace("[", "[lb]")
		var low := line.to_lower()
		var stripped := line.strip_edges()
		if stripped.begins_with("⚠"):
			out.append("[color=#%s]%s[/color]" % [bad, line])
			continue
		if low.begins_with("gerekir") or low.begins_with("requires") or low.begins_with("gerekli"):
			out.append("[color=#e8a45a]%s[/color]" % line)
			continue
		if stripped.ends_with(":") and stripped.length() < 40:
			out.append("[color=#c9b27a]%s[/color]" % line)
			continue
		var inverted := false
		for k: String in _INVERTED:
			if low.contains(k):
				inverted = true
				break
		var res := ""
		var last := 0
		for m in _num_re.search_all(line):
			var tok := m.get_string()
			res += line.substr(last, m.get_start() - last)
			var neg := tok.contains("-") or tok.contains("−")
			var pos := tok.contains("+")
			if neg or pos:
				var is_good := pos != inverted
				res += "[color=#%s]%s[/color]" % [good if is_good else bad, tok]
			else:
				res += "[color=#f3e7c4]%s[/color]" % tok
			last = m.get_end()
		res += line.substr(last)
		out.append(res)
	return "\n".join(out)

## İlk bulunan ikon (yeni setteki ad, yoksa eski ad)
## Haritadaki sprite'lar için ölçek: doku hangi çözünürlükte gelirse gelsin (SVG ya da yeni 512 px ikon) aynı ekran boyu.
## ref_px: tasarımın dayandığı doku genişliği
static func px_scale(tex: Texture2D, ref_px: float) -> float:
	return ref_px / maxf(float(tex.get_width()), 1.0) if tex else 1.0

static func icon_or(primary: String, fallback: String) -> Texture2D:
	var t := icon(primary)
	return t if t else icon(fallback)

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

## Harita pinleri için uzaktan seçilen, menü resminden bağımsız yapı piktogramı.
static func building_pin_icon(building: String) -> Texture2D:
	var bitmap: Texture2D = icon("map_building_" + building)
	if bitmap:
		return bitmap
	var path := "res://assets/ui/icons/map_building_%s.svg" % building
	var pin: Texture2D = load(path) if ResourceLoader.exists(path) else null
	return pin if pin else building_icon(building)

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

## Arayüzü hazır ama oyuna henüz etkisi olmayan özellik: görünür kalır, soluklaşır, üstünde yasak imleci çıkar
## (ipucu nedenini söyler). Oyunu kazandıran ya da kaybettiren her şey açık kalır.
## Kutuya iç boşluk: tema türünün (theme_type_variation) kutusunu kopyalayıp kenar boşluklarını ayarlar
static func pad(pc: PanelContainer, h: int = 12, v: int = 9) -> PanelContainer:
	var variant := pc.theme_type_variation if pc.theme_type_variation != &"" else &"PanelContainer"
	var base := get_theme().get_stylebox("panel", variant)
	if base:
		var sb: StyleBox = base.duplicate()
		sb.content_margin_left = h
		sb.content_margin_right = h
		sb.content_margin_top = v
		sb.content_margin_bottom = v
		pc.add_theme_stylebox_override("panel", sb)
	return pc

static func mark_unavailable(c: Control) -> void:
	c.modulate = Color(1, 1, 1, 0.38)
	c.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

## Arayüz ikonu: yeni ikon setinin saydam kenar boşluğu (çoğunda her kenarda ~%20) kırpılır; aynı yuvada ikonun kendisi
## ~1,8 kat büyük görünür. Kırpma kutuları assets/ui/icon_trims.json'da (tools/make_icon_trims.py); listede olmayan ikon
## masaüstünde bir kez ölçülür, web'de olduğu gibi kalır. Sonuç önbelleklenir. Harita ikonları kırpılmaz.
static var _trim_cache := {}
static var _trims: Dictionary = {}
static func trimmed(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key := tex.get_instance_id()
	if _trim_cache.has(key):
		return _trim_cache[key]
	var out: Texture2D = tex
	var path := tex.resource_path
	if path.begins_with("res://assets/ui/icons_new/"):
		if _trims.is_empty():
			var f := FileAccess.open("res://assets/ui/icon_trims.json", FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
			_trims = parsed if parsed is Dictionary else {"": []}
		var stem := path.get_file().get_basename()
		var r := Rect2()
		if _trims.has(stem):
			var box: Array = _trims[stem]
			var k := float(tex.get_width()) / maxf(float(box[4]), 1.0)
			r = Rect2(float(box[0]) * k, float(box[1]) * k, float(box[2]) * k, float(box[3]) * k)
		elif not OS.has_feature("web"):
			r = _measure_trim(tex)
		if r.size.x > 0.0:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = r
			out = at
	_trim_cache[key] = out
	return out

static func _measure_trim(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	if img == null or img.is_compressed() or img.detect_alpha() == Image.ALPHA_NONE:
		return Rect2()
	var used := img.get_used_rect()
	var full := Vector2(img.get_width(), img.get_height())
	if used.size.x <= 0 or used.size.x * used.size.y >= full.x * full.y * 0.8:
		return Rect2()
	var side := maxf(used.size.x, used.size.y) * 1.08
	var c := Vector2(used.position) + Vector2(used.size) * 0.5
	return Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)).intersection(Rect2(Vector2.ZERO, full))

static func icon_texture(tex: Texture2D, side := 28) -> TextureRect:
	var view := TextureRect.new()
	view.texture = trimmed(tex)
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
	b.icon = trimmed(icon(icon_name))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBox = get_theme().get_stylebox(st, "Button").duplicate()
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
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## Arayüz dokuları (assets/ui/skin, tools/make_ui_skin.py)
static func skin(name: String, margin: int = 10, content: int = 8) -> StyleBox:
	var style := preload("res://game/ui/panel_material_style.gd").new()
	style.configure(legacy_skin(name, margin, content), load("res://assets/ui/materials/panel_gunmetal_v1.png"), name)
	return style

## Original border/state colour sources; also used by before/after art checks.
static func legacy_skin(name: String, margin: int = 10, content: int = 8) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/skin/%s.png" % name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	# Büyük yüzeylerde 96px metal dokuyu panel boyuna germeyelim. Dokunun tanesi ve
	# kenar kalınlığı sabit kalır; 9-dilim köşeleri/perçinleri zaten ayrı korur.
	if name in ["panel", "panel_flat", "strip"]:
		# Perçinin dış halkası 13. piksele ulaşır; tekrar alanına girmemeli.
		if name == "strip":
			sb.set_texture_margin_all(maxi(margin, 14))
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	elif name in ["header", "section"]:
		# Başlığın dikey ışık geçişi korunur; yatay fırça dokusu genişlikle uzamaz.
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb

## Ana ve iç panelin sabit içerik payları.
static func material_panel(flat := false) -> StyleBox:
	return skin("panel_flat" if flat else "panel", 14 if flat else 16, 12 if flat else 14)

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
	t.default_font_size = 20

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	var pnl := material_panel()
	t.set_stylebox("panel", "PanelContainer", pnl)
	t.set_stylebox("panel", "Panel", pnl)
	for pair: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"],
			["hover_pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		var b := skin(pair[1], 8, 9)
		b.content_margin_left = 16
		b.content_margin_right = 16
		t.set_stylebox(pair[0], "Button", b)
		t.set_stylebox(pair[0], "MenuButton", b)
		t.set_stylebox(pair[0], "OptionButton", b)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)

	# --- tür varyasyonları (control.theme_type_variation = "...")
	for v: Array in [["Header", "PanelContainer", "header", 8, 6], ["Section", "PanelContainer", "section", 6, 3],
			["Slot", "PanelContainer", "slot", 6, 3], ["SlotGold", "PanelContainer", "slot_gold", 6, 3],
			["SlotGood", "PanelContainer", "slot_good", 6, 3], ["SlotBad", "PanelContainer", "slot_bad", 6, 3],
			["Cell", "PanelContainer", "cell", 6, 3], ["Strip", "PanelContainer", "strip", 12, 6],
			["PanelFlat", "PanelContainer", "panel_flat", 14, 12]]:
		t.set_type_variation(v[0], v[1])
		t.set_stylebox("panel", v[0], skin(v[2], v[3], v[4]))
	t.set_stylebox("panel", "PanelFlat", material_panel(true))
	# liste satırı: koyu gömük zemin, ince kenar; tablo için kenarsız açık/koyu sıralar
	var row_sb := StyleBoxFlat.new()
	row_sb.bg_color = Color(0.085, 0.09, 0.092, 0.92)
	row_sb.border_color = Color(0.29, 0.26, 0.2)
	row_sb.set_border_width_all(1)
	row_sb.border_width_top = 0
	row_sb.border_color = Color(0.26, 0.24, 0.19)
	row_sb.set_content_margin_all(6)
	row_sb.content_margin_left = 6
	row_sb.set_corner_radius_all(2)
	t.set_type_variation("Row", "PanelContainer")
	t.set_stylebox("panel", "Row", row_sb)
	var alt := StyleBoxFlat.new()
	alt.bg_color = Color(0.15, 0.155, 0.15, 0.55)
	alt.set_content_margin_all(4)
	alt.content_margin_left = 6
	alt.content_margin_right = 6
	t.set_type_variation("CellAlt", "PanelContainer")
	t.set_stylebox("panel", "CellAlt", alt)
	var cell0 := StyleBoxFlat.new()
	cell0.bg_color = Color(0.05, 0.055, 0.057, 0.55)
	cell0.set_content_margin_all(4)
	cell0.content_margin_left = 6
	cell0.content_margin_right = 6
	t.set_type_variation("CellRow", "PanelContainer")
	t.set_stylebox("panel", "CellRow", cell0)
	for v: Array in [["Card", "card", "card_hover", "card_selected"], ["Tab", "tab", "tab", "tab_active"],
			["MenuTile", "menu_btn", "menu_btn_hover", "menu_btn_pressed"]]:
		t.set_type_variation(v[0], "Button")
		var n := skin(v[1], 8, 9)
		var h := skin(v[2], 8, 9)
		var p2 := skin(v[3], 8, 9)
		for sb: StyleBox in [n, h, p2]:
			sb.content_margin_left = 14
			sb.content_margin_right = 14
		t.set_stylebox("normal", v[0], n)
		t.set_stylebox("hover", v[0], h)
		t.set_stylebox("pressed", v[0], p2)
		t.set_stylebox("hover_pressed", v[0], p2)
		t.set_stylebox("disabled", v[0], n)
		t.set_stylebox("focus", v[0], StyleBoxEmpty.new())

	# yazı kutusu (arama): gömük yuva dokusu, odakta altın yuva
	var le_n := skin("slot", 6, 8)
	le_n.content_margin_left = 12
	var le_f := skin("slot_gold", 6, 8)
	le_f.content_margin_left = 12
	t.set_stylebox("normal", "LineEdit", le_n)
	t.set_stylebox("read_only", "LineEdit", le_n)
	t.set_stylebox("focus", "LineEdit", le_f)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))

	var tip := skin("tooltip", 8, 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0.9))
	t.set_constant("shadow_offset_x", "TooltipLabel", 1)
	t.set_constant("shadow_offset_y", "TooltipLabel", 2)
	t.set_constant("line_spacing", "TooltipLabel", 4)
	t.set_font_size("font_size", "TooltipLabel", 20)

	# ilerleme çubukları: gömük koyu zemin, altın/yeşil dolgu
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.03, 0.035, 0.04, 0.95)
	pb_bg.border_color = Color(0, 0, 0)
	pb_bg.set_border_width_all(1)
	var pb_fg := StyleBoxFlat.new()
	pb_fg.bg_color = Color("b89a52")
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_color("font_color", "ProgressBar", TEXT)

	# kaydırma çubuğu: ince, koyu
	var sgrab := StyleBoxFlat.new()
	sgrab.bg_color = Color(0.42, 0.40, 0.34, 0.9)
	sgrab.set_corner_radius_all(2)
	sgrab.content_margin_left = 4
	sgrab.content_margin_right = 4
	var strack := StyleBoxFlat.new()
	strack.bg_color = Color(0, 0, 0, 0.45)
	strack.content_margin_left = 4
	strack.content_margin_right = 4
	for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", sgrab)
	t.set_stylebox("scroll", "VScrollBar", strack)

	var sep := StyleBoxLine.new()
	sep.color = Color(0.02, 0.02, 0.02)
	sep.thickness = 2
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

## Okunur yazı boyu: tasarım boyutu -> ekrandaki boyut. Küçük yazılar en az 16 olur (pencere/tarayıcı ölçeğinde
## 1920x1080 tasarımın küçülmesiyle 12'lik yazı okunmuyordu); büyükler orantılı büyür.
static func fs(size: int) -> int:
	if size <= 0:
		return size
	if size <= 13:
		return 16
	if size <= 20:
		return size + 3
	return size + 2

static func make_label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	return l
