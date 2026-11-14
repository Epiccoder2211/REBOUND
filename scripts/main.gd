extends Node2D
## REBOUND: The Art of Falling Forward
## No external art/assets needed. All platforms and effects are drawn in code.

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const GOAL_SCRIPT = preload("res://scripts/goal.gd")
const HAZARD_SCRIPT = preload("res://scripts/hazard.gd")
const MOVING_SCRIPT = preload("res://scripts/moving_platform.gd")
const BACKGROUND_SHADER = preload("res://assets/nebula_background.gdshader")
const PLATFORM_GLOW_SHADER = preload("res://assets/platform_glow.gdshader")
const VIEW := Vector2(1152, 648)
const PLAYER_SCREEN_X := 90.0
const POWERUPS := [
	{"name": "SKYBOUND", "description": "A high rebound launches you toward the next ledge.", "color": "73eaff", "bounce": 760.0, "dash": 0.0},
	{"name": "COMET DASH", "description": "A strong rebound and forward burst carry you across gaps.", "color": "ff9b67", "bounce": 650.0, "dash": 490.0},
	{"name": "PRISM KICK", "description": "A balanced hop with a quick forward surge.", "color": "dc8cff", "bounce": 700.0, "dash": 380.0}
]

var world: Node2D
var player
var levels: Array = []
var stage_index := 0
var stage_offset := 0.0
var run_start_x := 0.0
var furthest_x := 0.0
var state := "menu" # menu, playing, paused
var level_spawn := Vector2.ZERO
var falls := 0
var elapsed := 0.0
var message_timeout := 0.0
var respawn_timer := 0.0
var background_material: ShaderMaterial
var current_theme: Dictionary = {}
var camera: Camera2D
var current_powerup: Dictionary = {}
var theme_tween: Tween

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
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	camera.make_current()
	create_ui()
	build_level(0)
	show_menu()

func _process(delta: float) -> void:
	if state == "playing":
		elapsed += delta
		if is_instance_valid(player):
			camera.position.x = player.global_position.x + VIEW.x * 0.5 - PLAYER_SCREEN_X
			furthest_x = maxf(furthest_x, player.global_position.x)
	if message_timeout > 0.0:
		message_timeout -= delta
		if message_timeout <= 0.0:
			message_label.text = ""
	if respawn_timer > 0.0:
		respawn_timer = maxf(0.0, respawn_timer - delta)
		respawn_card.modulate.a = minf(1.0, (1.6 - respawn_timer) * 5.0)
		if respawn_timer == 0.0:
			respawn_card.visible = false
			if is_instance_valid(player) and state == "playing":
				player.active = true
				show_powerup_prompt()
	update_stats()

func create_background() -> void:
	var background_layer := CanvasLayer.new()
	background_layer.name = "Background"
	background_layer.layer = -1
	add_child(background_layer)
	var background := ColorRect.new()
	background.name = "NebulaBackground"
	background.size = VIEW
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_material = ShaderMaterial.new()
	background_material.shader = BACKGROUND_SHADER
	background.material = background_material
	background_layer.add_child(background)

func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)

	hud = Control.new()
	hud.name = "HUD"
	layer.add_child(hud)
	info_label = make_label(hud, "", Vector2(24, 17), Vector2(560, 36), 22, Color("e4f2ff"))
	stats_label = make_label(hud, "", Vector2(700, 20), Vector2(420, 30), 17, Color("ffd67f"))
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
	screen_subtitle = make_label(shade, "", Vector2(120, 276), Vector2(912, 155), 21, Color("d9d7f5"))
	screen_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_instruction = make_label(shade, "", Vector2(130, 495), Vector2(892, 62), 23, Color("ffdc86"))
	screen_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue"])
	screen_title.add_theme_font_override("font", title_font)
	respawn_card = PanelContainer.new()
	respawn_card.position = Vector2(336, 244)
	respawn_card.size = Vector2(480, 150)
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
	respawn_title = make_label(card_content, "POWER UP", Vector2.ZERO, Vector2(440, 38), 25, Color("73eaff"))
	respawn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_title.add_theme_font_override("font", title_font)
	respawn_subtitle = make_label(card_content, "A NEW BOOST IS READY", Vector2.ZERO, Vector2(440, 36), 14, Color("e4e6ff"))
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
	show_overlay("R E B O U N D", "THE ENDLESS RUN\n\nEvery stage flows into the next. Reach each portal to set a checkpoint.\nA fall grants a boost—press P whenever you want to use it.\nSKYBOUND • COMET DASH • PRISM KICK", "A / D OR ARROWS: MOVE   •   SPACE: JUMP / BEGIN\nP: USE BOOST AFTER A FALL")

