extends "res://ui/echo_nexus/echo_nexus.gd"
## Requests navigation through signals. The host owns journey/restart/quit.
signal journey_requested()
signal nexus_requested()
signal personalization_requested()
signal help_requested()
signal settings_requested()
var first_welcome := false
var _welcome: Label
var _xp: ProgressBar
signal restart_requested()
signal quit_to_menu_requested()
signal quit_requested()
@export_enum("main", "pause", "help") var menu_kind := "main"
var _actions: Dictionary = {}
var _hero: Control
const PREVIEW = preload("res://ui/shared/orb_preview.gd")

func _ready() -> void:
	hotkey_enabled = false
	super._ready()

func _build() -> void:
	add_child(COSMOS.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_"+side, 44)
	add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	column.add_child(_label("BOUNCE BACK  /  AN ENDLESS JOURNEY",12))
	column.add_child(_label("REBOUND\nEVOLUTION" if menu_kind == "main" else ("A MOMENT\nTO BREATHE" if menu_kind == "pause" else "FIND YOUR\nMOMENTUM"), 38))
	column.add_child(_label("Fall. Adapt. Evolve. Rise.",17))
	column.add_child(HSeparator.new())
	if menu_kind == "main":
		_welcome = _label("",16)
		column.add_child(_welcome)
		_xp = ProgressBar.new()
		_xp.custom_minimum_size.y = 10
		_xp.show_percentage = false
		column.add_child(_xp)
	if menu_kind == "main":
		_action(column,"start","Start Journey",func(): journey_requested.emit())
		_action(column,"nexus","Echo Nexus",func(): nexus_requested.emit())
		_action(column,"personalization","Personalization",func(): personalization_requested.emit())
		_action(column,"help","How to Play",func(): help_requested.emit())
		_action(column,"settings","Settings",func(): settings_requested.emit())
		_action(column,"quit","Quit",func(): quit_requested.emit())
	elif menu_kind == "pause":
		_action(column,"resume","Resume Journey",close_tree)
		_action(column,"nexus","Echo Nexus",func(): nexus_requested.emit())
		_action(column,"personalization","Personalization",func(): personalization_requested.emit())
		_action(column,"restart","Restart from Safe Ground",func(): restart_requested.emit())
		_action(column,"menu","Quit to Menu",func(): quit_to_menu_requested.emit())
	else:
		column.custom_minimum_size.x = 620
		for section in [["BASIC CONTROLS", "Move   A / D or arrows", "Jump   Space • hold for height", "Perfect Rebound   Space just before a spring", "Echo Nexus   Tab • Personalization   C"], ["ADVANCED · UNLOCK THROUGH PLAY", "Double Jump   Space again in midair", "Air Dash   Shift", "Ground Slam   X", "Overdrive   E • 100 energy"]]:
			for index in range(section.size()):
				var card := _label(section[index], 13 if index == 0 else 16)
				card.modulate = Color("86c5d8") if index == 0 else Color.WHITE
				column.add_child(card)
		_action(column,"back","Return",close_tree)
	_hero = PREVIEW.new()
	_hero.custom_minimum_size.x = 260
	_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hero)

func _action(parent: Node, id: String, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	_actions[id] = button

func _refresh() -> void:
	if _hero != null and is_instance_valid(progression):
		_hero.appearance = progression.get_cosmetic_appearance()
		if _welcome != null:
			_welcome.text = ("Welcome, %s\nLevel %d · %d / %d XP" if first_welcome else "Welcome back, %s\nLevel %d · %d / %d XP") % [progression.display_name,progression.get_player_level(),progression.lifetime_xp,progression.xp_threshold(progression.get_player_level()+1)]
			_xp.max_value = progression.xp_threshold(progression.get_player_level()+1)
			_xp.value = progression.lifetime_xp

func open_tree() -> void:
	super.open_tree()
	if not _actions.is_empty():
		_actions.values()[0].grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if menu_kind != "main":
				close_tree()
		KEY_TAB: nexus_requested.emit()
		KEY_C: personalization_requested.emit()
		_: return
	get_viewport().set_input_as_handled()
