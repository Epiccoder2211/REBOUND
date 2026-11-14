extends Control
const VISUAL = preload("res://scripts/echo_visual.gd")
const CATALOG = preload("res://scripts/cosmetic_catalog.gd")
var appearance := CATALOG.appearance({})
var phase := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if is_visible_in_tree():
		phase += delta
		queue_redraw()
func _draw() -> void:
	var center := size * Vector2(0.52, 0.48)
	var radius := minf(size.x, size.y) * 0.14
	var trail: Color = appearance.get("trail", Color("63eaff"))
	for i in range(5, 0, -1):
		var at := center - Vector2(i * radius * 0.52, -sin(phase + i * 0.3) * radius * 0.18)
		draw_circle(at, radius * 0.55, Color(trail, 0.035 * (6-i)))
		if appearance.get("trail_style") == "trail_nebula":
			draw_line(at, at + Vector2(radius * 0.4,0), Color(trail,0.3), 2.0, true)
		elif appearance.get("trail_style") == "trail_gold":
			draw_circle(at + Vector2(0, radius * 0.55), 2.0, Color(trail,0.5))
	VISUAL.draw_echo(self, center + Vector2(0,sin(phase)*4.0), radius, appearance, phase)
	draw_arc(center, radius * 2.9, PI * 0.1, PI * 0.9, 50, Color(0.5,0.7,0.9,0.1), 1.0, true)
