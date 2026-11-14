extends Area2D
## Spawns at the last safe position from the previous attempt.

var phase := 0.0

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(48, 18)
    collision.shape = shape
    add_child(collision)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    phase += delta * 4.5
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("bounce"):
        body.bounce(930.0)

func _draw() -> void:
    var pulse := (sin(phase) + 1.0) * 0.5
    draw_circle(Vector2(0, -8), 31.0 + pulse * 5.0, Color(1.0, 0.32, 0.77, 0.08))
    draw_rect(Rect2(-25, 2, 50, 10), Color("a638aa"))
    draw_rect(Rect2(-21, -2, 42, 7), Color("ff66d4"))
    for i in range(4):
        var x := -16.0 + i * 10.0
        draw_line(Vector2(x, -2), Vector2(x + 5, -12), Color("ffc6ed"), 3.0)
