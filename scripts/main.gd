extends Node2D
## REBOUND: The Art of Falling Forward
## No external art/assets needed. All platforms and effects are drawn in code.

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const SPRING_SCRIPT = preload("res://scripts/spring.gd")
const GOAL_SCRIPT = preload("res://scripts/goal.gd")
const HAZARD_SCRIPT = preload("res://scripts/hazard.gd")
const MOVING_SCRIPT = preload("res://scripts/moving_platform.gd")
const BACKGROUND_SHADER = preload("res://assets/nebula_background.gdshader")
const PLATFORM_GLOW_SHADER = preload("res://assets/platform_glow.gdshader")
const VIEW := Vector2(1152, 648)
const MAX_SPRINGS := 3

var world: Node2D
var player
var levels: Array = []
var level_index := 0
var state := "menu" # menu, playing, paused, level_done, victory
var level_spawn := Vector2.ZERO
var springs: Array[Node2D] = []
var falls := 0
var total_springs := 0
var elapsed := 0.0
var message_timeout := 0.0
var respawn_timer := 0.0
var background_material: ShaderMaterial
var current_theme: Dictionary = {}

var hud: Control
var info_label: Label
var stats_label: Label
var tip_label: Label
var message_label: Label
var shade: ColorRect
var screen_title: Label
var screen_subtitle: Label
var screen_instruction: Label
var respawn_card: PanelContainer
var respawn_title: Label
var respawn_subtitle: Label

func _ready() -> void:
	levels = make_levels()
	create_background()
	world = Node2D.new()
	world.name = "LevelWorld"
	add_child(world)
	create_ui()
	build_level(0)
	show_menu()

func _process(delta: float) -> void:
	if state == "playing":
		elapsed += delta
	if message_timeout > 0.0:
		message_timeout -= delta
		if message_timeout <= 0.0:
			message_label.text = ""
	if respawn_timer > 0.0:
		respawn_timer = maxf(0.0, respawn_timer - delta)
		respawn_card.modulate.a = minf(1.0, (1.6 - respawn_timer) * 5.0)
		if respawn_timer == 0.0:
			respawn_card.visible = false
	update_stats()

func create_background() -> void:
	var background := ColorRect.new()
	background.name = "NebulaBackground"
	background.size = VIEW
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_material = ShaderMaterial.new()
	background_material.shader = BACKGROUND_SHADER
	background.material = background_material
	add_child(background)

