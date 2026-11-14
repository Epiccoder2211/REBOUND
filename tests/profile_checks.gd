extends SceneTree
const MANAGER = preload("res://scripts/progression_manager.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)
func run() -> void:
	var dir := OS.get_environment("REBOUND_TEST_DIR")
	if dir.is_empty(): dir = OS.get_user_data_dir()
	var path := dir.path_join("profile-test-%d.json" % OS.get_process_id())
	var m := MANAGER.new(path)
	m.auto_save = false
	root.add_child(m)
	check(m.display_name == "" and m.lifetime_xp == 0,"old/missing saves receive profile defaults")
	check(not m.set_display_name("   "),"empty nickname rejected")
	check(m.set_display_name("  星 Echo  ") and m.display_name == "星 Echo","Unicode nickname trimmed")
	m.set_display_name("abcdefghijklmnopqrstuvwxyz")
	check(m.display_name.length() == 24,"name length bounded")
	m.set_display_name("星 Echo")
	check(m.start_run() and not m.start_run(),"duplicate run start rejected")
	m.complete_challenge("velocity_trial")
	check(m.lifetime_xp == 40,"challenge grants forty XP")
	m.complete_challenge("velocity_trial")
	check(m.lifetime_xp == 40,"duplicate challenge grants no XP")
	m.complete_comeback("test/comeback")
	m.enter_biome("fracture")
	check(m.lifetime_xp == 120 and m.get_player_level() == 2,"Comeback and biome XP reach level two")
	check("glow_spark" in m.get_owned_cosmetics() and m.equip_cosmetic("glow_spark"),"milestone gift owned and equipable")
	check(not m.purchase_cosmetic("skin_champion"),"milestone gift cannot be bought prematurely")
	m.run_tracker.tick(30)
	m.report_run_distance(1500)
	m.report_run_distance(200)
	check(m.run_tracker.metrics["distance"] == 1500,"route distance never accumulates backtracking")
	m.run_tracker.event("springs",6)
	m.run_tracker.metrics["best_combo"] = 5
	var summary: Dictionary = m.end_run()
	check(summary["xp"] == 260 and m.lifetime_xp == 260,"run and personal record XP are exact")
	check(m.end_run().is_empty() and m.lifetime_xp == 260,"duplicate run ending never awards again")
	check(summary["insights"].size() > 0 and summary["records"].has("distance"),"summary contains measured records and offline insights")
	check(m.get_player_level() == 3 and "trail_star" in m.get_owned_cosmetics(),"level three gift unlocked")
	for i in range(12):
		m.start_run()
		m.end_run()
	check(m.recent_runs.size() == 10 and m.lifetime_xp == 260,"empty runs give no XP and history stays bounded")
	m.set_reduced_motion(true)
	check(m.save_progression(),"extended save writes")
	var loaded := MANAGER.new(path)
	loaded.auto_save = false
	root.add_child(loaded)
	check(loaded.display_name == "星 Echo" and loaded.lifetime_xp == 260 and loaded.reduced_motion,"profile XP and settings persist")
	check(loaded.get_equipped_cosmetics()["glow"] == "glow_spark" and loaded.recent_runs.size() == 10,"gift selection and bounded history persist")
	for pair in [[0,1],[100,2],[250,3],[500,4],[900,5]]:
		loaded.lifetime_xp = pair[0]
		check(loaded.get_player_level() == pair[1],"XP level threshold %d" % pair[0])
	var loader = load("res://ui/menus/loading_screen.gd").new()
	root.add_child(loader)
	var completed: Array = []
	loader.loaded.connect(func(scene): completed.append(scene))
	loader.prepare("res://ui/menus/main_menu.tscn")
	for i in range(120):
		await process_frame
		if not completed.is_empty(): break
	check(completed.size() == 1,"threaded loading completes with actual scene resource")
	loader.queue_free()
	# Exercise onboarding UI and returning profile using a fresh isolated demo save.
	var demo = load("res://ui/menus/polish_demo.tscn").instantiate()
	demo.demo_save_path = path + ".demo"
	root.add_child(demo)
	demo.progression.auto_save = false
	check(demo.profile_menu.visible and paused,"first launch opens onboarding")
	demo.profile_menu._name_input.text = "Nova"
	demo.profile_menu._accept_name()
	check(demo.main_menu.visible and demo.progression.display_name == "Nova","accepted profile reaches main menu")
	demo.main_menu._actions["personalization"].pressed.emit()
	demo.personalization.edit_name_requested.emit()
	demo.profile_menu._name_input.text = "Nova II"
	demo.profile_menu._accept_name()
	check(demo.personalization.visible and not demo.main_menu.visible,"name editing returns to Personalization")
	demo.personalization.close_tree()
	check(demo.main_menu.visible,"nested name editor preserves original main menu parent")
	# Container geometry at target sizes; headless does not assert visual beauty.
	for resolution in [Vector2i(3400,1912),Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720)]:
		root.size = resolution
		await process_frame
		await process_frame
		check(demo.main_menu.size.x >= 1600 and demo.main_menu.size.y >= 900,"logical menu sizing at %s" % resolution)
	demo.main_menu.close_tree()
	print("PROFILE CHECKS: %d passed, %d failed" % [checks-failures,failures])
	quit(0 if failures == 0 else 1)
