class_name City
extends RefCounted
## Şehir: zafer puanı (VP), başkent ve liman bilgisini taşır.

var id: int
var name: String
var names: Dictionary = {}      ## dil kodu -> ad

func display_name() -> String:
	return names.get(TranslationServer.get_locale().substr(0, 2), name)
var province_id: int
var state_id: int
var position: Vector2
var population: int
var victory_points: int
var is_capital: bool
var is_port: bool
var style: String = "west"       ## mimari stil: west | east | orient | nordic
var gates: Array[Vector2] = []    ## ana caddelerin şehirden çıktığı noktalar (yol/demiryolu bağlantısı)
var grid_angle := 0.0             ## şehir ızgarasının açısı
