class_name Province
extends RefCounted
## Haritanın en küçük birimi: hareket, muharebe ve ikmal bu düzeyde işler.

enum Type { LAND, SEA, LAKE }

var id: int
var type: Type
var terrain: String
var state_id: int
var coastal: bool
var center: Vector2
var lonlat: Vector2                     ## merkezin boylam/enlemi (mesafe hesabı)
var area_km2: int
var adjacent: PackedInt32Array
var river_adjacent: PackedInt32Array   ## nehir geçişli komşular
var strait_adjacent: PackedInt32Array  ## boğaz üzerinden bağlı kara bölgeleri
var city: City                          ## bölgedeki en büyük şehir (yoksa null)

func is_land() -> bool:
	return type == Type.LAND
