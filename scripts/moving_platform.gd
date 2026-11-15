extends AnimatableBody2D
## Oscillating platform for level 3.

var origin := Vector2.ZERO
var travel := 85.0
var phase := 0.0

func _physics_process(delta: float) -> void:
	phase += delta * 1.5
	position = origin + Vector2(sin(phase) * travel, 0.0)
