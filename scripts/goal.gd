extends Area2D
## Tall glowing gate that frames the next level beyond it.

signal reached
var phase := 0.0
var used := false
var color_a := Color("82dfff")
var color_b := Color("ffb26c")

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collider := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 25.0
    collider.shape = shape
    add_child(collider)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    phase += delta * 3.0
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    if not used and body.has_method("bounce"):
        used = true
        reached.emit()

func _draw() -> void:
    var pulse := 1.0 + sin(phase) * 0.10
    var blend := 0.5 + sin(phase * 0.65) * 0.18
    var portal_color := color_a.lerp(color_b, blend)
    var alternate_color := color_b.lerp(color_a, blend)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.82, 1.36))
    draw_circle(Vector2.ZERO, 76.0 * pulse, Color(portal_color.r, portal_color.g, portal_color.b, 0.025))
    draw_circle(Vector2.ZERO, 61.0 * pulse, Color(alternate_color.r, alternate_color.g, alternate_color.b, 0.045))
    draw_circle(Vector2.ZERO, 48.0 * pulse, Color(portal_color.r, portal_color.g, portal_color.b, 0.10))
    draw_circle(Vector2.ZERO, 34.0 * pulse, Color(portal_color.r, portal_color.g, portal_color.b, 0.12))
    draw_arc(Vector2.ZERO, 41.0 * pulse, 0.0, TAU, 72, Color(portal_color.r, portal_color.g, portal_color.b, 0.7), 12.0, true)
    draw_arc(Vector2.ZERO, 32.0 * pulse, 0.0, TAU, 72, Color(alternate_color.r, alternate_color.g, alternate_color.b, 0.95), 5.0, true)
    draw_arc(Vector2(0, -2), 23.0 * pulse, phase * 0.35, phase * 0.35 + TAU * 0.78, 56, Color(1.0, 1.0, 1.0, 0.9), 2.5, true)
    draw_circle(Vector2.ZERO, 12.0 * pulse, Color(portal_color.r, portal_color.g, portal_color.b, 0.22))
    draw_circle(Vector2.ZERO, 7.0, Color("fff5dd"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