func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)

	hud = Control.new()
	hud.name = "HUD"
	layer.add_child(hud)
	info_label = make_label(hud, "", Vector2(24, 17), Vector2(560, 36), 22, Color("e4f2ff"))
	stats_label = make_label(hud, "", Vector2(775, 20), Vector2(345, 30), 19, Color("ffd67f"))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip_label = make_label(hud, "", Vector2(32, 606), Vector2(1090, 30), 18, Color("aab9df"))
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label = make_label(hud, "", Vector2(185, 62), Vector2(780, 42), 23, Color("ff8cd9"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	shade = ColorRect.new()
	shade.name = "MenuOverlay"
	shade.position = Vector2.ZERO
	shade.size = VIEW
	shade.color = Color(0.035, 0.045, 0.10, 0.91)
	layer.add_child(shade)
	screen_title = make_label(shade, "", Vector2(80, 167), Vector2(992, 95), 70, Color("6deaff"))
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_subtitle = make_label(shade, "", Vector2(120, 295), Vector2(912, 90), 23, Color("d9d7f5"))
	screen_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_instruction = make_label(shade, "", Vector2(130, 480), Vector2(892, 62), 23, Color("ffdc86"))
	screen_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue"])
	screen_title.add_theme_font_override("font", title_font)
	respawn_card = PanelContainer.new()
	respawn_card.position = Vector2(376, 250)
	respawn_card.size = Vector2(400, 132)
	respawn_card.visible = false
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.035, 0.055, 0.12, 0.94)
	card_style.border_color = Color("73eaff")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.set_content_margin_all(18)
	respawn_card.add_theme_stylebox_override("panel", card_style)
	hud.add_child(respawn_card)
	var card_content := VBoxContainer.new()
	card_content.alignment = BoxContainer.ALIGNMENT_CENTER
	card_content.add_theme_constant_override("separation", 7)
	respawn_card.add_child(card_content)
	respawn_title = make_label(card_content, "REBOUND", Vector2.ZERO, Vector2(360, 38), 27, Color("73eaff"))
	respawn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_title.add_theme_font_override("font", title_font)
	respawn_subtitle = make_label(card_content, "A NEW SPRING TAKES SHAPE", Vector2.ZERO, Vector2(360, 28), 14, Color("e4e6ff"))
	respawn_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle_font := SystemFont.new()
	subtitle_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	respawn_subtitle.add_theme_font_override("font", subtitle_font)

func make_label(parent: Node, txt: String, at: Vector2, size: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = txt
	label.position = at
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label

func show_overlay(title: String, subtitle: String, instruction: String) -> void:
	shade.visible = true
	screen_title.text = title
	screen_subtitle.text = subtitle
	screen_instruction.text = instruction
	hud.visible = false
	if is_instance_valid(player):
		player.active = false

func show_menu() -> void:
	state = "menu"
	show_overlay("R E B O U N D", "THE ART OF FALLING FORWARD\n\nWhen you fall, your last safe step becomes a spring.", "PRESS SPACE OR ENTER TO BEGIN")

func resume_game() -> void:
	state = "playing"
	shade.visible = false
	hud.visible = true
	if is_instance_valid(player):
		player.active = true
	message_label.text = ""

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		if state == "playing":
			state = "paused"
			show_overlay("PAUSED", "Every setback is an opportunity.", "PRESS SPACE TO RESUME")
		elif state == "paused":
			resume_game()
		return

	if not key_event.is_action_pressed("ui_accept"):
		return
	match state:
		"menu", "paused":
			resume_game()
		"level_done":
			build_level(level_index + 1)
			resume_game()
		"victory":
			falls = 0
			total_springs = 0
			elapsed = 0.0
			build_level(0)
			resume_game()

func build_level(index: int) -> void:
	level_index = index
	springs.clear()
	for item in world.get_children():
		world.remove_child(item)
		item.queue_free()
	var data: Dictionary = levels[level_index]
	current_theme = data["theme"]
	apply_level_theme(current_theme)
	level_spawn = data["spawn"]

	for rect in data["platforms"]:
		create_platform(rect)
	for platform_data in data["moving"]:
		create_platform(platform_data["rect"], true, platform_data["travel"])
	for rect in data["hazards"]:
		create_hazard(rect)

	player = PLAYER_SCRIPT.new()
	world.add_child(player)
	player.modulate = Color(current_theme["player_tint"])
	player.global_position = level_spawn
	player.safe_position = level_spawn
	player.died.connect(on_player_died)

	var portal = GOAL_SCRIPT.new()
	portal.position = data["goal"]
	world.add_child(portal)
	portal.reached.connect(on_goal_reached)
	tip_label.text = data["tip"]
	message_label.text = ""
	update_stats()

func apply_level_theme(theme: Dictionary) -> void:
	background_material.set_shader_parameter("upper_color", Color(theme["background_upper"]))
	background_material.set_shader_parameter("horizon_color", Color(theme["background_horizon"]))
	background_material.set_shader_parameter("floor_color", Color(theme["background_floor"]))
	background_material.set_shader_parameter("cloud_color", Color(theme["cloud_color"]))
	background_material.set_shader_parameter("first_bloom_color", Color(theme["bloom_one"]))
	background_material.set_shader_parameter("second_bloom_color", Color(theme["bloom_two"]))
	background_material.set_shader_parameter("atmosphere_strength", theme["atmosphere_strength"])
	background_material.set_shader_parameter("star_strength", theme["star_strength"])
	background_material.set_shader_parameter("flow_speed", theme["flow_speed"])

func create_platform(rect: Rect2, moving: bool = false, travel: float = 0.0) -> void:
	var body: PhysicsBody2D
	if moving:
		var moving_body = MOVING_SCRIPT.new()
		moving_body.origin = rect.position + rect.size * 0.5
		moving_body.travel = travel
		body = moving_body
	else:
		body = StaticBody2D.new()
	body.name = "MovingPlatform" if moving else "Platform"
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	var visual := Polygon2D.new()
	var half := rect.size * 0.5
	var side := Polygon2D.new()
	side.polygon = PackedVector2Array([
		Vector2(-half.x, half.y - 2), Vector2(half.x, half.y - 2),
		Vector2(half.x, half.y + 7), Vector2(-half.x, half.y + 7)
	])
	side.color = Color(current_theme["platform_moving_side"] if moving else current_theme["platform_side"])
	body.add_child(side)
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	visual.color = Color(current_theme["platform_moving"] if moving else current_theme["platform_static"])
	body.add_child(visual)
	var highlight := Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, -half.y + 7), Vector2(-half.x, -half.y + 7)
	])
	highlight.color = Color(current_theme["platform_moving_highlight"] if moving else current_theme["platform_highlight"])
	body.add_child(highlight)
	var accent := Polygon2D.new()
	accent.polygon = PackedVector2Array([
		Vector2(-half.x + 12, -half.y + 10), Vector2(half.x - 12, -half.y + 10),
		Vector2(half.x - 12, -half.y + 12), Vector2(-half.x + 12, -half.y + 12)
	])
	accent.color = Color(current_theme["platform_moving_accent"] if moving else current_theme["platform_accent"])
	var glow_material := ShaderMaterial.new()
	glow_material.shader = PLATFORM_GLOW_SHADER
	accent.material = glow_material
	body.add_child(accent)
	for side_sign: float in [-1.0, 1.0]:
		var rivet := Polygon2D.new()
		var rivet_x: float = side_sign * (half.x - 8.0)
		var rivet_y: float = half.y - 6.0
		rivet.polygon = PackedVector2Array([
			Vector2(rivet_x, rivet_y - 2.5), Vector2(rivet_x + 2.5, rivet_y),
			Vector2(rivet_x, rivet_y + 2.5), Vector2(rivet_x - 2.5, rivet_y)
		])
		rivet.color = Color(current_theme["platform_moving_rivet"] if moving else current_theme["platform_rivet"])
		body.add_child(rivet)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)
	])
	outline.width = 1.5
	outline.default_color = Color(current_theme["platform_outline"])
	body.add_child(outline)
	world.add_child(body)

