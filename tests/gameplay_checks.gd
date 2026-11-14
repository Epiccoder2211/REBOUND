extends SceneTree
# Deterministic movement regression arena; does not load or modify main.gd.
var p
var spring
var failures := 0
var dash_starts := 0
var dash_ends := 0
var slam_hits := 0
var last_impact := 0.0
var rebound_events := 0
var last_perfect := false
func check(ok: bool, label: String) -> void:
    if ok:
        print("PASS: ", label)
    else:
        failures += 1
        push_error("FAIL: " + label)
func _initialize() -> void:
    call_deferred("run")
func tick(count: int = 1) -> void:
    for i in range(count):
        await physics_frame
        p._physics_process(1.0 / 60.0)
        await process_frame
func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()
func platform(at: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = at
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    root.add_child(body)
    return body
func run() -> void:
    p = load("res://scripts/player.gd").new()
    root.add_child(p)
    p.set_physics_process(false)
    p.dash_started.connect(func(_direction): dash_starts += 1)
    p.dash_ended.connect(func(): dash_ends += 1)
    p.slam_landed.connect(func(_at, speed): slam_hits += 1; last_impact = speed)
    p.spring_bounced.connect(func(perfect, _combo): rebound_events += 1; last_perfect = perfect)
    platform(Vector2(0, 320), Vector2(2000, 40))
    p.respawn(Vector2(0, 100))
    key(KEY_SHIFT, true)
    key(KEY_X, true)
    await tick()
    check(dash_starts == 0 and not p.slam_active, "abilities locked by default")
    key(KEY_SHIFT, false)
    key(KEY_X, false)
    await tick()
    p.unlock_ability("dash")
    p.unlock_ability("slam")
    key(KEY_SHIFT, true)
    await tick()
    check(dash_starts == 1 and is_equal_approx(p.velocity.x, 850.0) and p.velocity.y == 0.0, "air dash speed and suspended gravity")
    check(not p.dash_available, "dash consumes charge")
    key(KEY_SHIFT, false)
    await tick(11)
    check(dash_ends == 1 and p.velocity.x > 700.0 and p.velocity.y > 0.0, "dash ends with coast and restored gravity")
    key(KEY_SHIFT, true)
    await tick()
    check(dash_starts == 1, "second air dash blocked")
    key(KEY_SHIFT, false)
    await tick(50)
    check(p.is_on_floor() and p.dash_available, "landing recharges dash")
    p.respawn(Vector2(0, 100))
    key(KEY_A, true)
    key(KEY_SHIFT, true)
    await tick()
    check(p.velocity.x < -800.0, "left dash")
    key(KEY_A, false)
    key(KEY_SHIFT, false)
    await tick(12)
    p.respawn(Vector2(0, 100))
    p._jump()
    Input.action_press("ui_accept")
    await tick()
    var held_speed: float = p.velocity.y
    Input.action_release("ui_accept")
    await tick()
    check(held_speed < -400.0 and p.velocity.y > -230.0, "jump release cuts ordinary ascent")
    spring = load("res://scripts/spring.gd").new()
    spring.position = Vector2(0, 200)
    root.add_child(spring)
    p.respawn(Vector2(0, 180))
    p.velocity.y = 100.0
    p.dash_available = false
    check(p._check_springs(), "automatic spring contact")
    check(is_equal_approx(p.velocity.y, -930.0) and p.dash_available, "normal rebound power and dash recharge")
    p.velocity.y = 0.0
    check(not p._check_springs(), "continuous contact cannot retrigger")
    p.global_position = Vector2(300, 100)
    p._check_springs()
    p.global_position = Vector2(0, 180)
    p.velocity.y = 100.0
    p._last_jump_press_msec = Time.get_ticks_msec() - 80
    check(p._check_springs() and last_perfect and p.velocity.y < -1090.0, "80 ms early input gives perfect rebound")
    p._last_jump_press_msec = Time.get_ticks_msec()
    var launch_speed: float = p.velocity.y
    check(not p._check_springs() and p.velocity.y == launch_speed, "late input cannot upgrade or repeat launch")
    p.respawn(Vector2(0, 180))
    p.velocity.y = 100.0
    p._last_jump_press_msec = Time.get_ticks_msec() - 150
    p._check_springs()
    check(not last_perfect and is_equal_approx(p.velocity.y, -930.0), "150 ms old input is ordinary rebound")
    p.respawn(Vector2(500, 100))
    key(KEY_X, true)
    await tick()
    check(p.slam_active and p.velocity.y == 1250.0, "X starts slam at configured speed")
    key(KEY_X, false)
    await tick(15)
    check(not p.slam_active and p.is_on_floor() and slam_hits == 1 and last_impact == 1250.0, "slam ends once on solid floor with impact speed")
    check(p.momentum_energy == 12.0 and p.total_style_points > 0, "slam awards energy and style")
    p.respawn(Vector2(0, 100))
    key(KEY_X, true)
    await tick(5)
    key(KEY_X, false)
    check(not p.slam_active and p.velocity.y < 0.0 and p.dash_available, "slam into spring interrupts with rebound")
    p.respawn(Vector2(500, 100))
    p.bounce(930.0)
    key(KEY_SHIFT, true)
    await tick(12)
    key(KEY_SHIFT, false)
    check(p.combo_multiplier == 2 and p.momentum_energy == 18.0, "rebound plus traveled dash increases multiplier and energy")
    var time_left: float = p._combo_remaining
    p.active = false
    await tick(200)
    check(p._combo_remaining == time_left, "inactive pause freezes combo timeout")
    p.active = true
    p.set_physics_process(false)
    for i in range(12):
        p.bounce(930.0)
    check(p.combo_multiplier == 8 and p.bounce_combo == 8 and p.momentum_energy == 100.0, "multiplier, bounce counter, and energy are capped")
    var style_before: int = p.total_style_points
    p.die()
    check(p.combo_multiplier == 1 and p.bounce_combo == 0 and p.momentum_energy == 0.0 and not p.slam_active, "death clears ability state, combo, and energy")
    p.respawn(Vector2(500, 100))
    check(p.dash_unlocked and p.slam_unlocked and p.dash_available and p.total_style_points == style_before, "respawn preserves unlocks/style and restores dash")
    var wall := platform(Vector2(600, 100), Vector2(20, 300))
    await tick(2)
    key(KEY_D, true)
    key(KEY_SHIFT, true)
    await tick(10)
    key(KEY_SHIFT, false)
    key(KEY_D, false)
    check(p.global_position.x <= 576.1 and p.velocity.x == 0.0, "dash stops at wall without clipping")
    wall.queue_free()
    p.respawn(Vector2(500, 100))
    p.bounce(930.0)
    # Test timeout without introducing landings/death during the wait.
    for i in range(181):
        p.global_position = Vector2(500, 100)
        p.velocity = Vector2.ZERO
        await tick()
    check(p.bounce_combo == 0 and p.combo_multiplier == 1, "three active seconds expire combo")
    p.respawn(Vector2(-45, 180))
    p.velocity.y = 20.0
    key(KEY_D, true)
    key(KEY_SHIFT, true)
    var ends_before: int = dash_ends
    await tick(2)
    key(KEY_SHIFT, false)
    key(KEY_D, false)
    check(p.velocity.y < -800.0 and p.dash_available and dash_ends == ends_before + 1, "spring cleanly interrupts dash and recharges")
    spring.position = Vector2(0, 293)
    p.respawn(Vector2(0, 250))
    p.velocity.y = 500.0
    Input.action_press("ui_accept")
    await tick(5)
    Input.action_release("ui_accept")
    check(p.velocity.y < -900.0 and last_perfect, "buffered jump on spring landing remains a perfect rebound")
    p.respawn(Vector2(500, 270))
    p.velocity.y = 500.0
    Input.action_press("ui_accept")
    await tick(2)
    Input.action_release("ui_accept")
    check(p.velocity.y < -400.0, "ordinary landing still consumes buffered jump")
    p.respawn(Vector2(990, 286))
    await tick(2)
    p.global_position.x = 1200.0
    await tick()
    Input.action_press("ui_accept")
    await tick()
    Input.action_release("ui_accept")
    check(p.velocity.y < -400.0, "coyote jump survives walking off floor")
    p.respawn(Vector2(500, 100))
    key(KEY_D, true)
    key(KEY_SHIFT, true)
    await tick()
    key(KEY_SHIFT, false)
    key(KEY_X, true)
    await tick()
    key(KEY_X, false)
    key(KEY_D, false)
    check(p.slam_active and p.velocity.y == 1250.0, "slam cleanly interrupts dash")
    var danger = load("res://scripts/hazard.gd").new()
    danger.position = Vector2(p.global_position.x, 220)
    root.add_child(danger)
    await tick(8)
    check(p.dead, "slam still triggers Area2D hazards")
    danger.queue_free()
    await process_frame
    p.respawn(Vector2(500, 100))
    p.double_jump_unlocked = false
    Input.action_press("ui_accept")
    await tick()
    Input.action_release("ui_accept")
    check(p.velocity.y > 0.0, "locked Double Jump cannot activate")
    await tick()
    p.unlock_ability("double_jump")
    Input.action_press("ui_accept")
    await tick()
    Input.action_release("ui_accept")
    check(p.velocity.y == -440.0 and not p.double_jump_available, "Double Jump uses weaker launch and consumes charge")
    await tick()
    Input.action_press("ui_accept")
    await tick()
    Input.action_release("ui_accept")
    check(p.velocity.y > -440.0, "third airborne jump blocked")
    await tick(60)
    check(p.is_on_floor() and p.double_jump_available, "landing recharges Double Jump")
    p.respawn(Vector2(0, 273))
    p.double_jump_available = false
    p.velocity.y = 100.0
    p._check_springs()
    check(p.double_jump_available and p.velocity.y < -900.0, "spring recharges Double Jump")
    p.apply_progression({"double_jump": true, "air_dash": true, "ground_slam": true,
        "dash_amplifier": true, "spring_mastery": true, "energy_booster": true,
        "slam_pulse": true, "echo_overdrive": true})
    p.respawn(Vector2(500, 100))
    p._set_energy(100.0)
    key(KEY_E, true)
    await tick()
    key(KEY_E, false)
    check(p.overdrive_active and p.momentum_energy == 0.0, "E consumes full energy and starts Overdrive")
    var overdrive_time: float = p._overdrive_remaining
    p.active = false
    await tick(10)
    check(p._overdrive_remaining == overdrive_time, "pause freezes Overdrive")
    p.active = true
    p._overdrive_remaining = 0.01
    await tick()
    check(not p.overdrive_active, "Overdrive expires cleanly")
    p.respawn(Vector2(500, 100))
    p.bounce(930.0)
    check(p.momentum_energy == 10.0, "Energy Booster increases action gain by twenty-five percent")
    p.respawn(Vector2(500, 100))
    p._start_dash(1.0)
    check(is_equal_approx(p._dash_remaining, 0.184), "Dash Amplifier increases duration by fifteen percent")
    p._end_dash(false)
    var pulses: Array = []
    p.slam_pulse.connect(func(at, radius): pulses.append([at, radius]))
    p.respawn(Vector2(500, 100))
    key(KEY_X, true)
    await tick(15)
    key(KEY_X, false)
    check(pulses.size() == 1 and pulses[0][1] == 120.0, "meaningful slam emits exactly one upgraded pulse")
    p.respawn(Vector2(0, 273))
    p.velocity.y = 100.0
    p._last_jump_press_msec = Time.get_ticks_msec() - 140
    p._check_springs()
    check(last_perfect, "Spring Mastery accepts a 140 ms early press")
    var reasons: Array[String] = []
    p.style_points_awarded.connect(func(_points, reason): reasons.append(reason))
    spring.position.x = -1500.0
    p.respawn(Vector2(-500, 100))
    p._double_jump()
    key(KEY_D, true)
    key(KEY_SHIFT, true)
    await tick(13)
    key(KEY_D, false)
    key(KEY_SHIFT, false)
    await tick(50)
    check(reasons.count("double_jump_dash_landing") == 1, "Double Jump dash safe landing rewards exactly once")
    await tick(10)
    check(reasons.count("double_jump_dash_landing") == 1, "standing on floor never repeats chain reward")
    p.respawn(Vector2(500, 740))
    p.fall_boundary_enabled = false
    await tick(10)
    check(not p.dead, "endless world can disable starter fall boundary")
    p.fall_boundary_enabled = true
    p.fall_boundary_y = 900.0
    await tick()
    check(not p.dead, "custom world fall boundary replaces starter height")
    p.global_position.y = 910.0
    await tick()
    check(p.dead, "custom world fall boundary still kills below limit")
    print("CHECKS COMPLETE; failures=", failures)
    quit(0 if failures == 0 else 1)
