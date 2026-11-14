extends RefCounted
## Shared by player and cosmetic preview. Draws only; never touches physics.
static func draw_echo(canvas: CanvasItem, center: Vector2, radius: float, appearance: Dictionary, phase: float) -> void:
	var core: Color = appearance.get("core", Color("68efff"))
	var accent: Color = appearance.get("accent", Color("e0fcff"))
	var glow: Color = appearance.get("glow", core)
	var breath := 1.0 + sin(phase * 1.8) * 0.035
	for i in range(4, 0, -1):
		canvas.draw_circle(center, radius * (1.0 + i * 0.34) * breath,
			Color(glow, 0.018 + (4 - i) * 0.018))
	canvas.draw_circle(center, radius, core.darkened(0.65))
	for layer in range(12,0,-1):
		var t := float(layer)/12.0
		canvas.draw_circle(center + Vector2(-0.15,-0.18)*radius*(1.0-t), radius*t*0.95, core.darkened(t*0.5))
	canvas.draw_circle(center + Vector2(-0.06, -0.09) * radius, radius * 0.7, Color(core,0.24))
	canvas.draw_arc(center, radius * 1.04, phase * 0.3, phase * 0.3 + PI * 1.45,
		32, Color(accent, 0.65), maxf(1.0, radius * 0.07), true)
	canvas.draw_circle(center + Vector2(-0.3, -0.36) * radius, radius * 0.27, Color(accent, 0.8))
	canvas.draw_circle(center + Vector2(-0.37, -0.43) * radius, radius * 0.1, Color.WHITE)
	var style: String = appearance.get("glow_style", "glow_standard")
	if style == "glow_celestial": style = "glow_prism"
	if style == "glow_spark": style = "glow_royal"
	if style == "glow_royal":
		canvas.draw_arc(center, radius * 1.4, phase * 0.45, phase * 0.45 + TAU * 0.8, 40, Color(glow, 0.45), 1.0, true)
		for i in range(2):
			canvas.draw_circle(center + Vector2.from_angle(phase * 0.45 + i * PI) * radius * 1.4, radius * 0.08, accent)
	elif style == "glow_prism":
		for i in range(3):
			var angle := phase * 0.35 + i * TAU / 3.0
			var color := Color.from_hsv(float(i) / 3.0 + 0.15, 0.35, 1.0, 0.5)
			canvas.draw_arc(center, radius * 1.35, angle, angle + 1.1, 14, color, 1.5, true)
