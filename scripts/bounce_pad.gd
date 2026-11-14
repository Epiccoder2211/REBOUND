extends Area2D
## A stationary recovery platform left near a previous fall.

signal activated

var glow_color := Color("73eaff")
var bounce_power := 650.0
var pulse := 0.0
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

func randomize_at(at: Vector2, spawn_chance: float = 0.3) -> void:
	position = at
	pad_width = randf_range(34.0, 54.0)
	pad_height = randf_range(7.0, 10.0)
	bounce_power = randf_range(620.0, 760.0)
	activated_once = false
	(collision.shape as RectangleShape2D).size = Vector2(pad_width, pad_height)
	var spawned := randf() < spawn_chance
	visible = false
	set_deferred("monitoring", spawned)
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta * 4.0
	if visible:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if activated_once or not body is CharacterBody2D or not body.has_method("bounce") or body.velocity.y <= 0.0:
		return
	activated_once = true
	body.bounce(bounce_power)
	visible = true
	activated.emit()

func _draw() -> void:
	var half_width := pad_width * 0.5
	var half_height := pad_height * 0.5
	var glow := 0.5 + (sin(pulse) + 1.0) * 0.25
	draw_rect(Rect2(-half_width - 8.0, -half_height - 5.0, pad_width + 16.0, pad_height + 10.0), Color(glow_color, 0.08 * glow))
	draw_rect(Rect2(-half_width - 4.0, -half_height - 2.0, pad_width + 8.0, pad_height + 4.0), Color(glow_color, 0.18 * glow))
	draw_rect(Rect2(-half_width, -half_height, pad_width, pad_height), Color("17243a"))
	draw_rect(Rect2(-half_width + 2.0, -half_height, pad_width - 4.0, maxf(2.0, pad_height * 0.35)), glow_color)
	draw_line(Vector2(-half_width * 0.55, -half_height * 0.35), Vector2(-half_width * 0.35, half_height * 0.2), Color.WHITE, 1.2)
	draw_line(Vector2(half_width * 0.05, -half_height * 0.35), Vector2(half_width * 0.25, half_height * 0.2), Color.WHITE, 1.2)
	draw_line(Vector2(half_width * 0.55, -half_height * 0.35), Vector2(half_width * 0.75, half_height * 0.2), Color.WHITE, 1.2)
