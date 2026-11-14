extends Area2D
## A stationary recovery platform left near a previous fall.

signal activated

const FALL_GRAVITY := 1320.0
const BOUNCE_HEIGHT_MULTIPLIER := 1.2

var pad_width := 42.0
var pad_height := 8.0
var activated_once := false
var discovered := false
var collision: CollisionShape2D

func _ready() -> void:
	add_to_group("recovery_bounce_pad")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(pad_width, pad_height)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func randomize_at(at: Vector2, spawn_chance: float = 0.3) -> void:
	position = at
	pad_width = randf_range(34.0, 54.0)
	pad_height = randf_range(7.0, 10.0)
	activated_once = false
	(collision.shape as RectangleShape2D).size = Vector2(pad_width, pad_height)
	var spawned := randf() < spawn_chance
	visible = discovered
	set_deferred("monitoring", spawned)

func _on_body_entered(body: Node2D) -> void:
	if activated_once or not body is CharacterBody2D or not body.has_method("bounce") or body.velocity.y <= 0.0:
		return
	activated_once = true
	discovered = true
	visible = true
	queue_redraw()
	var fall_distance: float = maxf(0.0, body.global_position.y - body.safe_position.y)
	var bounce_power := sqrt(2.0 * FALL_GRAVITY * fall_distance) * BOUNCE_HEIGHT_MULTIPLIER
	body.bounce(bounce_power)
	activated.emit()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("bounce"):
		activated_once = false

func _draw() -> void:
	if not discovered:
		return
	draw_circle(Vector2.ZERO, 25.0, Color(0.20, 0.86, 1.0, 0.18))
	draw_rect(Rect2(-pad_width * 0.5, -pad_height * 0.5, pad_width, pad_height), Color("145c78"), true)
	draw_rect(Rect2(-pad_width * 0.5, -pad_height * 0.5, pad_width, pad_height), Color("8df4ff"), false, 2.0)
	draw_line(Vector2(-pad_width * 0.34, 0.0), Vector2(pad_width * 0.34, 0.0), Color("ffffff"), 2.0)
