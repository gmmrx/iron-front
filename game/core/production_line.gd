class_name ProductionLine
extends RefCounted
## Bir üretim hattı: bir ekipman türü, atanan askeri fabrikalar ve biriken verimlilik.

var equipment: String
var factories: int = 1
var efficiency: float = 0.1
var progress_ic: float = 0.0       ## bir sonraki birime birikmiş IC
var last_output: float = 0.0       ## son gün üretilen birim (tahmini)
var resource_fraction: float = 1.0 ## son gün karşılanan kaynak oranı
