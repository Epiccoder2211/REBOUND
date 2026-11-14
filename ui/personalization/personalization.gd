extends "res://ui/echo_nexus/echo_nexus.gd"
## Reuses tested pause ownership, not upgrade purchase logic. Preview is isolated.
const PREVIEW = preload("res://ui/shared/orb_preview.gd")
signal edit_name_requested()
var _preview: Control

func _ready() -> void:
	_selected = "skin_echo"
	super._ready()

func bind_progression(manager: Node) -> void:
	if is_instance_valid(progression):
		for event in ["coins_changed", "cosmetic_purchased", "cosmetic_equipped", "progression_loaded"]:
			if progression.is_connected(event, _on_progression_changed):
				progression.disconnect(event, _on_progression_changed)
	progression = manager
	if not is_instance_valid(progression):
		return
	_definitions = progression.get_cosmetic_definitions()
	_selected = progression.get_equipped_cosmetics()["skin"]
	for event in ["coins_changed", "cosmetic_purchased", "cosmetic_equipped", "progression_loaded"]:
		progression.connect(event, _on_progression_changed)
	if is_node_ready():
		_refresh()

func _build() -> void:
	add_child(COSMOS.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_"+side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("PERSONALIZATION", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_balance = _label("", 21)
	_balance.modulate = Color("ffce72")
	heading.add_child(_balance)
	var edit := Button.new()
	edit.text = "Edit Name"
	edit.pressed.connect(func(): edit_name_requested.emit())
	column.add_child(edit)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 280
	row.add_child(scroll)
	_canvas = VBoxContainer.new()
	_canvas.custom_minimum_size.x = 260
	scroll.add_child(_canvas)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	center.add_child(_label("LIVE PREVIEW", 12))
	_preview = PREVIEW.new()
	_preview.custom_minimum_size = Vector2(210,230)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_preview)
	
	var frame := PanelContainer.new()
	frame.custom_minimum_size.x = 280
	row.add_child(frame)
	var details := VBoxContainer.new()
	frame.add_child(details)
	details.add_child(_label("YOUR SIGNATURE",12))
	_title = _label("",24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_title)
	_description = _label("",17)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_description)
	_requirements = _label("",16)
	details.add_child(_requirements)
	_status = _label("",15)
	details.add_child(_status)
	_purchase = Button.new()
	_purchase.custom_minimum_size.y = 50
	_purchase.pressed.connect(_purchase_selected)
	details.add_child(_purchase)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close_tree)
	details.add_child(back)

func _refresh() -> void:
	if not is_instance_valid(progression):
		return
	_balance.text = "%d ECHO COINS" % progression.get_coin_balance()
	var owned: Array = progression.get_owned_cosmetics()
	var equipped: Dictionary = progression.get_equipped_cosmetics()
	var last_slot := ""
	for id in _definitions:
		var definition: Dictionary = _definitions[id]
		if not _buttons.has(id):
			if definition["slot"] != last_slot:
				_canvas.add_child(_label(str(definition["slot"]).to_upper(),12))
				last_slot = definition["slot"]
			var button := Button.new()
			button.custom_minimum_size.y = 54
			button.add_theme_font_size_override("font_size",15)
			button.pressed.connect(_select.bind(id))
			_canvas.add_child(button)
			_buttons[id] = button
		var suffix := "EQUIPPED" if equipped[definition["slot"]] == id else ("OWNED" if id in owned else "%d COINS" % int(definition["cost"]))
		_buttons[id].text = "%s  ·  %s" % [definition["name"],suffix]
		_buttons[id].add_theme_color_override("font_color", definition["color"])
		_buttons[id].modulate = Color.WHITE if _selected == id else Color(0.75,0.8,0.9)
	_update_details()

func _select(id: String) -> void:
	_selected = id
	_refresh()

func _update_details() -> void:
	if not _definitions.has(_selected):
		return
	var definition: Dictionary = _definitions[_selected]
	var owned: bool = _selected in progression.get_owned_cosmetics()
	var equipped: bool = progression.get_equipped_cosmetics()[definition["slot"]] == _selected
	_title.text = definition["name"]
	_title.modulate = definition["color"]
	_description.text = definition["description"]
	_requirements.text = "Owned" if owned else "Cost: %d Echo Coins" % int(definition["cost"])
	_status.text = "Currently equipped" if equipped else ("Ready to equip" if owned else "Previewing • not equipped")
	_purchase.disabled = equipped or (not owned and progression.get_coin_balance() < int(definition["cost"]))
	_purchase.text = "Equipped" if equipped else ("Equip" if owned else "Purchase")
	if definition.has("level") and not owned:
		_requirements.text = "Level %d gift" % int(definition["level"])
		_purchase.disabled = true
		_purchase.text = "Locked"
	_preview.appearance = progression.get_cosmetic_appearance({definition["slot"]: _selected})

func _purchase_selected() -> void:
	if _selected in progression.get_owned_cosmetics():
		progression.equip_cosmetic(_selected)
	else:
		progression.purchase_cosmetic(_selected)
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (hotkey_enabled and event.keycode == KEY_C) or (visible and event.keycode == KEY_ESCAPE):
			if visible:
				close_tree()
			else:
				open_tree()
			get_viewport().set_input_as_handled()
