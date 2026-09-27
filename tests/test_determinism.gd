extends "res://tests/test_case.gd"
## Belirlenimcilik: aynı tohumla iki koşu (yeni oyun + 120 gün) aynı dünyayı üretir. Fark varsa alanları yazılır.

const DAYS := 120

var _snap := preload("res://tests/snapshot.gd").new()

func _run(seed_value: int) -> Dictionary:
	seed(seed_value)
	Game.new_game()
	World.start_game("TUR")
	days(DAYS)
	return _snap.take(true)

func test_same_seed_same_world() -> void:
	var a := _run(1234)
	var b := _run(1234)
	none(_snap.diff_fields(a, b), "aynı tohum, farklı sonuç")

## Tohum gerçekten kullanılıyor: farklı tohumla dünya en az bir alanda değişir (rastgelelik yoksa test anlamsız olur)
func test_different_seed_differs() -> void:
	var a := _run(1234)
	var b := _run(987)
	gt(_snap.diff_fields(a, b).size(), 0, "farklı tohumla fark alanı sayısı")
