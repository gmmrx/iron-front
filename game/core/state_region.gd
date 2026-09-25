class_name StateRegion
extends RefCounted
## türün klasiklerindeki "state": bina slotları, nüfus ve sahiplik birimi.

var id: int
var name: String
var adm0 := ""                  ## modern ülke kodu (anavatan/sömürge ayrımı için)
var names: Dictionary = {}      ## dil kodu -> ad
var owner: String
var controller: String
var provinces: PackedInt32Array
var population: int
var area_km2: int
var center: Vector2
var cities: Array[City] = []
var category: String = "rural"
var building_slots: int = 2               ## ortak bina slotu (fabrika, tersane, rafineri)
var buildings: Dictionary = {}            ## bina -> seviye
var resources: Dictionary = {}            ## kaynak -> miktar
var coastal := false

func building_level(b: String) -> int:
	return int(buildings.get(b, 0))

func used_slots() -> int:
	var n := 0
	for b: String in buildings:
		if Economy.is_shared_slot(b):
			n += int(buildings[b])
	return n

func free_slots() -> int:
	return building_slots - used_slots()

func display_name() -> String:
	return names.get(TranslationServer.get_locale().substr(0, 2), name)

func victory_points() -> int:
	var total := 0
	for c in cities:
		total += c.victory_points
	return total

func largest_city() -> City:
	return cities[0] if not cities.is_empty() else null
