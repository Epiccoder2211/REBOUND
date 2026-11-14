extends Area2D
## Pink-red danger strip; falling into it counts as a setback.

var hazard_size := Vector2(110.0, 18.0)

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = hazard_size
    collider.shape = shape
    add_child(collider)
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("die"):
        body.die()

func _draw() -> void:
    draw_rect(Rect2(-hazard_size * 0.5, hazard_size), Color("ec457d"))
    draw_rect(Rect2(-hazard_size * 0.5 + Vector2(0, 4), Vector2(hazard_size.x, 4)), Color("ffacc6"))
