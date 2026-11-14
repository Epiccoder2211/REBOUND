extends Control
## Optional nonblocking HUD hook. Coin streaks merge; at most three notices.
var progression: Node
var _items: Array[Dictionary] = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func bind_progression(manager: Node) -> void:
	if is_instance_valid(progression) and progression.reward_received.is_connected(_reward):
		progression.reward_received.disconnect(_reward)
	progression = manager
	if is_instance_valid(manager):
		manager.reward_received.connect(_reward)
func _reward(amount: int, reason: String) -> void:
	if reason == "Echo Coins" and not _items.is_empty():
		var last: Dictionary = _items.back()
		if last["reason"] == reason and float(last["age"]) < 0.4:
			last["amount"] += amount
			last["age"] = 0.0
			return
	if _items.size() >= 3:
		_items.pop_front()
	_items.append({"amount": amount, "reason": reason, "age": 0.0})
func _process(delta: float) -> void:
	for i in range(_items.size()-1,-1,-1):
		_items[i]["age"] += delta
		if float(_items[i]["age"]) > 2.3:
			_items.remove_at(i)
	queue_redraw()
func _draw() -> void:
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var alpha := minf(1.0, (2.3-float(item["age"])) / 0.35)
		var at := Vector2(maxf(12,size.x-278),24+i*52)
		draw_style_box(_box(alpha),Rect2(at,Vector2(250,44)))
		draw_string(ThemeDB.fallback_font,at+Vector2(14,28),"+%d  %s" % [item["amount"],item["reason"]],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,0.85,0.52,alpha))
func _box(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04,0.08,0.15,0.92*alpha)
	box.border_color = Color(0.65,0.52,0.3,0.4*alpha)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	return box
