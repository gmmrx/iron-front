extends MapView3D
## Synthetic relief for checking order overlays over sharp mountain ridges.
func _ready() -> void:
	pass

func height_at(p: Vector2) -> float:
	return 58.0 * exp(-pow((p.x - 240.0) / 32.0, 2.0)) + 25.0 * exp(-pow((p.x - 340.0) / 20.0, 2.0)) * (0.65 + 0.35 * sin(p.y * 0.07))
