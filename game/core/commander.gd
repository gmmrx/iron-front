class_name Commander
extends RefCounted
## Kara komutanı. General bir orduyu, mareşal bir ordular grubunu (ya da bir orduyu) yönetir. Beceri (1-5) bağlı
## tümenlerin saldırı ve savunmasını artırır; komutanı olduğu tümenler savaştıkça tecrübe kazanır, tecrübe dolunca
## becerisi yükselir. Generali mareşalliğe terfi ettirmek komuta gücü ister (oyuncu karar verir).

enum Rank { GENERAL, MARSHAL }
const MAX_SKILL := 5

var id: int
var owner: String
var name: String
var rank: Rank = Rank.GENERAL
var skill := 1
var xp := 0.0                   ## 0..1: dolunca beceri +1

func is_marshal() -> bool:
	return rank == Rank.MARSHAL

func rank_name() -> String:
	return TranslationServer.translate("CMD_RANK_%d" % int(rank))

## Tecrübe ekle; beceri yükseldiyse true
func gain(amount: float) -> bool:
	if skill >= MAX_SKILL:
		xp = 0.0
		return false
	xp += amount / float(skill)
	if xp >= 1.0:
		xp = 0.0
		skill += 1
		return true
	return false