func resume_game() -> void:
	state = "playing"
	shade.visible = false
	hud.visible = true
	if is_instance_valid(player):
		player.active = respawn_timer <= 0.0
		if player.active and not current_powerup.is_empty():
			show_powerup_prompt()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		if state == "playing":
			state = "paused"
			show_overlay("PAUSED", "Keep moving forward.", "PRESS SPACE TO RESUME")
		elif state == "paused":
			resume_game()
		return
	if key_event.keycode == KEY_P:
		if state == "playing":
			activate_powerup()
		return
	if not key_event.is_action_pressed("ui_accept"):
		return
	if state == "menu" or state == "paused":
		resume_game()

func build_level(index: int) -> void:
	stage_index = index
	stage_offset = 0.0
	for item in world.get_children():
		world.remove_child(item)
		item.queue_free()
	player = PLAYER_SCRIPT.new()
	world.add_child(player)
	player.died.connect(on_player_died)
	run_start_x = 0.0
	furthest_x = 0.0
	falls = 0
	current_powerup.clear()
	build_stage(stage_index, stage_offset, false)
	player.global_position = level_spawn
	player.safe_position = level_spawn
	player.modulate = Color(current_theme["player_tint"])
	# Level geometry is authored in a 1152x648 world-space viewport, with the
	# platforms and player around y=450-570. Keep that area inside the camera.
	camera.position = Vector2(level_spawn.x + VIEW.x * 0.5 - PLAYER_SCREEN_X, VIEW.y * 0.5)
	update_stats()

func build_stage(index: int, offset: float, transition: bool) -> void:
	var data: Dictionary = levels[index % levels.size()]
	current_theme = data["theme"]
	apply_level_theme(current_theme, transition)
	level_spawn = data["spawn"] + Vector2(offset, 0.0)
	for rect: Rect2 in data["platforms"]:
		create_platform(Rect2(rect.position + Vector2(offset, 0.0), rect.size))
	for platform_data: Dictionary in data["moving"]:
		var moving_rect: Rect2 = platform_data["rect"]
		create_platform(
			Rect2(moving_rect.position + Vector2(offset, 0.0), moving_rect.size),
			true,
			platform_data["travel"]
		)
	for rect: Rect2 in data["hazards"]:
		create_hazard(Rect2(rect.position + Vector2(offset, 0.0), rect.size))
	var portal = GOAL_SCRIPT.new()
	portal.position = data["goal"] + Vector2(offset, 0.0)
	world.add_child(portal)
	portal.reached.connect(on_goal_reached)
	tip_label.text = data["tip"]
	message_label.text = ""
	update_stats()

func remove_stage_geometry() -> void:
	for item in world.get_children():
		if item != player:
			world.remove_child(item)
			item.queue_free()

func apply_level_theme(theme: Dictionary, animate: bool = false) -> void:
	var color_parameters := {
		"upper_color": "background_upper", "horizon_color": "background_horizon",
		"floor_color": "background_floor", "cloud_color": "cloud_color",
		"first_bloom_color": "bloom_one", "second_bloom_color": "bloom_two"
	}
	var number_parameters := {
		"atmosphere_strength": "atmosphere_strength", "star_strength": "star_strength", "flow_speed": "flow_speed"
	}
	if theme_tween and theme_tween.is_running():
		theme_tween.kill()
	if animate:
		theme_tween = create_tween().set_parallel(true)
		for parameter: String in color_parameters:
			theme_tween.tween_property(background_material, "shader_parameter/" + parameter, Color(theme[color_parameters[parameter]]), 1.15)
		for parameter: String in number_parameters:
			theme_tween.tween_property(background_material, "shader_parameter/" + parameter, theme[number_parameters[parameter]], 1.15)
	else:
		for parameter: String in color_parameters:
			background_material.set_shader_parameter(parameter, Color(theme[color_parameters[parameter]]))
		for parameter: String in number_parameters:
			background_material.set_shader_parameter(parameter, theme[number_parameters[parameter]])
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(theme["background_floor"])
	card_style.border_color = Color(theme["platform_accent"])
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.set_content_margin_all(18)
	respawn_card.add_theme_stylebox_override("panel", card_style)
	respawn_title.add_theme_color_override("font_color", Color(theme["platform_accent"]))
	respawn_subtitle.add_theme_color_override("font_color", Color(theme["platform_highlight"]))

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
	var spike_count := maxi(1, int(rect.size.x / 16.0))
	var spike_width := rect.size.x / float(spike_count)
	for spike_index in range(spike_count):
		var spike := Polygon2D.new()
		spike.position.x = -rect.size.x * 0.5 + spike_width * (float(spike_index) + 0.5)
		spike.polygon = PackedVector2Array([
			Vector2(-spike_width * 0.5, rect.size.y * 0.5),
			Vector2(spike_width * 0.5, rect.size.y * 0.5),
			Vector2(0.0, -rect.size.y * 0.5)
		])
		spike.color = Color("ffacc6")
		hazard.add_child(spike)

