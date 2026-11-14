extends Area2D
## A small, rotating recovery pad left near a previous fall.

var rotation_speed := 0.0
var orbit_radius := 0.0
var orbit_speed := 0.0
var orbit_phase := 0.0
var glow_color := Color("73eaff")
var bounce_power := 650.0
var pulse := 0.0
var anchor_position := Vector2.ZERO

func _ready() -> void:
	anchor_position = position
	add_to_group("death_bounce_pad")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36.0, 9.0)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotation += rotation_speed * delta
	pulse += delta * 4.0
	orbit_phase += orbit_speed * delta
	position = anchor_position + Vector2(cos(orbit_phase) * orbit_radius, sin(orbit_phase) * orbit_radius * 0.3)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("bounce") and body.velocity.y > 0.0:
		body.bounce(bounce_power)

func _draw() -> void:
	var glow := 0.5 + (sin(pulse) + 1.0) * 0.25
	draw_rect(Rect2(-23.0, -8.0, 46.0, 16.0), Color(glow_color, 0.08 * glow))
	draw_rect(Rect2(-19.0, -5.0, 38.0, 10.0), Color(glow_color, 0.18 * glow))
	draw_rect(Rect2(-18.0, -3.0, 36.0, 7.0), Color("17243a"))
	draw_rect(Rect2(-17.0, -5.0, 34.0, 4.0), glow_color)
	draw_line(Vector2(-12.0, -4.0), Vector2(-7.0, -1.0), Color.WHITE, 1.5)
	draw_line(Vector2(-2.0, -4.0), Vector2(3.0, -1.0), Color.WHITE, 1.5)
	draw_line(Vector2(8.0, -4.0), Vector2(13.0, -1.0), Color.WHITE, 1.5)