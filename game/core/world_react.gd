class_name WorldReact
extends RefCounted
## Dünya olaylarına tepki: oyuncunun iki taraftan biri (ya da müttefiki) olmadığı bir savaş ilanına ya da ilhaka dünya
## olayları menüsünden 2–3 gerçek seçenekle cevap. Seçenekler, bedelleri ve etkileri data/common/world_reactions.json'da;
## etkiler var olan etki sözlüğüyle uygulanır (Politics.apply_effects): "self" tepki veren ülkeye, "target" saldırıya
## uğrayana, "actor" saldırgana; etki değerlerindeki "actor" / "target" sözcükleri o ülkelerin koduna çevrilir.
## Oyuncunun kendi saldırısına yapay zekâ büyük güçleri aynı seçeneklerle tepki verir (kuralı veride).

const PATH := "res://data/common/world_reactions.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data

## Kayda tepki bağla. Oyuncu taraflardan biriyse (ya da müttefikiyse) seçenek yok; oyuncu saldırgansa yapay zekâ tepki verir.
static func offer(e: Dictionary, kind: String, actor: String, target: String) -> void:
	if not data().has(kind):
		return
	var me := World.player_tag
	if not World.in_game or me == "":
		return
	if actor == me:
		_ai_react(kind, actor, target)
		return
	if target == me or Diplomacy.are_allies(actor, me) or Diplomacy.are_allies(target, me) or Diplomacy.are_enemies(actor, me):
		return
	e["react"] = kind
	e["actor"] = actor
	e["target"] = target

static func options(e: Dictionary) -> Array:
	return (data().get(String(e.get("react", "")), {}) as Dictionary).get("options", [])

## Kayda hâlâ tepki verilebilir mi (seçilmemiş, süresi dolmamış, taraflar ayakta)
static func is_open(e: Dictionary) -> bool:
	if not e.has("react") or e.has("choice"):
		return false
	var days := int((data().get(String(e["react"]), {}) as Dictionary).get("days", 30))
	if World.day_count - int(e["day"]) > days:
		return false
	var actor: Country = World.countries.get(String(e.get("actor", "")))
	return actor != null and actor.exists()

static func option(e: Dictionary, id: String) -> Dictionary:
	for o: Dictionary in options(e):
		if String(o["id"]) == id:
			return o
	return {}

## Seçeneğin şartı tutuyor mu ("" = evet, değilse neden)
static func block(c: Country, e: Dictionary, o: Dictionary) -> String:
	var req: Dictionary = o.get("require", {})
	for eq: String in (req.get("equipment", {}) as Dictionary):
		if float(c.stockpile.get(eq, 0.0)) < float(req["equipment"][eq]):
			return TranslationServer.translate("REACT_NEED_EQUIPMENT") % [int(req["equipment"][eq]), Economy.equipment_name(eq)]
	var target: Country = World.countries.get(String(e.get("target", "")))
	if not (o.get("target", []) as Array).is_empty() and (target == null or not target.exists()):
		return TranslationServer.translate("REACT_TARGET_GONE")
	return ""

## Oyuncunun seçimi: etkiler uygulanır, kayıt seçimi taşır, seçimin haberi yazılır
static func choose(e: Dictionary, id: String) -> bool:
	var c := World.player()
	var o := option(e, id)
	if c == null or o.is_empty() or not is_open(e) or block(c, e, o) != "":
		return false
	_apply(c, e, o)
	e["choice"] = id
	return true

static func _apply(c: Country, e: Dictionary, o: Dictionary) -> void:
	var actor := String(e.get("actor", ""))
	var target := String(e.get("target", ""))
	Politics.apply_effects(c, bind(o.get("self", []), actor, target))
	var t: Country = World.countries.get(target)
	if t and t.exists() and not (o.get("target", []) as Array).is_empty():
		Politics.apply_effects(t, bind(o["target"], actor, target))
	var a: Country = World.countries.get(actor)
	if a and a.exists() and not (o.get("actor", []) as Array).is_empty():
		Politics.apply_effects(a, bind(o["actor"], actor, target))
	if String(o.get("news", "")) != "":
		World.world_event("diplomacy", String(o["news"]), ["@" + c.tag, "@" + actor, "@" + target], [c.tag, actor, target],
			World.capital_province(c.tag))

## Etki listesinin kopyası; "actor" / "target" değerleri ülke koduna çevrilir
static func bind(effects: Array, actor: String, target: String) -> Array:
	var out: Array = []
	for eff: Dictionary in effects:
		var d := {}
		for k: String in eff:
			var v: Variant = eff[k]
			if v is String and v == "actor":
				v = actor
			elif v is String and v == "target":
				v = target
			d[k] = v
		out.append(d)
	return out

## Seçeneğin etkileri (ipucu): kendine, kurbana, saldırgana
static func describe(e: Dictionary, o: Dictionary) -> String:
	var actor := String(e.get("actor", ""))
	var target := String(e.get("target", ""))
	var lines: Array[String] = []
	var own := Politics.describe_effects(bind(o.get("self", []), actor, target))
	if own != "":
		lines.append(own)
	for side: String in ["target", "actor"]:
		var eff: Array = o.get(side, [])
		if eff.is_empty():
			continue
		var tag := target if side == "target" else actor
		var who: Country = World.countries.get(tag)
		lines.append(TranslationServer.translate("REACT_TO") % (who.display_name() if who else tag))
		lines.append(Politics.describe_effects(bind(eff, actor, target)))
	return "\n".join(lines)

## Yapay zekâ büyük güçlerinin oyuncunun saldırısına tepkisi (kural veride): demokrasiler demokrasi olmayan saldırganı kınar
static func _ai_react(kind: String, actor: String, target: String) -> void:
	var rule: Dictionary = (data()[kind] as Dictionary).get("ai", {})
	if rule.is_empty():
		return
	var o := option({"react": kind}, String(rule["option"]))
	var a: Country = World.countries.get(actor)
	if o.is_empty() or a == null:
		return
	var e := {"react": kind, "actor": actor, "target": target, "day": World.day_count}
	for c: Country in World.countries.values():
		if not c.exists() or not c.is_major() or c.tag == actor or c.tag == target:
			continue
		if Diplomacy.are_allies(c.tag, actor) or Diplomacy.are_enemies(c.tag, actor):
			continue
		match String(rule.get("rule", "")):
			"democracies_condemn":
				if c.ideology != "democratic" or a.ideology == "democratic":
					continue
		if block(c, e, o) != "":
			continue
		_apply(c, e, o)
