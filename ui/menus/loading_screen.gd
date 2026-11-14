extends Control
## Real threaded resource loading. Host decides where to instantiate the result.
signal loaded(scene: PackedScene)
signal failed(message: String)
const SKY = preload("res://ui/shared/cosmic_background.gd")
const PREVIEW = preload("res://ui/shared/orb_preview.gd")
var _path := ""
var _label: Label
var _progress: ProgressBar
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SKY.new())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.position -= Vector2(220,190)
	column.size = Vector2(440,380)
	add_child(column)
	var orb := PREVIEW.new()
	orb.custom_minimum_size = Vector2(440,240)
	column.add_child(orb)
	_label = Label.new()
	_label.text = "REBOUND: EVOLUTION\nFall. Adapt. Evolve. Rise."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	column.add_child(_progress)
	hide()
func prepare(path: String) -> void:
	if not _path.is_empty(): return
	_path = path
	show()
	var error := ResourceLoader.load_threaded_request(path,"PackedScene")
	if error != OK: _fail("Unable to prepare journey: " + error_string(error))
func _process(_delta: float) -> void:
	if _path.is_empty(): return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path,progress)
	if not progress.is_empty(): _progress.value = float(progress[0])*100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var resource := ResourceLoader.load_threaded_get(_path)
		_path = ""
		hide()
		if resource is PackedScene: loaded.emit(resource)
		else: _fail("The requested journey is not a scene.")
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail("Journey preparation failed. Return and try again.")
func _fail(message: String) -> void:
	_path = ""
	_label.text = message
	failed.emit(message)
func _input(_event: InputEvent) -> void:
	if visible: get_viewport().set_input_as_handled()
