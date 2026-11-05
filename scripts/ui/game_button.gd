class_name CityGameButton
extends Button
## A drawn game control, with one silhouette and material response across the game.
## Button retains native focus, keyboard, mouse and touch semantics.
var surface: MaterialSurface

func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(12)
		add_theme_stylebox_override(state, empty)
	apply_ink()
	surface = MaterialSurface.new()
	surface.button = self
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = true
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	visibility_changed.connect(queue_redraw)

func apply_ink() -> void:
	var intent := str(get_meta("intent", "navy"))
	var light_ink := intent in ["gold", "quiet_dark"]
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		add_theme_color_override(color_name, CityArtDirection.UI_ON_PRIMARY if light_ink else CityArtDirection.UI_INK)
	add_theme_color_override("font_disabled_color", CityArtDirection.UI_DISABLED_TEXT)
	add_theme_color_override("icon_disabled_color", CityArtDirection.UI_DISABLED_TEXT)

func _draw() -> void:
	if is_instance_valid(surface): surface.queue_redraw()

func _paint(target: Control) -> void:
	var intent: String = str(get_meta("intent", "navy"))
	var on_dark := intent == "quiet_dark"
	var quiet := intent == "quiet" or on_dark
	var primary := intent == "gold"
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(mini(12, roundi(size.y * .25)))
	style.bg_color = CityArtDirection.UI_PRIMARY if primary else (Color.TRANSPARENT if quiet else CityArtDirection.UI_HOVER)
	style.border_color = CityArtDirection.UI_LINE
	style.set_border_width_all(0 if primary or quiet else 1)
	if is_hovered() and not disabled: style.bg_color = CityArtDirection.UI_PRIMARY_HOVER if primary else CityArtDirection.UI_HOVER
	if is_pressed() and not disabled: style.bg_color = CityArtDirection.UI_PRIMARY.darkened(.09) if primary else CityArtDirection.UI_PRESSED
	if on_dark and not disabled and (is_hovered() or is_pressed()):
		style.bg_color = Color("365967") if is_pressed() else Color("2c4b5a")
	if disabled: style.bg_color = CityArtDirection.UI_DISABLED
	if primary and not disabled:
		style.shadow_color = Color(0.02, .17, .14, .14)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
	var rect := Rect2(Vector2(0, 1 if is_pressed() else 0), size - Vector2(0, 1))
	target.draw_style_box(style, rect)
	if has_focus():
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = CityArtDirection.UI_ACCENT_LIGHT if on_dark else CityArtDirection.UI_PRIMARY.lightened(.22)
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(13)
		target.draw_style_box(focus, rect.grow(2))

class MaterialSurface extends Control:
	var button: CityGameButton
	func _draw() -> void:
		if is_instance_valid(button): button._paint(self)
