class_name Army
extends RefCounted
## Ordu: tümen grubu, bir cepheye (hedef ülkeyle sınır) atanır; tümenler cephe boyunca kendiliğinden dağılır.
## Duruş: savun (hattı tut) ya da taarruz (cephe bütünlüğünü bozmadan komşu düşman bölgelerine ilerle).

enum Mode { HOLD, ATTACK }

var id: int
var owner: String
var name: String
var enemy := ""                         ## cephe: bu ülkeyle sınır ("" = cephe yok, yerinde bekler)
var mode: Mode = Mode.HOLD
var color := Color(0.95, 0.8, 0.3)
