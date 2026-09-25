class_name Country
extends RefCounted
## Bir ülkenin simülasyon verisi. Render/UI'dan bağımsızdır.

var tag: String
var index: int                  ## palet/veri dokusundaki indeks (1..255)
var names: Dictionary           ## dil kodu -> ad
var map_names: Dictionary       ## dil kodu -> harita üzerindeki kısa ad
var color: Color
var ideology: String
var leader: String
var stability: float
var war_support: float
var political_power: float = 50.0
var capital_state: int = 0
var flag_def: Dictionary
var states: Array[int] = []
var population: int = 0
var manpower_pop: int = 0                  ## insan gücü nüfusu: anavatan tam, sömürge/işgal %15 (türün klasiklerindeki gibi)
var core_adm0 := ""                        ## anavatanın modern ülke kodu
var construction_queue: Array[ConstructionProject] = []
var consumer_goods: float = 0.35          ## sivil fabrikaların tüketim malına giden oranı (ekonomi yasası)
var laws: Dictionary = {}                  ## yasa grubu -> yasa
var production_lines: Array[ProductionLine] = []
var stockpile: Dictionary = {}             ## ekipman -> adet (float)
var resource_use: Dictionary = {}          ## kaynak -> son gün kullanılan
var imports: Array = []                    ## [{from, res, amount}] (otomatik ticaret)
var exports: Array = []                    ## [{to, res, amount}]
var trade_factories_paid := 0              ## ithalat için verilen sivil fabrika
var trade_factories_earned := 0            ## ihracattan kazanılan sivil fabrika

# --- siyaset
var popularity: Dictionary = {}            ## ideoloji -> oran (toplam 1)
var spirits: Array[String] = []            ## milli ruhlar
var advisors: Array[String] = []           ## işe alınan danışmanlar
var fuel := -1.0                           ## yakıt deposu (-1: henüz doldurulmadı)
var fuel_cap := 0.0
var research_stored := 0.0               ## boş araştırma yuvalarında biriken gün (en çok 30 × yuva)
var focus_done: Array[String] = []
var focus_current := ""
var focus_progress := 0.0                  ## gün
var research_slots := 2
var research_current: Array = []           ## [{tech, progress}]
var research_done: Array[String] = []
var research_bonus: Array = []             ## [{category, value, uses}]
var tech_mods: Dictionary = {}             ## araştırmalardan gelen toplam modifier'lar
var decisions_active: Dictionary = {}      ## karar -> bitiş günü (gün sayacı)

# --- askeri / diplomatik
var manpower_used := 0                     ## tümenlerde ve kayıplarda kullanılan insan gücü
var templates: Array = []                  ## [{name, battalions: {tür: adet}}]
var faction := ""                          ## ittifak adı
var war_goals: Dictionary = {}             ## hedef tag -> "justifying:gün" | "ready"
var justify_progress: Dictionary = {}      ## hedef tag -> kalan gün
var guarantees: Array[String] = []         ## garanti verilen ülkeler
var access: Array[String] = []             ## askeri geçiş hakkı olan ülkeler (bize geçiş verenler)
var capitulated := false
var surrender_progress := 0.0
var air_losses := 0.0
var naval_strength_cache := 0.0

## Toplam modifier: milli ruhlar + danışmanlar + araştırma + yasalar
func mod(key: String) -> float:
	var total := float(tech_mods.get(key, 0.0))
	for sp in spirits:
		total += float(Politics.spirit_mods(sp).get(key, 0.0))
	for ad in advisors:
		total += float(Politics.advisor_mods(ad).get(key, 0.0))
	total += Economy.law_sum(self, key)
	return total

func exists() -> bool:
	return not states.is_empty()

func is_major() -> bool:
	return tag in ["GER", "ENG", "FRA", "ITA", "SOV"]

func available_manpower() -> int:
	return maxi(recruitable_manpower() - manpower_used, 0)

func display_name() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2)
	return names.get(loc, names.get("en", tag))

## Haritada gösterilecek kısa ad (yoksa resmi ad)
func map_name() -> String:
	var loc := TranslationServer.get_locale().substr(0, 2)
	return map_names.get(loc, display_name()) if not map_names.is_empty() else display_name()

func daily_political_power_gain() -> float:
	return maxf(2.0 * (1.0 + mod("political_power_gain")) + mod("political_power_flat"), 0.1)

func recruitable_manpower() -> int:
	return int(manpower_pop * (Economy.law_value(self, "manpower", 0.015) + mod("recruitable_population")))
