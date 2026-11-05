extends SceneTree
## Real viewport events: cancellation must survive pointer release off-control,
## focus loss, repeated releases and the accessible keyboard path.
var failures := 0
var checks := 0
var commits := 0
var signature: CityLeaseSignature
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func fresh() -> void:
	if is_instance_valid(signature):
		root.remove_child(signature)
		signature.queue_free()
	signature = CityLeaseSignature.new()
	signature.position = Vector2(20, 20)
	signature.size = Vector2(516, 82)
	root.add_child(signature)
	signature.completed.connect(func() -> void: commits += 1)
func touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	root.push_input(event, true)
func run() -> void:
	CityLocale.set_language("en")
	fresh()
	await process_frame
	touch(Vector2(52, 50), true)
	await create_timer(.1).timeout
	touch(Vector2(900, 400), false)
	await create_timer(.65).timeout
	check(commits == 0 and not signature.held and signature.progress == 0, "Off-control release cancels, never signs later")
	fresh()
	await process_frame
	touch(Vector2(52, 50), true)
	await create_timer(.08).timeout
	signature.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await create_timer(.65).timeout
	check(commits == 0 and not signature.held, "Leaving the app cancels the gesture")
	fresh()
	await process_frame
	touch(Vector2(52, 50), true)
	await create_timer(.08).timeout
	signature.hide()
	await create_timer(.65).timeout
	check(commits == 0 and not signature.held, "Closing the sheet cannot complete a hidden signature")
	fresh()
	await process_frame
	touch(Vector2(52, 50), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(285, 50)
	drag.relative = Vector2(233, 0)
	root.push_input(drag, true)
	touch(Vector2(285, 50), false)
	touch(Vector2(285, 50), false)
	check(commits == 1 and signature.committed, "One short natural swipe commits once, including duplicate release")
	fresh()
	await process_frame
	signature.grab_focus()
	key(true)
	await create_timer(.64).timeout
	key(false)
	check(commits == 2 and signature.committed, "Keyboard hold has the same short signing path")
	fresh()
	await process_frame
	touch(Vector2(52, 50), true)
	await create_timer(.64).timeout
	touch(Vector2(52, 50), false)
	check(commits == 3 and signature.committed, "Stationary touch hold is accessible without accurate tracing")
	print("SIGNATURE_INPUT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
