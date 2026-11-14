extends Area2D
## Spawns at the last safe position from the previous attempt.

var phase := 0.0
const LAUNCH_POWER := 930.0
const PAD_SIZE := Vector2(48.0, 18.0)
const PLAYER_RADIUS := 14.0
# One activation per continuous contact, even under a low ceiling.
var _launched_bodies: Dictionary = {}

func _ready() -> void:
    add_to_group("rebound_springs")
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = PAD_SIZE
    collision.shape = shape
    add_child(collision)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    phase += delta * 4.5
    queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    _try_launch(body)

func _try_launch(body: Node2D) -> void:
    try_launch(body)

func release_player(body: Node2D) -> void:
    _launched_bodies.erase(body.get_instance_id())

func try_launch(body: Node2D) -> bool:
    if not body is CharacterBody2D or not body.has_method("bounce"):
        return false
    var player := body as CharacterBody2D
    # Match the player's circle against our rectangle using current positions,
    # independent of the physics server's delayed Area2D overlap notifications.
    # These procedural gameplay nodes use unscaled transforms.
    var local_center := to_local(player.global_position)
    var closest := local_center.clamp(-PAD_SIZE * 0.5, PAD_SIZE * 0.5)
    var touching := local_center.distance_squared_to(closest) <= PLAYER_RADIUS * PLAYER_RADIUS
    if not touching:
        # Release from current geometry, not a delayed body_exited signal,
        # which could otherwise re-arm the pad during a fresh contact.
        release_player(body)
        return false
    if _launched_bodies.has(body.get_instance_id()):
        return false
    if not body.get("active") or body.get("dead"):
        return false
    if player.velocity.y < 0.0 or player.global_position.y > global_position.y:
        return false
    _launched_bodies[body.get_instance_id()] = true
    player.call("bounce", LAUNCH_POWER)
    return true

func _draw() -> void:
    var pulse := (sin(phase) + 1.0) * 0.5
    draw_circle(Vector2(0, -8), 31.0 + pulse * 5.0, Color(1.0, 0.32, 0.77, 0.08))
    draw_rect(Rect2(-25, 2, 50, 10), Color("a638aa"))
    draw_rect(Rect2(-21, -2, 42, 7), Color("ff66d4"))
    for i in range(4):
        var x := -16.0 + i * 10.0
        draw_line(Vector2(x, -2), Vector2(x + 5, -12), Color("ffc6ed"), 3.0)
