extends "res://ui/echo_nexus/echo_nexus_test.gd"
## Presentation host only. Reuses the dedicated arena; never edits main.gd.
const MAIN_MENU = preload("res://ui/menus/main_menu.tscn")
const PAUSE_MENU = preload("res://ui/menus/pause_menu.tscn")
const HELP_MENU = preload("res://ui/menus/how_to_play.tscn")
var main_menu: Control
var pause_menu: Control
var help_menu: Control
var _return_menu: Control
var _menu_stack: Array[Control] = []
var _navigating := false
const PROFILE = preload("res://ui/menus/profile_panel.gd")
var profile_menu: Control
var settings_menu: Control
var summary_menu: Control
var _route_origin := 0.0
var _route_best := 0.0
@export var onboarding_enabled := true


func _ready() -> void:
	open_nexus_on_start = false
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	main_menu = MAIN_MENU.instantiate()
	pause_menu = PAUSE_MENU.instantiate()
	help_menu = HELP_MENU.instantiate()
	for menu in [main_menu,pause_menu,help_menu]:
		layer.add_child(menu)
		menu.bind_progression(progression)
	main_menu.journey_requested.connect(_start_journey)
	profile_menu = PROFILE.new()
	settings_menu = PROFILE.new()
	settings_menu.mode = "settings"
	summary_menu = PROFILE.new()
	summary_menu.mode = "summary"
	for panel in [profile_menu,settings_menu,summary_menu]:
		layer.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.bind_progression(progression)
	profile_menu.accepted.connect(func():
		main_menu.first_welcome = true
		main_menu._refresh()
		if not personalization.visible and not main_menu.visible: main_menu.open_tree()
		_update_hotkeys())
	main_menu.settings_requested.connect(func(): _push(settings_menu,main_menu))
	personalization.edit_name_requested.connect(func(): _push(profile_menu,personalization))
	progression.run_completed.connect(_show_summary)
	main_menu.quit_requested.connect(func(): progression.save_progression(); get_tree().quit())
	main_menu.help_requested.connect(func(): _push(help_menu,main_menu))
	pause_menu.restart_requested.connect(func(): _finish_journey(); player.respawn(Vector2(100,520)))
	pause_menu.quit_to_menu_requested.connect(_finish_journey)
	for menu in [main_menu,pause_menu]:
		menu.nexus_requested.connect(_push.bind(nexus,menu))
		menu.personalization_requested.connect(_push.bind(personalization,menu))
	for child in [nexus,personalization,help_menu,profile_menu,settings_menu,summary_menu]:
		child.closed.connect(_pop)
		child.opened.connect(_update_hotkeys)
	pause_menu.closed.connect(_update_hotkeys)
	get_window().content_scale_size = Vector2i(1700,956)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if onboarding_enabled and progression.display_name.is_empty():
		profile_menu.open_tree()
	else:
		main_menu.open_tree()
	_update_hotkeys()

func _push(child: Control, parent_menu: Control) -> void:
	_navigating = true
	parent_menu.close_tree()
	_return_menu = parent_menu
	_menu_stack.append(parent_menu)
	child.open_tree()
	_navigating = false
	_update_hotkeys()

func _pop() -> void:
	if _navigating:
		return
	if not _menu_stack.is_empty():
		var menu: Control = _menu_stack.pop_back()
		_return_menu = _menu_stack.back() if not _menu_stack.is_empty() else null
		if is_instance_valid(menu): menu.open_tree()
	_update_hotkeys()

func _update_hotkeys() -> void:
	var menu_open := (is_instance_valid(main_menu) and main_menu.visible) or (is_instance_valid(pause_menu) and pause_menu.visible) or (is_instance_valid(help_menu) and help_menu.visible)
	for extra in [profile_menu,settings_menu,summary_menu]:
		menu_open = menu_open or (is_instance_valid(extra) and extra.visible)
	nexus.hotkey_enabled = not menu_open
	personalization.hotkey_enabled = not menu_open

func _input(event: InputEvent) -> void:
	super._input(event)
	if not is_instance_valid(pause_menu) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and not profile_menu.visible and not settings_menu.visible and not summary_menu.visible and not nexus.visible and not personalization.visible and not main_menu.visible and not help_menu.visible and not pause_menu.visible:
		pause_menu.open_tree()
		_update_hotkeys()
		get_viewport().set_input_as_handled()

func _start_journey() -> void:
	main_menu.close_tree()
	_route_origin = player.global_position.x
	_route_best = 0.0
	progression.start_run()
	_update_hotkeys()

func _process(_delta: float) -> void:
	if is_instance_valid(progression) and progression.run_tracker.active and player.active and not player.dead:
		# Demo route: forward world X beyond the start, never accumulated pacing.
		_route_best = maxf(_route_best, player.global_position.x - _route_origin)
		progression.report_run_distance(_route_best)

func _finish_journey() -> void:
	pause_menu.close_tree()
	if progression.end_run().is_empty(): main_menu.open_tree()
	_update_hotkeys()

func _show_summary(summary: Dictionary) -> void:
	summary_menu.summary = summary
	_return_menu = main_menu
	_menu_stack.append(main_menu)
	summary_menu.open_tree()
	_update_hotkeys()