func on_player_died(safe_position: Vector2) -> void:
	if state != "playing":
		return
	# Defer physics-body changes so that Area2D collision callbacks stay safe.
	call_deferred("finish_respawn", safe_position)

func finish_respawn(_safe_position: Vector2) -> void:
	if state != "playing" or not is_instance_valid(player):
		return
	falls += 1
	current_powerup = POWERUPS[(falls - 1) % POWERUPS.size()]
	player.respawn(level_spawn)
	player.active = false
	player.modulate = Color(current_powerup["color"])
	message_label.text = ""
	message_timeout = 0.0
	respawn_title.text = "POWER UP: " + current_powerup["name"]
	respawn_subtitle.text = current_powerup["description"]
	respawn_card.visible = true
	respawn_card.modulate.a = 0.0
	respawn_timer = 1.6

func activate_powerup() -> void:
	if state != "playing" or current_powerup.is_empty() or not is_instance_valid(player) or not player.active:
		return
	var direction := signf(Input.get_axis("ui_left", "ui_right"))
	if direction == 0.0:
		direction = 1.0
	player.bounce(current_powerup["bounce"])
	if current_powerup["dash"] > 0.0:
		player.velocity.x = direction * current_powerup["dash"]
	message_label.text = current_powerup["name"] + " BOOST!"
	message_timeout = 1.5
	current_powerup.clear()

func show_powerup_prompt() -> void:
	if current_powerup.is_empty():
		return
	message_label.text = "PRESS P TO USE " + current_powerup["name"]
	message_timeout = 0.0

func on_goal_reached() -> void:
	if state == "playing":
		call_deferred("advance_stage")

func advance_stage() -> void:
	if state != "playing":
		return
	var old_data: Dictionary = levels[stage_index % levels.size()]
	stage_index += 1
	var next_data: Dictionary = levels[stage_index % levels.size()]
	stage_offset += old_data["goal"].x - next_data["spawn"].x + 120.0
	remove_stage_geometry()
	build_stage(stage_index, stage_offset, true)
	player.respawn(level_spawn)
	message_label.text = "CHECKPOINT  •  STAGE %d" % (stage_index + 1)
	message_timeout = 2.0
	update_stats()

func update_stats() -> void:
	if levels.is_empty():
		return
	var data: Dictionary = levels[stage_index % levels.size()]
	info_label.text = "STAGE %d   •   %s" % [stage_index + 1, data["title"]]
	var meters := int(maxf(0.0, furthest_x - run_start_x) / 100.0)
	stats_label.text = "METERS  %05d     FALLS  %d" % [meters, falls]

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
			"goal": Vector2(1055, 418),
			"platforms": [Rect2(0, 570, 300, 78), Rect2(370, 530, 180, 24), Rect2(610, 490, 180, 24), Rect2(850, 450, 302, 198)],
			"moving": [],
			"hazards": [],
			"tip": "A / D OR ARROWS: MOVE    •    SPACE: JUMP    •    REACH THE PORTAL FOR A CHECKPOINT"
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
			"goal": Vector2(1060, 378),
			"platforms": [Rect2(0, 570, 270, 78), Rect2(330, 530, 160, 24), Rect2(540, 490, 160, 24), Rect2(750, 450, 160, 24), Rect2(960, 410, 192, 238)],
			"moving": [],
			"hazards": [Rect2(600, 450, 46, 10)],
			"tip": "SMALL, REGULAR JUMPS ARE ENOUGH. THE GLOWING BEAMS ARE DANGEROUS."
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
			"goal": Vector2(1060, 378),
			"platforms": [Rect2(0, 570, 270, 78), Rect2(330, 530, 160, 24), Rect2(750, 450, 160, 24), Rect2(960, 410, 192, 238)],
			"moving": [{"rect": Rect2(548, 490, 144, 24), "travel": 18.0}],
			"hazards": [Rect2(574, 438, 72, 10), Rect2(810, 410, 42, 10)],
			"tip": "WATCH FOR SPIKE BEAMS ABOVE THE PLATFORMS. LAND, THEN JUMP AGAIN."
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
			"goal": Vector2(1060, 378),
			"platforms": [Rect2(0, 570, 270, 78), Rect2(330, 530, 160, 24), Rect2(540, 490, 160, 24), Rect2(750, 450, 160, 24), Rect2(960, 410, 192, 238)],
			"moving": [],
			"hazards": [Rect2(396, 478, 48, 10), Rect2(852, 398, 48, 10)],
			"tip": "FOUR STAGES REPEAT WITH NEW COLORS. YOUR METER NEVER STOPS CLIMBING."
		}
	]
