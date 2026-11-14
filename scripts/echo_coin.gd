extends Area2D
signal picked_up(position: Vector2, amount: int)
## Optional coin component. Ved owns placement/art; no world generation here.
@export var source_id := ""
const MAGNET_SPEED := 220.0
var progression: Node
var _claimed := false
var _phase := 0.0
var _burst_age := 0.0
var _reward_amount := 5
var _magnetized := false
const BURST_DURATION := 0.32

func _process(delta: float) -> void:
	_phase += delta
	if _claimed:
		_burst_age += delta
		if _burst_age >= BURST_DURATION:
			queue_free()
	queue_redraw()

func configure(manager: Node, stable_id: String) -> void:
	progression = manager
	source_id = stable_id

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	if is_instance_valid(progression) and progression.has_claimed_source("coin", source_id):
		_claimed = true
		queue_free()

func _physics_process(delta: float) -> void:
	if _claimed or not is_instance_valid(progression):
		return
	var player: Node = progression.get_bound_player()
	if not is_instance_valid(player) or not player.active or player.dead:
		return
	var radius: float = player.coin_magnet_radius
	_magnetized = radius > 0.0 and global_position.distance_to(player.global_position) <= radius
	if _magnetized:
		global_position = global_position.move_toward(player.global_position, MAGNET_SPEED * delta)
		if global_position.distance_to(player.global_position) <= 20.0:
			_on_body_entered(player)

func _on_body_entered(body: Node2D) -> void:
	if _claimed or not is_instance_valid(progression) or body != progression.get_bound_player():
		return
	if not body.active or body.dead:
		return
	if progression.collect_coin(source_id):
		_claimed = true
		_reward_amount = progression.coin_pickup_reward
		set_deferred("monitoring", false)
		picked_up.emit(global_position, _reward_amount)
		# Keep only the short visual burst alive; physics and reward logic stop.

func _draw() -> void:
	if _claimed:
		var progress := clampf(_burst_age / BURST_DURATION, 0.0, 1.0)
		var color := Color(1.0, 0.85, 0.45, 1.0 - progress)
		draw_arc(Vector2.ZERO, 7.0 + progress * 23.0, 0.0, TAU, 28, color, 1.5, true)
		for i in range(7):
			var at := Vector2.from_angle(float(i) * TAU / 7.0) * (6.0 + progress * 26.0)
			draw_line(at - Vector2(2, 0), at + Vector2(2, 0), color, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-10, -14 - progress * 18), "+%d" % _reward_amount,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		return
	var bob := Vector2(0, sin(_phase * 2.7 + position.x * 0.02) * 2.5)
	draw_circle(bob, 20.0, Color(1.0, 0.74, 0.3, 0.045))
	draw_circle(bob, 13.0, Color(1.0, 0.82, 0.4, 0.1))
	if _magnetized:
		draw_arc(bob, 12.0, _phase * 6.0, _phase * 6.0 + PI, 20, Color(0.4, 0.95, 1.0, 0.6), 1.0, true)
	var spin := 0.4 + absf(cos(_phase * 1.7)) * 0.6
	draw_set_transform(bob, 0.0, Vector2(spin, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color("795326"))
	draw_circle(Vector2(-0.6, -0.6), 7.1, Color("ffce72"))
	draw_arc(Vector2.ZERO, 5.2, 0.0, TAU, 24, Color("fff0b0"), 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-3.5), Vector2(2.5,0), Vector2(0,3.5), Vector2(-2.5,0)]), Color("fff6d4"))
	draw_set_transform(Vector2.ZERO)
	var shimmer := Vector2(cos(_phase * 1.7) * 6.0, -6.0) + bob
	draw_line(shimmer - Vector2(2, 0), shimmer + Vector2(2, 0), Color("d9ffff"), 1.0)
