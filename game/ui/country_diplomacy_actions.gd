class_name CountryDiplomacyActions
extends RefCounted
## Shared rules for country-card actions. A stale UI callback never authorizes an action.

static func entries(actor: Country, target: Country) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec: Array in [
		["declare", "battle", "DIPLO_DECLARE", "TIP_DECLARE"],
		["justify", "war_support", "QUICK_JUSTIFY", "TIP_JUSTIFY"],
		["access", "army", "QUICK_ACCESS", "TIP_ACCESS"],
		["guarantee", "stability", "QUICK_GUARANTEE", "TIP_GUARANTEE"],
		["invite", "diplomacy", "DIPLO_INVITE", "TIP_INVITE"],
		["peace", "political_power", "DIPLO_PEACE", "TIP_PEACE"]]:
		var tip := String(TranslationServer.translate(spec[3]))
		if spec[0] == "justify":
			tip = String(TranslationServer.translate("DIPLO_JUSTIFY")) % int(Diplomacy.JUSTIFY_COST) + "\n" + tip % Diplomacy.JUSTIFY_DAYS
		result.append({"key": spec[0], "icon": spec[1], "title": TranslationServer.translate(spec[2]),
			"tip": tip, "error": blocked(actor, target, spec[0])})
	return result

static func blocked(actor: Country, target: Country, key: String) -> String:
	if actor == null or target == null or actor == target or not actor.exists() or not target.exists():
		return "DIPLO_ERR_INVALID"
	if not World.is_active(actor.tag) or not World.is_active(target.tag):
		return "DIPLO_ERR_NEUTRAL"
	var enemies := Diplomacy.are_enemies(actor.tag, target.tag)
	match key:
		"justify": return Diplomacy.can_justify(actor, target)
		"declare": return Diplomacy.can_declare(actor, target)
		"guarantee":
			if enemies or target.tag in actor.guarantees: return "DIPLO_ERR_ALREADY"
			return Diplomacy.guarantee_block(actor)
		"access": return "DIPLO_ERR_ALREADY" if enemies or target.tag in actor.access else ""
		"invite":
			if actor.faction != actor.tag: return "DIPLO_ERR_NO_FACTION"
			return "DIPLO_ERR_ALREADY" if enemies or target.faction != "" else ""
		"peace": return "" if enemies else "DIPLO_ERR_INVALID"
	return "DIPLO_ERR_INVALID"

static func execute(actor_tag: String, target_tag: String, key: String) -> bool:
	if not World.in_game or World.player_tag != actor_tag: return false
	var actor: Country = World.countries.get(actor_tag)
	var target: Country = World.countries.get(target_tag)
	if blocked(actor, target, key) != "": return false
	match key:
		"justify": return Diplomacy.justify(actor, target)
		"declare": return Diplomacy.declare_war(actor_tag, target_tag)
		"guarantee": Diplomacy.guarantee(actor_tag, target_tag)
		"access":
			if target.ideology == actor.ideology or Diplomacy.are_allies(actor_tag, target_tag) or randf() < 0.3:
				Diplomacy.grant_access(target_tag, actor_tag)
				World.notify(String(TranslationServer.translate("NOTE_ACCESS_OK")) % target.display_name(), "good")
			else:
				World.notify(String(TranslationServer.translate("NOTE_ACCESS_NO")) % target.display_name(), "bad")
		"invite":
			if Diplomacy.ai_accepts_invite(target, actor):
				Diplomacy.join_faction(target_tag, actor_tag)
			else:
				World.notify(String(TranslationServer.translate("NOTE_INVITE_NO")) % target.display_name(), "bad")
		"peace":
			if not Diplomacy.offer_white_peace(actor_tag, target_tag):
				World.notify(String(TranslationServer.translate("NOTE_PEACE_NO")) % target.display_name(), "bad")
		_: return false
	return true
