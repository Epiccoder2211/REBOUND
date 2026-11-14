extends Control
## Preferred entry: prepare the actual demo resource asynchronously.
const LOADER = preload("res://ui/menus/loading_screen.gd")
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1700,956)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var loader := LOADER.new()
	add_child(loader)
	loader.loaded.connect(func(scene: PackedScene):
		var journey := scene.instantiate()
		get_tree().root.add_child(journey)
		get_tree().current_scene = journey
		queue_free())
	loader.failed.connect(func(_message):
		var back := Button.new()
		back.text = "Quit"
		back.position = Vector2(30,30)
		back.pressed.connect(func(): get_tree().quit())
		loader.add_child(back)
		loader.set_process_input(false))
	loader.prepare("res://ui/menus/polish_demo.tscn")
