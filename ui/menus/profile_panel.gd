extends "res://ui/echo_nexus/echo_nexus.gd"
## Shared local onboarding, settings and summary panel; no online account.
signal accepted()
var mode := "profile"
var summary: Dictionary = {}
var _name_input: LineEdit
var _message: Label
var _content: VBoxContainer
var _xp_bar: ProgressBar
func _build() -> void:
	add_child(COSMOS.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size.x = 560
	center.add_child(frame)
	_content = VBoxContainer.new()
	frame.add_child(_content)
	_content.add_child(_label("WELCOME TO REBOUND" if mode == "profile" else ("SETTINGS" if mode == "settings" else "JOURNEY COMPLETE"), 30))
	_message = _label("Every journey begins with a name." if mode == "profile" else "Another step forward.", 17)
	_content.add_child(_message)
	if mode == "profile":
		_name_input = LineEdit.new()
		_name_input.placeholder_text = "What's your name?"
		_name_input.max_length = 24
		_name_input.custom_minimum_size.y = 48
		_name_input.text_submitted.connect(func(_text): _accept_name())
		_content.add_child(_name_input)
		var submit := Button.new()
		submit.text = "Continue"
		submit.pressed.connect(_accept_name)
		_content.add_child(submit)
	elif mode == "settings":
		var motion := CheckButton.new()
		motion.text = "Reduced motion"
		motion.toggled.connect(func(enabled): progression.set_reduced_motion(enabled))
		_content.add_child(motion)
		motion.set_meta("motion_setting",true)
	else:
		_xp_bar = ProgressBar.new()
		_xp_bar.custom_minimum_size.y = 16
		_xp_bar.show_percentage = false
		_content.add_child(_xp_bar)
	var back := Button.new()
	back.text = "Back" if mode != "summary" else "Continue"
	back.visible = mode != "profile"
	back.pressed.connect(close_tree)
	_content.add_child(back)
func _accept_name() -> void:
	if progression.set_display_name(_name_input.text):
		close_tree()
		accepted.emit()
	else:
		_message.text = "Please enter a nickname."
func _refresh() -> void:
	if not is_instance_valid(progression): return
	if mode == "profile":
		_name_input.text = progression.display_name
	elif mode == "settings":
		for child in _content.get_children():
			if child.has_meta("motion_setting"): child.set_pressed_no_signal(progression.reduced_motion)
	elif mode == "summary":
		var lines := "Another step forward.\n\n%d px traveled    •    +%d XP    •    +%d coins\nBest combo ×%d    •    %d Comebacks\n" % [summary.get("distance",0),summary.get("xp",0),summary.get("coins",0),summary.get("best_combo",1),summary.get("comebacks",0)]
		if not summary.get("records",[]).is_empty(): lines += "New records: " + ", ".join(summary["records"]) + "\n"
		lines += "\nECHO INSIGHTS\n" + "\n".join(summary.get("insights",[]))
		for gift in summary.get("gifts",[]): lines += "\nGift unlocked: " + progression.get_cosmetic_definitions()[gift]["name"]
		_message.text = lines
		_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var level: int = progression.get_player_level()
		_xp_bar.max_value = progression.xp_threshold(level+1) - progression.xp_threshold(level)
		var target: float = progression.lifetime_xp-progression.xp_threshold(level)
		_xp_bar.value = target if progression.reduced_motion else maxf(0,target-float(summary.get("xp",0)))
		if not progression.reduced_motion: create_tween().tween_property(_xp_bar,"value",target,0.45)
func open_tree() -> void:
	super.open_tree()
	if mode == "profile" and visible: _name_input.grab_focus()
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mode != "profile": close_tree()
		get_viewport().set_input_as_handled()
