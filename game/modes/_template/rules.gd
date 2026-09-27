extends ModeRules
## Şablon modun kural betiği (data/modes/_template/mode.json "rules"). Yeni moda kopyalanır: tools/new_mode.py.
## Her kanca isteğe bağlı; kullanmadığını sil. Kurallar ve çağrılma sırası: game/core/mode_rules.gd, docs/modlar/README.md.

var days := 0                                  ## örnek mod durumu (kayda yazılır)
var rng := RandomNumberGenerator.new()         ## moda özel rastgelelik: tohumlu ve kayıtlı (belirlenimcilik)

func on_new_game() -> void:
	days = 0
	rng.seed = 1936

func on_day() -> void:
	days += 1

## Örnek oyun sonu: 400. günde oyuncunun 5'ten az eyaleti kaldıysa yenilgi (sebep bir strings.csv anahtarı)
func check_end() -> Dictionary:
	if days == 400:
		var p: Country = World.player()
		if p and p.states.size() < 5:
			return {"victory": false, "reason": "GAMEOVER_CAPITULATED"}
	return {}

## Yeni etki anahtarı: "template_bonus": N → oyuncuya N nüfuz. İki yere birden (CLAUDE.md kural 2).
func effect_keys() -> Array[String]:
	return ["template_bonus"]

func apply_effect(c: Country, key: String, value: Variant) -> void:
	if key == "template_bonus":
		c.political_power += float(value)

func describe_effect(key: String, value: Variant) -> String:
	if key == "template_bonus":
		return str(TranslationServer.translate("EFF_TEMPLATE_BONUS")) % int(value)
	return ""

## JSON sayıları ondalıklı (double): 64 bitlik tamsayılar (RNG durumu) bozulmasın diye metin olarak yazılır
func to_save() -> Dictionary:
	return {"days": days, "rng": str(rng.state)}

func from_save(d: Dictionary) -> void:
	days = int(d.get("days", 0))
	rng.state = int(str(d.get("rng", str(rng.state))))
