extends Control
## Reusable overlay. Add under a CanvasLayer and call bind_progression(manager).
## Owns only its own pause transition; it never resumes a previously paused game.
signal opened()
signal closed()
@export var hotkey_enabled := true
const COSMOS = preload("res://ui/shared/cosmic_background.gd")
const PRESENTATION = preload("res://ui/shared/presentation_theme.gd")
const STAR_NODE = preload("res://ui/echo_nexus/constellation_node.gd")
const POSITIONS := {
	"basic_movement": Vector2(385,315), "double_jump": Vector2(205,215),
	"air_dash": Vector2(180,430), "dash_amplifier": Vector2(105,620),
	"perfect_rebound": Vector2(535,115), "spring_mastery": Vector2(755,200),
	"energy_booster": Vector2(825,415), "echo_overdrive": Vector2(750,630),
	"ground_slam": Vector2(445,510), "slam_pulse": Vector2(465,710),
	"coin_magnet": Vector2(135,70)
}
var _sky_phase := 0.0

const COLORS := {"mobility": Color("55e6ff"), "rebound": Color("bd8bff"),
	"impact": Color("ffce72"), "utility": Color("53e6c5")}
var progression: Node
var _definitions: Dictionary = {}
var _buttons: Dictionary = {}
var _selected := "double_jump"
var _was_paused := false
var _was_active := false
var _paused_player: Node
var _canvas: Control
var _balance: Label
var _title: Label
var _description: Label
var _requirements: Label
var _status: Label
var _purchase: Button
var _pulse: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("echo_modal")
	theme = PRESENTATION.make_theme()
	_build()
	hide()
	if is_instance_valid(progression):
		_refresh()

func bind_progression(manager: Node) -> void:
	if is_instance_valid(progression):
		for event in ["coins_changed", "upgrade_purchased", "ability_unlocked", "progression_loaded"]:
			if progression.is_connected(event, _on_progression_changed):
				progression.disconnect(event, _on_progression_changed)
	progression = manager
	if not is_instance_valid(progression):
		return
	_definitions = progression.get_upgrade_definitions()
	for event in ["coins_changed", "upgrade_purchased", "ability_unlocked", "progression_loaded"]:
		progression.connect(event, _on_progression_changed)
	if is_node_ready():
		_refresh()

func _on_progression_changed(_value: Variant = null) -> void:
	if is_node_ready():
		_refresh()

