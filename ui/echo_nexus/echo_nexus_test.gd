extends Node2D
## Dedicated test arena only. Uses a separate save and no starter-map changes.
const MANAGER = preload("res://scripts/progression_manager.gd")
const PLAYER = preload("res://scripts/player.gd")
const COIN = preload("res://scripts/echo_coin.gd")
const SPRING = preload("res://scripts/spring.gd")
const NEXUS = preload("res://ui/echo_nexus/echo_nexus.tscn")
const PERSONALIZATION = preload("res://ui/personalization/personalization.tscn")
const NOTIFICATIONS = preload("res://ui/shared/reward_notifications.gd")
@export var open_nexus_on_start := true
@export var demo_save_path := "user://echo_nexus_demo_v1.json"
var progression: Node
var player: CharacterBody2D
var nexus: Control
var personalization: Control
var _notice: Label
var _grant_serial := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 800)
	progression = MANAGER.new(demo_save_path)
	progression.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(progression)
	player = PLAYER.new()
	player.position = Vector2(100, 520)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	progression.bind_player(player)
	player.died.connect(func(_safe): call_deferred("_respawn"))
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(650, 600)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1300, 40)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child(floor_body)
	var spring := SPRING.new()
	spring.position = Vector2(550, 573)
	spring.set_meta("source_id", "demo/spring/1")
	add_child(spring)
	for i in range(12):
		var coin := COIN.new()
		coin.configure(progression, "demo/coin/%d" % i)
		coin.position = Vector2(200 + i * 65, 552)
		add_child(coin)
	var layer := CanvasLayer.new()
	add_child(layer)
	_notice = Label.new()
	_notice.position = Vector2(20, 16)
	_notice.text = "TEST ARENA • Tab: Nexus • C: Personalization • 1: +100 demo coins • 2: Velocity • 3: Impact\n4: Comeback • 5: Biome • 6: ten coin pickups • 0: reset demo save\nA/D: move • Space: jump • Shift: dash • X: slam • E: Overdrive"
	layer.add_child(_notice)
	nexus = NEXUS.instantiate()
	layer.add_child(nexus)
	nexus.bind_progression(progression)
	personalization = PERSONALIZATION.instantiate()
	layer.add_child(personalization)
	personalization.bind_progression(progression)
	var notifications := NOTIFICATIONS.new()
	layer.add_child(notifications)
	notifications.bind_progression(progression)
	progression.celebration.connect(func(kind, source): print("CELEBRATION ", kind, ": ", source))
	if open_nexus_on_start:
		nexus.open_tree()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			# Unique developer-only grants; never present in the reusable overlay.
			_grant_serial += 1
			progression.add_coins(100, "demo/grant/%d/%d" % [Time.get_unix_time_from_system(), _grant_serial])
		KEY_2: progression.complete_challenge("velocity_trial")
		KEY_3: progression.complete_challenge("impact_trial")
		KEY_4: progression.complete_comeback("demo/comeback/1")
		KEY_5: progression.enter_biome("the_fracture")
		KEY_6:
			for i in range(10):
				progression.collect_coin("demo/simulated_coin/%d" % i)
		KEY_0: progression.development_reset()
		_: return
	get_viewport().set_input_as_handled()

func _respawn() -> void:
	player.respawn(Vector2(100, 520))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1800, 1000), Color("0b1225"))
	draw_rect(Rect2(0, 580, 1300, 40), Color("353853"))
	draw_line(Vector2(0, 580), Vector2(1300, 580), Color("55e6ff"), 3.0)
