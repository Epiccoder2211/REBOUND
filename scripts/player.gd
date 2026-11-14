extends CharacterBody2D
## The small blue orb. Reports its last safe standing position on death.

signal died(safe_position: Vector2)

const MOVE_SPEED := 310.0
const ACCEL := 1900.0
const GRAVITY := 1320.0
const JUMP_FORCE := -490.0
const COYOTE_TIME := 0.11

var active := true
var dead := false
var safe_position := Vector2.ZERO
var coyote := 0.0
var squash := 0.0

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 14.0
    collision.shape = shape
    add_child(collision)
    safe_position = global_position

func _physics_process(delta: float) -> void:
    if not active or dead:
        return

    if is_on_floor():
        coyote = COYOTE_TIME
        safe_position = global_position
    else:
        coyote = maxf(0.0, coyote - delta)

    var direction := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A):
        direction -= 1.0
    if Input.is_key_pressed(KEY_D):
        direction += 1.0
    direction = clampf(direction, -1.0, 1.0)
    velocity.x = move_toward(velocity.x, direction * MOVE_SPEED, ACCEL * delta)

    if Input.is_action_just_pressed("ui_accept") and coyote > 0.0:
        velocity.y = JUMP_FORCE
        coyote = 0.0
        squash = 0.35

    velocity.y = minf(velocity.y + GRAVITY * delta, 1150.0)
    move_and_slide()

    if is_on_floor():
        safe_position = global_position

    squash = maxf(0.0, squash - delta)
    queue_redraw()
    if global_position.y > 745.0:
        die()

func bounce(power: float = 910.0) -> void:
    if dead or not active:
        return
    velocity.y = -power
    coyote = 0.0
    squash = 0.25

func die() -> void:
    if dead or not active:
        return
    dead = true
    active = false
    died.emit(safe_position)

func respawn(at: Vector2) -> void:
    global_position = at
    velocity = Vector2.ZERO
    safe_position = at
    coyote = 0.0
    dead = false
    active = true

func _draw() -> void:
    var stretch := 1.0 + squash * 0.65
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + squash, 1.0 / stretch))
    draw_circle(Vector2.ZERO, 30.0, Color(0.20, 0.81, 1.0, 0.055))
    draw_circle(Vector2.ZERO, 23.0, Color(0.20, 0.81, 1.0, 0.13))
    draw_circle(Vector2.ZERO, 17.0, Color(0.20, 0.81, 1.0, 0.32))
    draw_circle(Vector2.ZERO, 13.0, Color("5be7ff"))
    draw_circle(Vector2(-4, -5), 5.0, Color(1.0, 1.0, 1.0, 0.78))
