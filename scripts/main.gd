extends Node2D
## REBOUND: The Art of Falling Forward
## No external art/assets needed. All platforms and effects are drawn in code.

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const SPRING_SCRIPT = preload("res://scripts/spring.gd")
const GOAL_SCRIPT = preload("res://scripts/goal.gd")
const HAZARD_SCRIPT = preload("res://scripts/hazard.gd")
const MOVING_SCRIPT = preload("res://scripts/moving_platform.gd")
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

var hud: Control
var info_label: Label
var stats_label: Label
var tip_label: Label
var message_label: Label
var shade: ColorRect
var screen_title: Label
var screen_subtitle: Label
var screen_instruction: Label

func _ready() -> void:
    levels = make_levels()
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
    update_stats()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color("111529"))
    draw_rect(Rect2(0, 440, VIEW.x, 208), Color("1b1836"))
    draw_rect(Rect2(0, 560, VIEW.x, 88), Color("24203b"))
    # Static stars and distant energy trails, no image files required.
    for i in range(64):
        var x := float((i * 151 + 17) % 1140) + 6.0
        var y := float((i * 79 + 31) % 490) + 12.0
        draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.35, Color(0.64, 0.73, 1.0, 0.25 + float(i % 4) * 0.1))
    for i in range(7):
        var yy := 175.0 + float(i * 64)
        draw_line(Vector2(0, yy), Vector2(VIEW.x, yy - 28), Color(0.45, 0.38, 0.78, 0.045), 2.0)
    # Distant golden core: visual hint at the goal of the world.
    draw_circle(Vector2(1090, 90), 62.0, Color(1, 0.70, 0.25, 0.025))
    draw_circle(Vector2(1090, 90), 40.0, Color(1, 0.70, 0.25, 0.045))

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
    level_spawn = data["spawn"]

    for rect in data["platforms"]:
        create_platform(rect)
    for platform_data in data["moving"]:
        create_platform(platform_data["rect"], true, platform_data["travel"])
    for rect in data["hazards"]:
        create_hazard(rect)

    player = PLAYER_SCRIPT.new()
    world.add_child(player)
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
    visual.polygon = PackedVector2Array([
        Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
        Vector2(half.x, half.y), Vector2(-half.x, half.y)
    ])
    visual.color = Color("413d6c") if moving else Color("353853")
    body.add_child(visual)
    var highlight := Polygon2D.new()
    highlight.polygon = PackedVector2Array([
        Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
        Vector2(half.x, -half.y + 7), Vector2(-half.x, -half.y + 7)
    ])
    highlight.color = Color("a480e6") if moving else Color("6d83af")
    body.add_child(highlight)
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
    message_label.text = "YOU FELL. YOUR PATH GOT STRONGER."
    message_timeout = 2.4

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
            "spawn": Vector2(90, 542),
            "goal": Vector2(940, 490),
            "platforms": [Rect2(0, 570, 360, 78), Rect2(590, 525, 562, 123)],
            "moving": [],
            "hazards": [],
            "tip": "A / D OR ARROWS: MOVE    •    SPACE: JUMP    •    FALL TO CREATE A SPRING"
        },
        {
            "title": "HIGHER THAN BEFORE",
            "spawn": Vector2(95, 550),
            "goal": Vector2(1040, 244),
            "platforms": [Rect2(0, 578, 355, 70), Rect2(465, 418, 235, 24), Rect2(795, 275, 357, 28)],
            "moving": [],
            "hazards": [],
            "tip": "USE EACH FALL TO BUILD YOUR WAY UP. ONLY THREE SPRINGS STAY AT ONCE."
        },
        {
            "title": "SHATTERED RHYTHM",
            "spawn": Vector2(95, 542),
            "goal": Vector2(1070, 282),
            "platforms": [Rect2(0, 570, 310, 78), Rect2(810, 321, 342, 28)],
            "moving": [{"rect": Rect2(465, 446, 220, 24), "travel": 65.0}],
            "hazards": [Rect2(680, 575, 120, 22)],
            "tip": "MOVING PLATFORMS AND HAZARDS! TIME YOUR BOUNCES."
        },
        {
            "title": "THE FRACTURE",
            "spawn": Vector2(75, 556),
            "goal": Vector2(1080, 163),
            "platforms": [Rect2(0, 585, 282, 63), Rect2(380, 454, 176, 24), Rect2(630, 323, 180, 24), Rect2(896, 194, 256, 25)],
            "moving": [],
            "hazards": [],
            "tip": "THE FINAL CLIMB. EVERY SETBACK BRINGS YOU CLOSER TO THE LIGHT."
        }
    ]
