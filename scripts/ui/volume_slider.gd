class_name CityVolumeSlider
extends HSlider
## Keep keyboard/mouse slider behavior, and handle direct touchscreen gestures.
var finger := -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			finger = event.index
			_set_from_touch(event.position.x)
		elif finger == event.index:
			finger = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		_set_from_touch(event.position.x)
		accept_event()

func _set_from_touch(x: float) -> void:
	var half_thumb := get_theme_icon("grabber").get_width() * .5
	var fraction := clampf((x - half_thumb) / maxf(1, size.x - 2 * half_thumb), 0, 1)
	value = min_value + fraction * (max_value - min_value)
