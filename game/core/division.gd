class_name Division
extends RefCounted
## Tek bir tümen. Konum bir bölgedir; hareket bir sonraki bölgeye doğru km ilerlemesiyle yapılır.

var id: int
var owner: String
var template: int                      ## ülkenin şablon listesindeki indeks
var name: String
var province: int
var path: PackedInt32Array = []        ## gidilecek bölgeler (sıradaki ilk)
var progress := 0.0                    ## km, sıradaki bölgeye doğru
var strength := 1.0                    ## 0..1 (can/ekipman doluluğu)
var org := 0.0
var attacking := 0                     ## saldırdığı bölge (0 = yok)
var in_combat := false
var idle_hours := 0                    ## siper (entrenchment) için
var supplied := true
var training := 0                      ## kalan eğitim günü (hareket edemez)
var xp := 0.15                         ## tecrübe 0..1: Yeşil · Eğitimli · Düzenli · Kıdemli · Seçkin
var planning := 0.0                    ## 0..1 → en çok +%20 saldırı (cephede bekledikçe birikir)
var army := 0                          ## bağlı olduğu ordu (0 = yok)
var hold := false                      ## "son askere kadar savun": organizasyon bitince geri çekilmez (oyuncu seçer)
var s: Dictionary = {}                 ## istatistik önbelleği (Military.div_stats)

const XP_LEVELS := [0.1, 0.3, 0.55, 0.8]          ## eşikler
const XP_MULT := [0.75, 1.0, 1.25, 1.5, 1.75]

func xp_level() -> int:
	var l := 0
	for t: float in XP_LEVELS:
		if xp >= t:
			l += 1
	return l

func xp_mult() -> float:
	return XP_MULT[xp_level()]

func is_moving() -> bool:
	return not path.is_empty()
