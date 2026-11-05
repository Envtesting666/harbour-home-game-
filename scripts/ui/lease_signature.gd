class_name CityLeaseSignature
extends Control
## Deliberate gesture with an accessible keyboard/hold alternative. Ink is only
## cosmetic until completed; interrupted gestures never commit a transaction.
signal completed
signal pen_started
signal pen_stopped
var progress := 0.0
var committed := false
var held := false
var finger := -1
var anchor := 0.0
var ink: Control
var hint: Label
var returning: Tween
var elapsed := 0.0
var ink_width := 225.0
const HOLD_SECONDS := .58

func _input(event: InputEvent) -> void:
	# GUI releases may land outside this control. Never keep signing after the
	# player has lifted their finger, released the mouse, or left the window.
	if not held: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and finger == -1:
		_release()
	elif event is InputEventScreenTouch and not event.pressed and event.index == finger:
		_release()
	elif event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER] and not event.pressed and finger == -2:
		_release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and held: _release()

func _ready() -> void:
	custom_minimum_size = Vector2(464, 82)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var script_font: Font = load("res://assets/fonts/allison/Allison-Regular.ttf")
	ink_width = script_font.get_string_size("Harbour & Home", HORIZONTAL_ALIGNMENT_LEFT, -1, 55).x + 3
	var ghost := Label.new()
	ghost.text = "Harbour & Home"
	ghost.add_theme_font_override("font", script_font)
	ghost.add_theme_font_size_override("font_size", 55)
	ghost.add_theme_color_override("font_color", Color("ccd6cf"))
	ghost.position = Vector2(70, -3)
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ghost)
	ink = Control.new()
	ink.position = Vector2(70, -3)
	ink.size = Vector2(0, 62)
	ink.clip_contents = true
	ink.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ink)
	var written := ghost.duplicate() as Label
	written.position = Vector2.ZERO
	written.add_theme_color_override("font_color", Color("174f49"))
	ink.add_child(written)
	hint = Label.new()
	hint.text = CityLocale.t("Slide to sign · or hold briefly")
	hint.position = Vector2(18, 60)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", CityArtDirection.UI_MUTED)
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hint)
	focus_exited.connect(func() -> void:
		if held: _release()
	)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree() and held: _release()
	)
	tooltip_text = CityLocale.t("Kaydır, basılı tut veya Space tuşunu kullan. Tamamlanmadan para harcanmaz.")
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if committed: return
	if event is InputEventScreenTouch:
		if event.pressed: _begin(event.position.x, event.index)
		elif finger == event.index: _release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		_drag(event.position.x)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(event.position.x, -1)
		else: _release()
		accept_event()
	elif event is InputEventMouseMotion and held and finger == -1:
		_drag(event.position.x)
		accept_event()
	elif event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER] and not event.echo:
		if event.pressed: _begin(24, -2)
		else: _release()
		accept_event()

func _begin(x: float, touch: int) -> void:
	if held or committed: return
	if is_instance_valid(returning): returning.kill()
	held = true
	finger = touch
	anchor = x - progress * _travel()
	elapsed = 0
	grab_focus()
	pen_started.emit()

func _drag(x: float) -> void:
	if held: _set_progress(maxf(progress, (x - anchor) / _travel()))

func _travel() -> float:
	return clampf(size.x * .42, 140, 220)

func _release() -> void:
	if not held: return
	held = false
	finger = -1
	pen_stopped.emit()
	if committed: return
	returning = create_tween()
	returning.tween_method(_set_progress, progress, 0.0, .14)

func _process(delta: float) -> void:
	if held and not committed:
		elapsed += delta
		_set_progress(maxf(progress, elapsed / HOLD_SECONDS))

func _set_progress(value: float) -> void:
	progress = clampf(value, 0, 1)
	if is_instance_valid(ink): ink.size.x = ink_width * progress
	if progress >= 1 and not committed:
		committed = true
		held = false
		hint.text = CityLocale.t("İmza tamamlandı")
		pen_stopped.emit()
		completed.emit()
	queue_redraw()

func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f2f5ed")
	box.set_corner_radius_all(12)
	box.border_color = Color("d9e1dc")
	box.set_border_width_all(1)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(70, 51), Vector2(size.x - 24, 51), Color("c7d1cc"), 1, true)
	if progress > 0:
		draw_line(Vector2(70, 51), Vector2(70 + (size.x - 94) * progress, 51), CityArtDirection.UI_PRIMARY, 2, true)
	var x := 30 + progress * _travel()
	if not committed:
		draw_circle(Vector2(x, 30), 20, CityArtDirection.UI_PRIMARY, true, -1, true)
		# A nib on the signature line, rather than a second generic arrow button.
		draw_polyline(PackedVector2Array([Vector2(x - 7, 37), Vector2(x - 4, 28), Vector2(x + 5, 20), Vector2(x + 10, 25), Vector2(x + 1, 34), Vector2(x - 7, 37)]), Color.WHITE, 1.8, true)
		draw_line(Vector2(x - 5, 35), Vector2(x, 30), Color.WHITE, 1.4, true)
	else:
		draw_circle(Vector2(size.x - 34, 30), 20, Color("248574"), true, -1, true)
		draw_polyline(PackedVector2Array([Vector2(size.x - 43, 30),Vector2(size.x - 36, 37),Vector2(size.x - 24, 23)]), Color.WHITE, 2.5, true)
	if has_focus() and not committed:
		draw_line(Vector2(22, size.y - 1), Vector2(size.x - 22, size.y - 1), CityArtDirection.UI_GOLD, 2, true)
