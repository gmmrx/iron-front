extends RefCounted
## Test tabanı. tests/test_*.gd dosyaları bunu genişletir:  extends "res://tests/test_case.gd"
## Koşucu (tests/run.gd) her test_* fonksiyonundan önce temiz oyun kurar: Game.new_game() + World.start_game(player_tag()).
## Doğrulamalar hatayı kaydeder ve false döndürür; test sürer, sonuçta tüm hatalar yazılır.

var _failures: Array[String] = []
var _warnings: Array[String] = []

## Testlerin oynadığı ülke (dosya bazında değiştirmek için ez)
func player_tag() -> String:
	return "TUR"

## Koşucu çağırır: yeni test başlıyor
func _begin() -> void:
	_failures.clear()
	_warnings.clear()

# ------------------------------------------------------------------ doğrulamalar
func fail(msg: String) -> bool:
	_failures.append(msg)
	return false

## Başarısız saymaz; koşucu uyarı olarak yazar (bilinen eksikler için)
func warn(msg: String) -> void:
	_warnings.append(msg)

func check(cond: bool, msg: String) -> bool:
	return true if cond else fail(msg)

func eq(actual: Variant, expected: Variant, msg: String) -> bool:
	if typeof(actual) == typeof(expected) and actual == expected:
		return true
	if (typeof(actual) == TYPE_INT or typeof(actual) == TYPE_FLOAT) and (typeof(expected) == TYPE_INT or typeof(expected) == TYPE_FLOAT) \
			and float(actual) == float(expected):
		return true
	return fail("%s: beklenen %s, bulunan %s" % [msg, str(expected), str(actual)])

func near(actual: float, expected: float, eps: float, msg: String) -> bool:
	return true if absf(actual - expected) <= eps else fail("%s: beklenen %s ± %s, bulunan %s" % [msg, expected, eps, actual])

func gt(a: float, b: float, msg: String) -> bool:
	return true if a > b else fail("%s: %s > %s değil" % [msg, a, b])

func ge(a: float, b: float, msg: String) -> bool:
	return true if a >= b else fail("%s: %s >= %s değil" % [msg, a, b])

func lt(a: float, b: float, msg: String) -> bool:
	return true if a < b else fail("%s: %s < %s değil" % [msg, a, b])

## Liste boşsa geçer; değilse her öğe ayrı hata olarak yazılır (veri denetimleri için)
func none(problems: Array, msg: String) -> bool:
	for p in problems:
		fail("%s: %s" % [msg, str(p)])
	return problems.is_empty()

# ------------------------------------------------------------------ yardımcılar
## Oyunu n gün ilerlet (saatlik tick'lerle, sahiplik sinyalleri dahil)
func days(n: int) -> void:
	for i in n:
		GameClock.advance_hours(24)
		World.flush_ownership()

func player() -> Country:
	return World.player()

func country(tag: String) -> Country:
	return World.countries.get(tag)

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
