extends CharacterBody2D
const ECHO_VISUAL = preload("res://scripts/echo_visual.gd")
const COSMETIC_CATALOG = preload("res://scripts/cosmetic_catalog.gd")
## The small blue orb. Reports its last safe standing position on death.

signal died(safe_position: Vector2)
signal spring_bounced(perfect: bool, combo: int)
signal dash_started(direction: Vector2)
signal dash_ended()
signal slam_started()
signal slam_landed(position: Vector2, impact_speed: float)
signal combo_changed(combo: int)
signal energy_changed(energy: float)
signal style_points_awarded(points: int, reason: String)
signal jumped()
signal double_jumped()
signal slam_pulse(position: Vector2, radius: float)
signal overdrive_changed(enabled: bool)
signal spring_source_bounced(spring_id: String, perfect: bool)

const MOVE_SPEED := 310.0
const ACCEL := 1900.0
const DECEL := 2400.0
const AIR_ACCEL := 1500.0
const AIR_DECEL := 650.0
const GRAVITY := 1320.0
const JUMP_FORCE := -490.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.12
const JUMP_RELEASE_SPEED := -220.0
const PERFECT_WINDOW_MSEC := 120
const PERFECT_POWER_MULTIPLIER := 1.18
const MAX_BOUNCE_COMBO := 8
const COMBO_TIMEOUT := 3.0
const DEBUG_UNLOCK_ALL_ABILITIES := false
const DOUBLE_JUMP_FORCE := -440.0
const OVERDRIVE_DURATION := 5.0
const OVERDRIVE_SPEED_MULTIPLIER := 1.12
const OVERDRIVE_STYLE_MULTIPLIER := 1.5
const DASH_SPEED := 850.0
const DASH_DURATION := 0.16
const DASH_COAST_TIME := 0.18
const DASH_CHAIN_DISTANCE := 64.0
const SLAM_SPEED := 1250.0
const SLAM_STEERING := 0.3
const SLAM_REWARD_DROP := 48.0
const SLAM_REWARD_SPEED := 700.0
const TRAIL_LIFETIME := 0.18
const MAX_TRAIL_POINTS := 10
const SHOCKWAVE_DURATION := 0.3
const MAX_ENERGY := 100.0
const REBOUND_ENERGY := 8.0
const PERFECT_ENERGY := 16.0
const DASH_CHAIN_ENERGY := 10.0
const SLAM_ENERGY := 12.0
const REBOUND_POINTS := 100
const PERFECT_POINTS := 200
const ABILITY_POINTS := 150

enum MotionState { NORMAL, DASH, SLAM }

var active := true
var dead := false
var safe_position := Vector2.ZERO
var coyote := 0.0
var squash := 0.0
var jump_buffer := 0.0
var bounce_combo := 0
var _combo_remaining := 0.0
var _variable_jump := false
var _input_frame := -1
var _last_jump_press_msec := -1000000
var dash_unlocked := false
var dash_available := true
var slam_unlocked := false
var slam_active: bool:
	get:
		return _motion_state == MotionState.SLAM
# Spring count stays separate for Ved's existing spring_bounced contract.
# The style multiplier counts all qualifying movement actions and bottoms at 1.
var combo_multiplier := 1
var momentum_energy := 0.0
var total_style_points := 0
var _motion_state := MotionState.NORMAL
var _facing := 1.0
var _dash_remaining := 0.0
var _dash_direction := 1.0
var _dash_distance := 0.0
var _dash_chain_eligible := false
var _coast_remaining := 0.0
var _rebound_chain := false
var _slam_start_y := 0.0
var _combo_actions := 0
var _dash_was_held := false
var _slam_was_held := false
var _last_bounce_frame := -1
var _floor_contact_valid := false
var _trail_positions := PackedVector2Array()
var _trail_lives := PackedFloat32Array()
var _shockwave_remaining := 0.0
var _shockwave_position := Vector2.ZERO
var _perfect_flash := 0.0
var double_jump_unlocked := false
var double_jump_available := true
var perfect_window_msec := PERFECT_WINDOW_MSEC
var dash_distance_multiplier := 1.0
var energy_gain_multiplier := 1.0
var coin_magnet_radius := 0.0
var slam_pulse_radius := 0.0
var overdrive_unlocked := false
var overdrive_active: bool:
	get:
		return _overdrive_remaining > 0.0