func create_hazard(rect: Rect2) -> void:
	var hazard = HAZARD_SCRIPT.new()
	hazard.position = rect.position + rect.size * 0.5
	hazard.hazard_size = rect.size
	world.add_child(hazard)

func on_player_died(safe_position: Vector2) -> void:
	if state != "playing":
		return
	# Defer physics-body changes so that Area2D collision callbacks stay safe.
	call_deferred("finish_respawn", safe_position)

func finish_respawn(safe_position: Vector2) -> void:
	if state != "playing" or not is_instance_valid(player):
		return
	falls += 1
	var placement := safe_position + Vector2(0, 7)
	var already_here := false
	for spring in springs:
		if is_instance_valid(spring) and spring.position.distance_to(placement) < 42.0:
			already_here = true
			break
	if not already_here:
		var spring = SPRING_SCRIPT.new()
		spring.position = placement
		world.add_child(spring)
		springs.append(spring)
		total_springs += 1
		if springs.size() > MAX_SPRINGS:
			var oldest = springs.pop_front()
			oldest.queue_free()
	player.respawn(level_spawn)
	message_label.text = ""
	message_timeout = 0.0
	respawn_title.text = "REBOUND"
	respawn_subtitle.text = "A NEW SPRING TAKES SHAPE"
	respawn_card.visible = true
	respawn_card.modulate.a = 0.0
	respawn_timer = 1.6

func on_goal_reached() -> void:
	if state == "playing":
		call_deferred("finish_level")

func finish_level() -> void:
	if state != "playing":
		return
	if level_index == levels.size() - 1:
		state = "victory"
		var duration := "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
		show_overlay("YOU BOUNCED BACK.", "Every fall became part of your way forward.\n\nFalls: %d    Springs created: %d    Time: %s" % [falls, total_springs, duration], "PRESS SPACE TO PLAY AGAIN")
	else:
		state = "level_done"
		show_overlay("LEVEL COMPLETE", "You didn't just try again.\nYou built a better way forward.", "PRESS SPACE FOR LEVEL %d" % (level_index + 2))

func update_stats() -> void:
	if levels.is_empty():
		return
	info_label.text = "LEVEL %d / %d   •   %s" % [level_index + 1, levels.size(), levels[level_index]["title"]]
	stats_label.text = "FALLS  %d     SPRINGS  %d" % [falls, total_springs]

