class_name ConstructionProject
extends RefCounted
## İnşaat kuyruğundaki bir proje (bir eyalette bir bina seviyesi).

var building: String
var state_id: int
var progress: float = 0.0     ## birikmiş inşaat puanı
var cost: float
var assigned_factories: int = 0
var last_daily: float = 0.0   ## son gündeki ilerleme (tahmini süre için)

func fraction() -> float:
	return clampf(progress / cost, 0.0, 1.0)

func days_left() -> int:
	if last_daily <= 0.0:
		return -1
	return int(ceil((cost - progress) / last_daily))
