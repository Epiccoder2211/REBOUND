extends Area2D
## Glowing golden portal at the end of each level.

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
    draw_circle(Vector2.ZERO, 40.0 * pulse, Color(1.0, 0.78, 0.23, 0.07))
    draw_circle(Vector2.ZERO, 31.0 * pulse, Color(1.0, 0.73, 0.19, 0.17))
    draw_arc(Vector2.ZERO, 23.0 * pulse, 0.0, TAU, 44, Color("ffd375"), 5.0, true)
    draw_circle(Vector2.ZERO, 8.0, Color("ffebae"))
