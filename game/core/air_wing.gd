class_name AirWing
extends RefCounted
## Hava kanadı: bir hava üssüne (eyalet) konuşlu, tek tür uçaktan oluşan birlik. Görevi bir bölgede (≈350 km) yürütür.

enum Mission { IDLE, SUPERIORITY, CAS, PORT_STRIKE }

var id: int
var owner: String
var name: String
var type: String                       ## fighter | cas | bomber
var planes := 0
var base := 0                          ## hava üssü olan eyalet id
var mission: Mission = Mission.IDLE
var zone := 0                          ## görev bölgesi merkezi (bölge id)
var auto := true                       ## yapay zekâ yönetsin (oyuncu kapatabilir)
var reserve := false                   ## üretimden gelen uçakların toplandığı yedek kanat
var losses_today := 0.0                ## görünüm / rapor
var kills_today := 0.0

func on_mission() -> bool:
	return mission != Mission.IDLE and zone > 0 and planes > 0