func _build() -> void:
	var background := COSMOS.new()
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var name_label := _label("THE ECHO NEXUS", 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	_balance = _label("0 ECHO COINS", 22)
	_balance.modulate = Color("ffce72")
	heading.add_child(_balance)
	var legend := _label("A CONSTELLATION OF POSSIBILITY     /     Fall. Adapt. Evolve. Rise.", 13)
	legend.modulate = Color("9daed0")
	column.add_child(legend)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(1020, 810)
	_canvas.draw.connect(_draw_connections)
	scroll.add_child(_canvas)
	var frame := PanelContainer.new()
	frame.custom_minimum_size.x = 300
	body.add_child(frame)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	frame.add_child(panel)
	var eyebrow := _label("ATTUNEMENT", 12)
	eyebrow.modulate = Color("9baed0")
	panel.add_child(eyebrow)
	_title = _label("Select an ability", 24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_title)
	_description = _label("", 17)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_description)
	_requirements = _label("", 16)
	_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_requirements)
	_status = _label("", 18)
	panel.add_child(_status)
	_purchase = Button.new()
	_purchase.custom_minimum_size.y = 48
	_purchase.pressed.connect(_purchase_selected)
	panel.add_child(_purchase)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer)
	panel.add_child(_label("CYAN • MOBILITY\nVIOLET • REBOUND\nGOLD • IMPACT\nTEAL • UTILITY", 12))
	var close_button := Button.new()
	close_button.text = "Back"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(close_tree)
	panel.add_child(close_button)
	

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _style(color: Color, unlocked: bool, available: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.13, color.g * 0.13, color.b * 0.13, 1.0)
	style.border_color = color if unlocked or available else Color("37415d")
	style.set_border_width_all(3 if unlocked else 1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(color.r, color.g, color.b, 0.18 if unlocked else 0.0)
	style.shadow_size = 9 if unlocked else 0
	return style

func _refresh() -> void:
	if not is_instance_valid(progression):
		return
	_balance.text = "%d ECHO COINS" % progression.get_coin_balance()
	for node_id in _definitions:
		var definition: Dictionary = _definitions[node_id]
		var button: Button
		if _buttons.has(node_id):
			button = _buttons[node_id]
		else:
			button = STAR_NODE.new()
			button.position = POSITIONS[node_id] - Vector2(83, 42)
			button.size = Vector2(166, 120)
			button.add_theme_font_size_override("font_size", 14)
			button.pressed.connect(_select.bind(node_id))
			_canvas.add_child(button)
			_buttons[node_id] = button
		var state: String = progression.get_node_state(node_id)
		var color: Color = COLORS[definition["branch"]]
		var affordable: bool = state == "available" and progression.get_coin_balance() >= int(definition["cost"])
		button.configure(definition, state, affordable, color)
		button.selected = node_id == _selected
		button.tooltip_text = definition["description"]
	_canvas.queue_redraw()
	_update_details()

func _draw_connections() -> void:
	for node_id in _definitions:
		var definition: Dictionary = _definitions[node_id]
		for prerequisite in definition["prerequisites"]:
			var from: Vector2 = POSITIONS[prerequisite]
			var to: Vector2 = POSITIONS[node_id]
			var bright: bool = is_instance_valid(progression) and progression.get_node_state(node_id) == "unlocked"
			var color: Color = COLORS[definition["branch"]]
			var count := maxi(2, int(from.distance_to(to) / 9.0))
			var normal := (to - from).orthogonal().normalized()
			for i in range(count + 1):
				var t := float(i) / count
				var point := from.lerp(to, t) + normal * sin(t * PI) * 16.0
				color.a = 0.55 if bright else 0.17
				_canvas.draw_circle(point, 1.5 if bright else 1.0, color)
			if bright:
				var t := fmod(_sky_phase * 0.12, 1.0)
				var spark := from.lerp(to,t) + normal * sin(t * PI) * 16.0
				_canvas.draw_circle(spark, 2.2, Color(color,0.8))

func _process(delta: float) -> void:
	if visible and _canvas != null and (not is_instance_valid(progression) or not progression.reduced_motion):
		_sky_phase += delta
		_canvas.queue_redraw()

func _select(node_id: String) -> void:
	_selected = node_id
	for id in _buttons:
		_buttons[id].selected = id == node_id
	_update_details()

func _update_details() -> void:
	if not _definitions.has(_selected):
		return
	var definition: Dictionary = _definitions[_selected]
	var state: String = progression.get_node_state(_selected)
	_title.text = definition["name"]
	_title.modulate = COLORS[definition["branch"]]
	_description.text = definition["description"]
	_requirements.text = "Cost: %d Echo Coins" % int(definition["cost"])
	if state == "locked":
		_requirements.text += "\n" + progression.get_lock_reason(_selected)
	_status.text = state.capitalize()
	_purchase.disabled = state != "available" or progression.get_coin_balance() < int(definition["cost"])
	_purchase.text = "Unlocked" if state == "unlocked" else ("Unlock" if state == "available" else "Requirements not met")
	if state == "available" and progression.get_coin_balance() < int(definition["cost"]):
		_status.text = "Need %d more coins" % (int(definition["cost"]) - progression.get_coin_balance())

func _purchase_selected() -> void:
	if progression.try_unlock_node(_selected):
		var button: Button = _buttons[_selected]
		button.illuminate()
		if _pulse != null and _pulse.is_valid():
			_pulse.kill()
		button.modulate = Color(1.6, 1.6, 1.6)
		_pulse = create_tween()
		_pulse.tween_property(button, "modulate", Color.WHITE, 0.4)
	_refresh()

func _apply_motion_preference(node: Node) -> void:
	if node is Control and node.get_script() != null:
		var path: String = node.get_script().resource_path
		if path.ends_with("cosmic_background.gd") or path.ends_with("orb_preview.gd") or path.ends_with("constellation_node.gd"):
			node.set_process(not progression.reduced_motion)
	for child in node.get_children(): _apply_motion_preference(child)

func open_tree() -> void:
	if visible or not is_instance_valid(progression):
		return
	for overlay in get_tree().get_nodes_in_group("echo_modal"):
		if overlay != self and overlay.visible:
			return
	_was_paused = get_tree().paused
	_paused_player = progression.get_bound_player()
	_was_active = is_instance_valid(_paused_player) and _paused_player.active
	if is_instance_valid(_paused_player):
		_paused_player.active = false
	get_tree().paused = true
	show()
	_apply_motion_preference(self)
	_refresh()
	if _buttons.has(_selected):
		_buttons[_selected].grab_focus()
	opened.emit()

func close_tree() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_paused_player):
		_paused_player.suppress_resume_input()
		_paused_player.active = _was_active and not _paused_player.dead
	get_tree().paused = _was_paused
	closed.emit()

func _exit_tree() -> void:
	if visible:
		close_tree()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (hotkey_enabled and event.keycode == KEY_TAB) or (visible and event.keycode == KEY_ESCAPE):
			if visible:
				close_tree()
			else:
				open_tree()
			get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
