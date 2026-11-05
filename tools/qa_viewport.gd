extends SceneTree
## Native rendered viewport isolated from desktop pointer events/window resizing.
## The game and its input-only QA run unchanged inside this fixed-size viewport.
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	var arguments: Array = Array(OS.get_cmdline_user_args())
	if not arguments.any(func(value: String) -> bool: return value.begins_with("--save-dir=")) or not arguments.any(func(value: String) -> bool: return value.begins_with("--capture-dir=")):
		push_error("QA requires explicit isolated --save-dir and --capture-dir arguments.")
		quit(2)
		return
	var mobile := "--mobile-layout" in OS.get_cmdline_user_args()
	var size := Vector2i(960, 540) if mobile else Vector2i(1280, 720)
	root.size = size
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	viewport.add_child(game)
