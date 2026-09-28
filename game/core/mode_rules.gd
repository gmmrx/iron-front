class_name ModeRules
extends RefCounted
## Bir oyun modunun kod kancaları (isteğe bağlı). Mod betiği bunu genişletir: game/modes/<id>/rules.gd, manifestte
## "rules": "res://game/modes/<id>/rules.gd". Game kuralları mod açılırken kurar (Game.rules); WWII modunda kural yoktur.
## Örnek: game/modes/_template/rules.gd. Rehber: docs/modlar/README.md.
##
## Kurallar (CLAUDE.md):
## - Oyuncu adına iş yapma (kural 1). on_game_started'da oyuncuya kolaylık açacaksan kapalı başlat.
## - Yeni etki eklersen apply_effect ve describe_effect ikisine birden ekle (kural 2).
## - Metinler strings.csv'de İngilizce ve Türkçe (kural 3).
## - Rastgelelik gerekiyorsa kendi RandomNumberGenerator'ını tohumla ve to_save'e yaz (belirlenimcilik).

## Yeni oyun kurulduktan sonra (açılışta ve her Game.new_game'de, AI.reset'ten sonra)
func on_new_game() -> void:
	pass

## Oyuncu ülkesini seçip oyuna girdikten sonra (World.start_game)
func on_game_started(_player: String) -> void:
	pass

## Her oyun günü: AI'dan sonra, oyun sonu denetiminden önce
func on_day() -> void:
	pass

## Her oyun saati: Military ve Navy'den sonra
func on_hour() -> void:
	pass

## Her ay başı
func on_month() -> void:
	pass

## Oyun sonu: {} = devam; {"victory": bool, "reason": "<strings.csv anahtarı ya da yerelleştirilmiş metin>"}
func check_end() -> Dictionary:
	return {}

## Skor (oyun sonu ekranı): -1 = varsayılan (zafer puanı toplamı)
func score(_tag: String) -> int:
	return -1

## Kayda yazılacak mod durumu (JSON'a çevrilebilir değerler) ve geri yükleme. JSON sayıları ondalıklıdır: büyük
## tamsayıları (ör. RandomNumberGenerator.state) metin olarak yaz: str(x) / int(str(d["x"])).
func to_save() -> Dictionary:
	return {}

func from_save(_d: Dictionary) -> void:
	pass

## Olay/program etkileri: mod yeni etki anahtarları ekleyebilir ("etkiler": [{"<anahtar>": değer}])
func effect_keys() -> Array[String]:
	return []

func apply_effect(_c: Country, _key: String, _value: Variant) -> void:
	pass

func describe_effect(_key: String, _value: Variant) -> String:
	return ""

## Olay/program şartları: mod yeni şart anahtarları ekleyebilir
func condition_keys() -> Array[String]:
	return []

func check_condition(_c: Country, _key: String, _value: Variant) -> bool:
	return true
