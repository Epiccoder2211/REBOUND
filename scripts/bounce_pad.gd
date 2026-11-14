extends Area2D
## A stationary recovery platform left near a previous fall.

signal activated

const FALL_GRAVITY := 1320.0

var pad_width := 42.0
var pad_height := 8.0
var activated_once := false
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
	visible = false
	set_deferred("monitoring", spawned)

func _on_body_entered(body: Node2D) -> void:
	if activated_once or not body is CharacterBody2D or not body.has_method("bounce") or body.velocity.y <= 0.0:
		return
	activated_once = true
	var fall_distance: float = maxf(0.0, body.global_position.y - body.safe_position.y)
	var bounce_power := sqrt(2.0 * FALL_GRAVITY * fall_distance)
	body.bounce(bounce_power)
	activated.emit()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("bounce"):
		activated_once = false
