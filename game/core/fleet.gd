class_name Fleet
extends RefCounted
## Filo: bir limanda ya da deniz bölgesinde bulunan gemi grubu. Görevi bir deniz bölgesinde (zone) yürütür.

enum Mission { PORT, SUPERIORITY, RAID, ESCORT }

var id: int
var owner: String
var name: String
var ships: Dictionary = {}             ## tür -> adet (int)
var damage: Dictionary = {}            ## tür -> sıradaki geminin aldığı hasar (hp)
var location: int                      ## deniz bölgesi ya da liman (kara) bölgesi
var home: int                          ## ana üs (liman bölgesi)
var path: PackedInt32Array = []
var progress := 0.0                    ## km, sıradaki bölgeye doğru
var mission: Mission = Mission.PORT
var zone_center := 0                   ## görev bölgesinin merkez deniz bölgesi (0 = yok)
var org := 1.0                         ## 0..1
var returning := false                 ## organizasyon düştü: üsse dönüyor
var in_combat := false
var wander := 0                        ## devriyede sonraki hedef seçimine kalan saat
var patrol := false                    ## devriye kayması (yarı hız)
var submerged := false                 ## denizaltı filosu dalışta (görünüm)
var reserve := false                   ## tersaneden çıkan gemilerin toplandığı yedek filo (AI göreve çıkarmaz)

func total() -> int:
	var n := 0
	for t: String in ships:
		n += int(ships[t])
	return n

func is_sub_fleet() -> bool:
	return int(ships.get("submarine", 0)) > 0 and total() == int(ships.get("submarine", 0))

func is_moving() -> bool:
	return not path.is_empty()

func in_port() -> bool:
	return path.is_empty() and World.province(location) != null and World.province(location).is_land()
