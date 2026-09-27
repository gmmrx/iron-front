class_name ArmyGroup
extends RefCounted
## Ordular grubu: birkaç orduyu bir mareşalin komutasında toplar. Mareşalin becerisi gruptaki bütün ordulara yarım
## etkiyle eklenir; grubun duruşu ve cephesi tek seferde bütün ordulara verilebilir.

var id: int
var owner: String
var name: String
var commander := 0              ## mareşal (0 = yok)
