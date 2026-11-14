extends Area2D
## Tall glowing gate that frames the next level beyond it.

signal reached
var phase := 0.0
var used := false

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
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.82, 1.36))
    draw_circle(Vector2.ZERO, 58.0 * pulse, Color(1.0, 0.78, 0.23, 0.045))
    draw_circle(Vector2.ZERO, 47.0 * pulse, Color(1.0, 0.73, 0.19, 0.10))
    draw_arc(Vector2.ZERO, 39.0 * pulse, 0.0, TAU, 64, Color(1.0, 0.68, 0.22, 0.45), 12.0, true)
    draw_arc(Vector2.ZERO, 31.0 * pulse, 0.0, TAU, 64, Color("ffd375"), 5.0, true)
    draw_arc(Vector2(0, -2), 22.0 * pulse, phase * 0.35, phase * 0.35 + TAU * 0.78, 48, Color("fff0b0"), 2.5, true)
    draw_circle(Vector2.ZERO, 8.0, Color("ffebae"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
