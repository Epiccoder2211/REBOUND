extends Area2D
## A stationary recovery platform left near a previous fall.

var glow_color := Color("73eaff")
var bounce_power := 650.0
var pulse := 0.0

func _ready() -> void:
	add_to_group("death_bounce_pad")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(92.0, 16.0)
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
	draw_rect(Rect2(-54.0, -15.0, 108.0, 30.0), Color(glow_color, 0.08 * glow))
	draw_rect(Rect2(-49.0, -11.0, 98.0, 22.0), Color(glow_color, 0.18 * glow))
	draw_rect(Rect2(-46.0, -8.0, 92.0, 16.0), Color("17243a"))
	draw_rect(Rect2(-44.0, -8.0, 88.0, 5.0), glow_color)
	draw_line(Vector2(-32.0, -6.0), Vector2(-23.0, -1.0), Color.WHITE, 2.0)
	draw_line(Vector2(-12.0, -6.0), Vector2(-3.0, -1.0), Color.WHITE, 2.0)
	draw_line(Vector2(8.0, -6.0), Vector2(17.0, -1.0), Color.WHITE, 2.0)
	draw_line(Vector2(28.0, -6.0), Vector2(37.0, -1.0), Color.WHITE, 2.0)