# Starter-compatible default. Endless worlds may disable this and call die()
# from their own kill zones, or update fall_boundary_y per active terrain.
var fall_boundary_enabled := true
var fall_boundary_y := 745.0
var _overdrive_remaining := 0.0
var _overdrive_was_held := false
var _resume_input_guard := false
var _double_jump_flash := 0.0
var _double_dash_chain := false
var _double_dash_ready := false
var _double_chain_remaining := 0.0
var _spring_source_id := ""
var cosmetic_appearance := COSMETIC_CATALOG.appearance({})
var _visual_phase := 0.0
var reduced_visual_motion := false

func apply_cosmetics(appearance: Dictionary) -> void:
	# Presentation-only snapshot: no changes to velocity, collider, or abilities.
	cosmetic_appearance = appearance.duplicate(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_visual_motion:
		_visual_phase = fmod(_visual_phase + delta, TAU * 10.0)
	queue_redraw()

func apply_progression(nodes: Dictionary) -> void:
	# Assign from baselines, never multiply existing values when loading/rebinding.
	double_jump_unlocked = DEBUG_UNLOCK_ALL_ABILITIES or nodes.has("double_jump")
	dash_unlocked = DEBUG_UNLOCK_ALL_ABILITIES or nodes.has("air_dash")
	slam_unlocked = DEBUG_UNLOCK_ALL_ABILITIES or nodes.has("ground_slam")
	perfect_window_msec = 150 if nodes.has("spring_mastery") else PERFECT_WINDOW_MSEC
	dash_distance_multiplier = 1.15 if nodes.has("dash_amplifier") else 1.0
	energy_gain_multiplier = 1.25 if nodes.has("energy_booster") else 1.0
	coin_magnet_radius = 90.0 if nodes.has("coin_magnet") else 0.0
	slam_pulse_radius = 120.0 if nodes.has("slam_pulse") else 0.0
	overdrive_unlocked = nodes.has("echo_overdrive")
	if not overdrive_unlocked:
		_end_overdrive()

func suppress_resume_input() -> void:
	# Called when closing overlays. Require button release before jump/abilities;
	# horizontal movement resumes immediately. Do not erase velocity or timers.
	_resume_input_guard = true
	jump_buffer = 0.0
	coyote = 0.0
	_last_jump_press_msec = -1000000

func award_style_points(points: int, reason: String) -> void:
	if points <= 0:
		return
	total_style_points += points
	style_points_awarded.emit(points, reason)

func _end_overdrive() -> void:
	if _overdrive_remaining > 0.0:
		_overdrive_remaining = 0.0
		overdrive_changed.emit(false)

func _double_jump() -> void:
	double_jump_available = false
	_double_dash_chain = true
	_double_chain_remaining = COMBO_TIMEOUT
	velocity.y = DOUBLE_JUMP_FORCE
	_variable_jump = true
	jump_buffer = 0.0
	coyote = 0.0
	_double_jump_flash = 0.22
	double_jumped.emit()

func unlock_ability(ability_name: String) -> void:
	# Unlocks last for this player/run, including deaths and respawns.
	match ability_name.to_lower():
		"dash":
			dash_unlocked = true
		"slam":
			slam_unlocked = true
		"double_jump":
			double_jump_unlocked = true

func _reset_combo() -> void:
	bounce_combo = 0
	_combo_remaining = 0.0
	_combo_actions = 0
	_rebound_chain = false
	_double_dash_chain = false
	_double_dash_ready = false
	if combo_multiplier != 1:
		combo_multiplier = 1
		combo_changed.emit(combo_multiplier)

func _set_energy(value: float) -> void:
	var next_energy := clampf(value, 0.0, MAX_ENERGY)
	if next_energy != momentum_energy:
		momentum_energy = next_energy
		energy_changed.emit(momentum_energy)

func _award_action(base_points: int, energy: float, reason: String) -> void:
	_combo_actions += 1
	_combo_remaining = COMBO_TIMEOUT
	var next_multiplier := mini(_combo_actions, MAX_BOUNCE_COMBO)
	if combo_multiplier != next_multiplier:
		combo_multiplier = next_multiplier
		combo_changed.emit(combo_multiplier)
	_set_energy(momentum_energy + energy * energy_gain_multiplier)
	var points := roundi(base_points * combo_multiplier * (OVERDRIVE_STYLE_MULTIPLIER if overdrive_active else 1.0))
	award_style_points(points, reason)

func _start_dash(direction: float) -> void:
	_motion_state = MotionState.DASH
	dash_available = false
	_dash_direction = direction if direction != 0.0 else _facing
	_facing = _dash_direction
	_dash_remaining = DASH_DURATION * dash_distance_multiplier
	_dash_distance = 0.0
	_dash_chain_eligible = _rebound_chain and _combo_remaining > 0.0
	_variable_jump = false
	coyote = 0.0
	jump_buffer = 0.0
	velocity = Vector2(_dash_direction * DASH_SPEED, 0.0)
	dash_started.emit(Vector2(_dash_direction, 0.0))

func _end_dash(reward: bool = true) -> void:
	if _motion_state != MotionState.DASH:
		return
	_motion_state = MotionState.NORMAL
	_coast_remaining = DASH_COAST_TIME
	jump_buffer = 0.0
	if reward and _dash_chain_eligible and _dash_distance >= DASH_CHAIN_DISTANCE:
		_award_action(ABILITY_POINTS, DASH_CHAIN_ENERGY, "rebound_dash")
	if reward and _double_dash_chain and _dash_distance >= DASH_CHAIN_DISTANCE:
		_double_dash_ready = true
	_dash_chain_eligible = false
	dash_ended.emit()

func _start_slam() -> void:
	_end_dash()
	# Slam landing is its own action, not also a "safe dash landing" reward.
	_double_dash_chain = false
	_double_dash_ready = false
	_motion_state = MotionState.SLAM
	_coast_remaining = 0.0
	_slam_start_y = global_position.y
	_variable_jump = false
	coyote = 0.0
	jump_buffer = 0.0
	velocity.y = SLAM_SPEED
	squash = 0.12
	slam_started.emit()

func _finish_slam(impact_speed: float) -> void:
	_motion_state = MotionState.NORMAL
	jump_buffer = 0.0
	squash = 0.55
	_shockwave_position = global_position + Vector2(0.0, 14.0)
	_shockwave_remaining = SHOCKWAVE_DURATION
	if global_position.y - _slam_start_y >= SLAM_REWARD_DROP and impact_speed >= SLAM_REWARD_SPEED:
		_award_action(ABILITY_POINTS, SLAM_ENERGY, "slam_landing")
		if slam_pulse_radius > 0.0:
			slam_pulse.emit(global_position, slam_pulse_radius)
	slam_landed.emit(global_position, impact_speed)

func _reset_motion() -> void:
	# No rewards for cancellation by death/respawn.
	_end_dash(false)
	_motion_state = MotionState.NORMAL
	dash_available = true
	double_jump_available = true
	_double_dash_chain = false
	_double_dash_ready = false
	_double_jump_flash = 0.0
	_end_overdrive()
	_coast_remaining = 0.0
	_variable_jump = false
	_trail_positions.clear()
	_trail_lives.clear()
	_shockwave_remaining = 0.0
	_perfect_flash = 0.0

func _update_effects(delta: float) -> void:
	for i in range(_trail_lives.size() - 1, -1, -1):
		_trail_lives[i] -= delta
		if _trail_lives[i] <= 0.0:
			_trail_lives.remove_at(i)
			_trail_positions.remove_at(i)
	if _motion_state == MotionState.DASH:
		if _trail_positions.size() >= MAX_TRAIL_POINTS:
			_trail_positions.remove_at(0)
			_trail_lives.remove_at(0)
		_trail_positions.append(global_position)
		_trail_lives.append(TRAIL_LIFETIME)
	_shockwave_remaining = maxf(0.0, _shockwave_remaining - delta)
	_perfect_flash = maxf(0.0, _perfect_flash - delta)
	_double_jump_flash = maxf(0.0, _double_jump_flash - delta)

func _sample_jump_input() -> void:
	# Springs can call bounce before our physics callback. Sample once per tick
	# so contact-frame input works regardless of scene-tree processing order.
	var frame := Engine.get_physics_frames()
	if _input_frame == frame:
		return
	_input_frame = frame
	if not _resume_input_guard and Input.is_action_just_pressed("ui_accept"):
		jump_buffer = JUMP_BUFFER_TIME
		_last_jump_press_msec = Time.get_ticks_msec()

func _check_springs() -> bool:
	var launched := false
	# Query current geometry before jumping and after moving. Area overlap lists
	# update later and alone can let a buffered landing jump steal a rebound.
	for spring in get_tree().get_nodes_in_group("rebound_springs"):
		if spring.has_method("try_launch"):
			_spring_source_id = str(spring.get_meta("source_id", ""))
			if spring.call("try_launch", self):
				launched = true
			_spring_source_id = ""
	return launched

func _ready() -> void:
	if DEBUG_UNLOCK_ALL_ABILITIES:
		unlock_ability("dash")
		unlock_ability("slam")
		unlock_ability("double_jump")
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	add_child(collision)
	safe_position = global_position

func _physics_process(delta: float) -> void:
	# Poll edges without editing InputMap. Holding a key through pause must not
	# activate an ability on resume, and OS key-repeat cannot retrigger it.
	var dash_held := Input.is_physical_key_pressed(KEY_SHIFT)
	var slam_held := Input.is_physical_key_pressed(KEY_X)
	var overdrive_held := Input.is_physical_key_pressed(KEY_E)
	var overdrive_pressed := overdrive_held and not _overdrive_was_held
	var dash_pressed := dash_held and not _dash_was_held
	var slam_pressed := slam_held and not _slam_was_held
	_dash_was_held = dash_held
	_slam_was_held = slam_held
	_overdrive_was_held = overdrive_held
	if _resume_input_guard:
		dash_pressed = false
		slam_pressed = false
		overdrive_pressed = false
		if not dash_held and not slam_held and not overdrive_held and not Input.is_action_pressed("ui_accept"):
			_resume_input_guard = false
	if not active or dead:
		jump_buffer = 0.0
		coyote = 0.0
		_last_jump_press_msec = -1000000
		return
	_combo_remaining = maxf(0.0, _combo_remaining - delta)
	if _combo_remaining == 0.0 and _combo_actions > 0:
		_reset_combo()
	_double_chain_remaining = maxf(0.0, _double_chain_remaining - delta)
	if _double_chain_remaining == 0.0:
		_double_dash_chain = false
		_double_dash_ready = false
	_coast_remaining = maxf(0.0, _coast_remaining - delta)
	if overdrive_active:
		_overdrive_remaining = maxf(0.0, _overdrive_remaining - delta)
		if not overdrive_active:
			overdrive_changed.emit(false)
	if overdrive_pressed and overdrive_unlocked and not overdrive_active and momentum_energy >= MAX_ENERGY:
		_set_energy(0.0)
		_overdrive_remaining = OVERDRIVE_DURATION
		overdrive_changed.emit(true)

	# Floor contact describes the previous move; a spring may already have
	# launched us since then. Do not restore coyote time during that launch.
	var grounded := _floor_contact_valid and is_on_floor() and velocity.y >= 0.0
	if grounded:
		coyote = COYOTE_TIME
		safe_position = global_position
		dash_available = true
		double_jump_available = true
	else:
		coyote = maxf(0.0, coyote - delta)

	# Treat WASD and arrows as aliases so mixed opposing keys cancel equally.
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var direction := float(right) - float(left)
	if direction != 0.0:
		_facing = direction

	jump_buffer = maxf(0.0, jump_buffer - delta)
	_sample_jump_input()
	var spring_launched := _check_springs()
	var bounced_this_tick := spring_launched or _last_bounce_frame == Engine.get_physics_frames()
	# Springs always win. Slam can interrupt a dash; dash cannot interrupt slam.
	if not grounded and not bounced_this_tick:
		if slam_pressed and slam_unlocked and not slam_active:
			_start_slam()
		elif dash_pressed and dash_unlocked and dash_available and _motion_state == MotionState.NORMAL:
			_start_dash(direction)

	if _motion_state != MotionState.DASH:
		var acceleration := ACCEL if grounded else AIR_ACCEL
		if direction == 0.0:
			acceleration = DECEL if grounded else AIR_DECEL
		if slam_active:
			acceleration *= SLAM_STEERING
		elif _coast_remaining > 0.0 and not grounded and (direction == 0.0 or direction == signf(velocity.x)):
			# Let excess dash speed settle gently; reversing remains responsive.
			acceleration *= 0.3
		var target_speed := MOVE_SPEED * (OVERDRIVE_SPEED_MULTIPLIER if overdrive_active else 1.0)
		velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
	# Only ordinary jumps are cut short; releasing Space never cuts a rebound.
	if _variable_jump and not Input.is_action_pressed("ui_accept"):
		velocity.y = maxf(velocity.y, JUMP_RELEASE_SPEED)
		_variable_jump = false

	match _motion_state:
		MotionState.DASH:
			velocity = Vector2(_dash_direction * DASH_SPEED, 0.0)
		MotionState.SLAM:
			velocity.y = SLAM_SPEED
		MotionState.NORMAL:
			# Do not subtract gravity from a spring launch on its contact tick.
			if not bounced_this_tick:
				velocity.y = minf(velocity.y + GRAVITY * delta, 1150.0)
			if not bounced_this_tick and jump_buffer > 0.0 and coyote > 0.0:
				_jump()
			elif not bounced_this_tick and not grounded and double_jump_unlocked and double_jump_available and Input.is_action_just_pressed("ui_accept") and not _resume_input_guard:
				_double_jump()
	var before_move := global_position
	var impact_speed := velocity.y
	move_and_slide()
	_floor_contact_valid = true
	if _motion_state == MotionState.DASH:
		_dash_distance += absf(global_position.x - before_move.x)
	_check_springs()
	if dead or not active:
		return
	if _motion_state == MotionState.DASH:
		_dash_remaining -= delta
		if _dash_remaining <= 0.0 or is_on_wall() or is_on_floor():
			_end_dash()

	if is_on_floor() and velocity.y >= 0.0:
		safe_position = global_position
		dash_available = true
		double_jump_available = true
		if _double_dash_ready:
			_award_action(ABILITY_POINTS, DASH_CHAIN_ENERGY, "double_jump_dash_landing")
		_double_dash_ready = false
		_double_dash_chain = false
		if slam_active:
			_finish_slam(impact_speed)
		elif not grounded:
			squash = maxf(squash, 0.18)
		_rebound_chain = false
		# Consume a buffered press on the landing tick, not one tick later.
		if jump_buffer > 0.0:
			_jump()

	squash = maxf(0.0, squash - delta)
	_update_effects(delta)
	queue_redraw()
	if fall_boundary_enabled and global_position.y > fall_boundary_y:
		die()

func _jump() -> void:
	jumped.emit()
	velocity.y = JUMP_FORCE
	_variable_jump = true
	coyote = 0.0
	jump_buffer = 0.0
	squash = 0.35

func bounce(power: float = 910.0) -> void:
	if dead or not active:
		return
	# Cancel abilities before applying the launch. No later dash/slam branch
	# may overwrite this velocity, including stale floor contact this tick.
	_end_dash()
	_motion_state = MotionState.NORMAL
	dash_available = true
	double_jump_available = true
	_double_dash_chain = false
	_double_dash_ready = false
	_last_bounce_frame = Engine.get_physics_frames()
	_sample_jump_input()
	var perfect := Time.get_ticks_msec() - _last_jump_press_msec <= perfect_window_msec
	velocity.y = -power * (PERFECT_POWER_MULTIPLIER if perfect else 1.0)
	_variable_jump = false
	_last_jump_press_msec = -1000000
	bounce_combo = mini(bounce_combo + 1, MAX_BOUNCE_COMBO)
	_award_action(PERFECT_POINTS if perfect else REBOUND_POINTS,
		PERFECT_ENERGY if perfect else REBOUND_ENERGY,
		"perfect_rebound" if perfect else "spring_bounce")
	_rebound_chain = true
	coyote = 0.0
	jump_buffer = 0.0
	squash = 0.4 if perfect else 0.25
	_perfect_flash = 0.22 if perfect else 0.0
	queue_redraw()
	spring_bounced.emit(perfect, bounce_combo)
	if not _spring_source_id.is_empty():
		spring_source_bounced.emit(_spring_source_id, perfect)

func die() -> void:
	if dead or not active:
		return
	dead = true
	active = false
	_reset_motion()
	_reset_combo()
	_set_energy(0.0)
	jump_buffer = 0.0
	_last_jump_press_msec = -1000000
	died.emit(safe_position)

func respawn(at: Vector2) -> void:
	global_position = at
	# Teleporting does not clear CharacterBody2D's previous floor result.
	_floor_contact_valid = false
	velocity = Vector2.ZERO
	safe_position = at
	coyote = 0.0
	jump_buffer = 0.0
	_variable_jump = false
	_last_jump_press_msec = -1000000
	_reset_motion()
	_reset_combo()
	_set_energy(0.0)
	_last_bounce_frame = -1
	for spring in get_tree().get_nodes_in_group("rebound_springs"):
		if spring.has_method("release_player"):
			spring.call("release_player", self)
	squash = 0.0
	dead = false
	active = true
	queue_redraw()

func _draw() -> void:
	if overdrive_active:
		draw_circle(Vector2.ZERO, 29.0 + sin(_visual_phase*4.0)*1.5, Color(1.0, 0.78, 0.25, 0.08))
		for i in range(3):
			var angle := _visual_phase * 1.4 + float(i) * TAU/3.0
			draw_arc(Vector2.ZERO, 22.0, angle, angle+1.25, 18, Color(1.0,0.85,0.4,0.7),1.6,true)
			draw_circle(Vector2.from_angle(angle)*26.0,1.4,Color("ffe8ab"))
	if _double_jump_flash > 0.0:
		draw_arc(Vector2(0, 12), 12.0 + (0.22 - _double_jump_flash) * 65.0, 0.0, PI, 20,
			Color(0.3, 0.95, 1.0, _double_jump_flash * 3.0), 2.0, true)
		for i in range(4):
			var offset := Vector2.from_angle(float(i)*PI/3.0) * (14.0+(0.22-_double_jump_flash)*70.0)
			draw_circle(Vector2(0,10)+offset,1.5,Color(0.65,1.0,1.0,_double_jump_flash*3.0))
	# Effects use world positions so they stay behind as the player moves.
	for i in range(_trail_positions.size()):
		var alpha := _trail_lives[i] / TRAIL_LIFETIME * 0.22
		var trail: Color = cosmetic_appearance.get("trail", Color("63eaff"))
		var at := to_local(_trail_positions[i])
		draw_circle(at, 11.0, Color(trail, alpha))
		if cosmetic_appearance.get("trail_style") == "trail_gold":
			draw_circle(at + Vector2(0, sin(float(i) * 2.0) * 6.0), 2.0, Color(trail, alpha * 2.5))
		elif cosmetic_appearance.get("trail_style") == "trail_nebula" and i > 0:
			draw_line(to_local(_trail_positions[i - 1]), at, Color(trail, alpha * 1.7), 2.0, true)
	if _shockwave_remaining > 0.0:
		var progress := 1.0 - _shockwave_remaining / SHOCKWAVE_DURATION
		var center := to_local(_shockwave_position)
		var tint := Color(0.4, 0.95, 1.0, 0.6 * (1.0 - progress))
		draw_arc(center, 8.0 + progress * 52.0, PI, TAU, 24, tint, 2.0, true)
		for i in range(6):
			var angle := PI + float(i) * PI / 5.0
			var offset := Vector2.from_angle(angle) * progress * 42.0
			draw_circle(center + offset, 2.0 * (1.0 - progress), tint)
	if _perfect_flash > 0.0:
		draw_circle(Vector2.ZERO, 24.0, Color(1.0,0.8,0.35,_perfect_flash*0.45))
		draw_arc(Vector2.ZERO, 24.0 + (0.22 - _perfect_flash) * 65.0,
			0.0, TAU, 32, Color(1.0, 0.8, 0.4, _perfect_flash * 2.0), 2.0, true)
	var stretch := 1.0 + squash * 0.65
	var speed_stretch := clampf(absf(velocity.x) / DASH_SPEED, 0.0, 1.0) * 0.12
	var body_scale := Vector2(1.0 + squash + speed_stretch, 1.0 / stretch)
	if slam_active:
		body_scale = Vector2(0.8, 1.28)
		draw_line(Vector2(-7,-27),Vector2(0,-21),Color(0.6,0.9,1.0,0.35),1.6,true)
		draw_line(Vector2(7,-27),Vector2(0,-21),Color(0.6,0.9,1.0,0.35),1.6,true)
	elif _motion_state == MotionState.DASH:
		body_scale = Vector2(1.3,0.8)
	draw_set_transform(Vector2.ZERO, 0.0, body_scale)
	ECHO_VISUAL.draw_echo(self, Vector2.ZERO, 13.0, cosmetic_appearance, _visual_phase)
