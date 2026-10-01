class_name UnitNames
extends RefCounted
## Birlik adları ülkenin kendi dilinde (data/common/unit_names.json): tümen (türüne göre), ordu, ordular grubu, filo,
## denizaltı filosu, yedek filolar, hava kanatları. Arayüz dilinden bağımsızdır: Türkçe oynarken de Almanya'nın tümeni
## "1. Infanterie-Division", İngiltere'ninki "1st Infantry Division" olur.

const PATH := "res://data/common/unit_names.json"
static var _data: Dictionary = {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = d if d is Dictionary else {"cultures": {}, "tags": {}, "fallback": "english"}

## Ülkenin ad kültürü: unit_names.json tags → komutan havuzu (commanders.json pool) → yedek (İngilizce)
static func culture(tag: String) -> String:
	_load()
	var cultures: Dictionary = _data["cultures"]
	var c: String = _data["tags"].get(tag, Military._cmd_data.get("pool", {}).get(tag, ""))
	return c if cultures.has(c) else String(_data["fallback"])

## kind: infantry / armored / motorized / garrison / army / army_group / fleet / sub_fleet / reserve_fleet /
## reserve_sub_fleet / wing_fighter / wing_cas / wing_bomber
static func name_of(tag: String, kind: String, n: int = 0) -> String:
	_load()
	var cul: Dictionary = _data["cultures"][culture(tag)]
	var pat: String = cul.get(kind, _data["cultures"][_data["fallback"]].get(kind, "{n}"))
	return pat.replace("{n}", str(n)).replace("{o}", ordinal_en(n)).replace("{fr}", "1re" if n == 1 else "%de" % n)

static func ordinal_en(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suf = "st"
			2: suf = "nd"
			3: suf = "rd"
	return "%d%s" % [n, suf]

## Tümenin türü taburlarından: zırhlı, motorlu, garnizon (topçusuz 5 ve daha az piyade), piyade
static func division_kind(bats: Dictionary) -> String:
	if int(bats.get("light_armor", 0)) + int(bats.get("medium_armor", 0)) > 0:
		return "armored"
	if int(bats.get("motorized", 0)) > 0:
		return "motorized"
	var total := 0
	for b: String in bats:
		total += int(bats[b])
	if int(bats.get("artillery", 0)) == 0 and total <= 5:
		return "garrison"
	return "infantry"
