extends Button
var title := ""
var glyph := ""
var tint := Color.WHITE
var state := "locked"
var cost := 0
var affordable := false
var selected := false
var is_core := false
var _hover := 0.0
var _phase := 0.0
var _unlock_flash := 0.0

func _ready() -> void:
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func configure(definition: Dictionary, node_state: String, can_afford: bool, color: Color) -> void:
	title = definition["name"]
	cost = definition["cost"]
	tint = color
	state = node_state
	affordable = can_afford
	is_core = definition["id"] == "basic_movement"
	glyph = ""
	for word in title.split(" "):
		glyph += word.left(1)
	glyph = glyph.left(2)
	queue_redraw()

func illuminate() -> void:
	_unlock_flash = 1.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase += delta
	_hover = move_toward(_hover, 1.0 if is_hovered() or has_focus() else 0.0, delta * 7.0)
	_unlock_flash = maxf(0.0, _unlock_flash - delta * 2.0)
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return point.distance_to(Vector2(size.x * 0.5, 42)) <= 46.0

func _draw() -> void:
	var center := Vector2(size.x * 0.5, 42)
	var radius := (36.0 if is_core else 30.0) + _hover * 2.0
	var active := state == "unlocked"
	var color := tint if active or affordable else tint.darkened(0.55)
	for i in range(3, 0, -1):
		draw_circle(center, radius + i * 5, Color(color, (0.025 + _hover * 0.025 + _unlock_flash * 0.04) if active or affordable else 0.01))
	draw_circle(center, radius + 2, Color("263448"))
	draw_circle(center, radius, Color("101b30"))
	draw_arc(center, radius, 0.0, TAU, 56, Color(color, 0.9), 2.0, true)
	draw_arc(center, radius - 4.0, -PI * 0.8, PI * 0.3, 30, Color(color, 0.25), 1.0, true)
	if active:
		draw_arc(center, radius + 5, _phase * 0.18, _phase * 0.18 + 1.2, 18, Color(tint,0.8), 1.4, true)
	if selected:
		for i in range(4):
			var at := center + Vector2.from_angle(PI / 4.0 + i * PI / 2.0) * (radius + 9.0)
			draw_circle(at, 1.7, Color("f4e4b9"))
	if _unlock_flash > 0.0:
		draw_arc(center, radius + (1.0 - _unlock_flash) * 25.0, 0.0, TAU, 48, Color(tint,_unlock_flash), 2.0, true)
	var font := ThemeDB.fallback_font
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	draw_string(font, center + Vector2(-glyph_size.x * 0.5, 6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color.lightened(0.25))
	var name_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, Vector2((size.x-name_size.x)*0.5, 96), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dce7f7") if active else Color("9eafc8"))
	var subtitle := "ATTUNED" if active else ("%d COINS" % cost if state == "available" else "SEALED")
	var sub_size := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_string(font, Vector2((size.x-sub_size.x)*0.5, 112), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