func make_levels() -> Array:
	return [
		{
			"title": "THE FIRST FALL",
			"theme": {
				"background_upper": "071329", "background_horizon": "26365c", "background_floor": "121a30",
				"cloud_color": "526fa8", "bloom_one": "46a9d2", "bloom_two": "d69a5e",
				"atmosphere_strength": 0.72, "star_strength": 0.8, "flow_speed": 0.65,
				"platform_static": "354762", "platform_side": "1b2940", "platform_highlight": "718fb9",
				"platform_accent": "82dfff", "platform_rivet": "c2e8ff", "platform_outline": "9abaff80",
				"platform_moving": "435878", "platform_moving_side": "263750", "platform_moving_highlight": "a3b8df",
				"platform_moving_accent": "b1eeff", "platform_moving_rivet": "e1f4ff", "player_tint": "d7f3ff"
			},
			"spawn": Vector2(90, 542),
			"goal": Vector2(940, 490),
			"platforms": [Rect2(0, 570, 360, 78), Rect2(590, 525, 562, 123)],
			"moving": [],
			"hazards": [],
			"tip": "A / D OR ARROWS: MOVE    •    SPACE: JUMP    •    FALL TO CREATE A SPRING"
		},
		{
			"title": "HIGHER THAN BEFORE",
			"theme": {
				"background_upper": "180b22", "background_horizon": "672644", "background_floor": "24112c",
				"cloud_color": "c63b77", "bloom_one": "f05b95", "bloom_two": "ff9b46",
				"atmosphere_strength": 1.45, "star_strength": 0.95, "flow_speed": 2.1,
				"platform_static": "63324f", "platform_side": "381c37", "platform_highlight": "e17098",
				"platform_accent": "ffb26c", "platform_rivet": "ffe0ac", "platform_outline": "ff9cbd99",
				"platform_moving": "633574", "platform_moving_side": "351d49", "platform_moving_highlight": "f097d5",
				"platform_moving_accent": "ffd27b", "platform_moving_rivet": "fff0c1", "player_tint": "ffd5c8"
			},
			"spawn": Vector2(95, 550),
			"goal": Vector2(1040, 244),
			"platforms": [Rect2(0, 578, 355, 70), Rect2(465, 418, 235, 24), Rect2(795, 275, 357, 28)],
			"moving": [],
			"hazards": [],
			"tip": "USE EACH FALL TO BUILD YOUR WAY UP. ONLY THREE SPRINGS STAY AT ONCE."
		},
		{
			"title": "SHATTERED RHYTHM",
			"theme": {
				"background_upper": "041820", "background_horizon": "07535b", "background_floor": "102b38",
				"cloud_color": "078d8a", "bloom_one": "28d6c3", "bloom_two": "ff4058",
				"atmosphere_strength": 1.35, "star_strength": 1.15, "flow_speed": 1.65,
				"platform_static": "20535a", "platform_side": "102f3b", "platform_highlight": "3bb8a9",
				"platform_accent": "76f4d8", "platform_rivet": "c2fff0", "platform_outline": "62ffe1a0",
				"platform_moving": "275c69", "platform_moving_side": "153542", "platform_moving_highlight": "72d8d1",
				"platform_moving_accent": "ff6477", "platform_moving_rivet": "ffd4d9", "player_tint": "baffdf"
			},
			"spawn": Vector2(95, 542),
			"goal": Vector2(1070, 282),
			"platforms": [Rect2(0, 570, 310, 78), Rect2(810, 321, 342, 28)],
			"moving": [{"rect": Rect2(465, 446, 220, 24), "travel": 65.0}],
			"hazards": [Rect2(680, 575, 120, 22)],
			"tip": "MOVING PLATFORMS AND HAZARDS! TIME YOUR BOUNCES."
		},
		{
			"title": "THE FRACTURE",
			"theme": {
				"background_upper": "11132f", "background_horizon": "55518b", "background_floor": "282642",
				"cloud_color": "a599db", "bloom_one": "73eaff", "bloom_two": "ffe08a",
				"atmosphere_strength": 1.2, "star_strength": 1.5, "flow_speed": 1.0,
				"platform_static": "514d73", "platform_side": "302d4c", "platform_highlight": "a49ce0",
				"platform_accent": "ffe58d", "platform_rivet": "fff5c9", "platform_outline": "e0d6ffad",
				"platform_moving": "62567f", "platform_moving_side": "39334f", "platform_moving_highlight": "c5a6ed",
				"platform_moving_accent": "fff4b0", "platform_moving_rivet": "ffffff", "player_tint": "fff0bd"
			},
			"spawn": Vector2(75, 556),
			"goal": Vector2(1080, 163),
			"platforms": [Rect2(0, 585, 282, 63), Rect2(380, 454, 176, 24), Rect2(630, 323, 180, 24), Rect2(896, 194, 256, 25)],
			"moving": [],
			"hazards": [],
			"tip": "THE FINAL CLIMB. EVERY SETBACK BRINGS YOU CLOSER TO THE LIGHT."
		}
	]
