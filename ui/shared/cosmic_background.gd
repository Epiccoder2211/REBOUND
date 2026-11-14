extends Control
## Bounded deterministic particles; no textures, random state, or world changes.
var phase := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
	if is_visible_in_tree():
		phase += delta
		queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("070e20"))
	var core := size * Vector2(0.42, 0.48)
	for i in range(6, 0, -1):
		draw_circle(core, 65.0 + float(i) * 54.0, Color(0.18, 0.28, 0.48, 0.014))
	for i in range(95):
		var point := Vector2(float((i * 317 + 53) % 997) / 997.0 * size.x,
			fmod(float((i * 173 + 67) % 991) / 991.0 * size.y + phase * (0.5 + i % 3), maxf(1.0, size.y)))
		var twinkle := 0.22 + (sin(phase * 0.5 + float(i)) + 1.0) * 0.14
		draw_circle(point, 0.65 + float(i % 3) * 0.25, Color(0.7, 0.81, 1.0, twinkle))
		if i % 17 == 0:
			draw_line(point - Vector2(3,0), point + Vector2(3,0), Color(0.7,0.9,1.0,0.18), 1.0)
	draw_set_transform(core, -0.22, Vector2(1.0, 0.55))
	for radius in [220.0, 330.0, 440.0]:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.55,0.7,0.95,0.045), 1.0, true)
	draw_set_transform(Vector2.ZERO)
