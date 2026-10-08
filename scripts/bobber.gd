extends Node3D
## Flota arriba y abajo girando (semillas doradas).

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.2) * 0.04
	rotation.y += delta * 2.0
