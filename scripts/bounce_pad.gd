extends Area2D
## A stationary recovery platform left near a previous fall.

var glow_color := Color("73eaff")
var bounce_power := 650.0
var pulse := 0.0

func _ready() -> void:
	add_to_group("recovery_bounce_pad")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64.0, 12.0)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse += delta * 4.0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("bounce") and body.velocity.y > 0.0:
		body.bounce(bounce_power)

func _draw() -> void:
	var glow := 0.5 + (sin(pulse) + 1.0) * 0.25
	draw_rect(Rect2(-42.0, -12.0, 84.0, 24.0), Color(glow_color, 0.08 * glow))
	draw_rect(Rect2(-37.0, -9.0, 74.0, 18.0), Color(glow_color, 0.18 * glow))
	draw_rect(Rect2(-32.0, -6.0, 64.0, 12.0), Color("17243a"))
	draw_rect(Rect2(-30.0, -6.0, 60.0, 4.0), glow_color)
	draw_line(Vector2(-22.0, -4.0), Vector2(-15.0, -1.0), Color.WHITE, 1.5)
	draw_line(Vector2(-6.0, -4.0), Vector2(1.0, -1.0), Color.WHITE, 1.5)
	draw_line(Vector2(10.0, -4.0), Vector2(17.0, -1.0), Color.WHITE, 1.5)
