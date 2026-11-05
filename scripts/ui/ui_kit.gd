class_name CityUI
extends RefCounted

static func box(color: Color, radius: int = 14, margin: int = 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

static func label(text: String, size: int, color: Color, theme: Theme, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = CityLocale.t(text)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if size >= 20:
		node.add_theme_font_override("font", theme.get_font("display", "City"))
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable, theme: Theme, primary: bool = false) -> Button:
	var node := CityGameButton.new()
	node.set_meta("intent", "gold" if primary else "navy")
	node.text = CityLocale.t(text)
	node.theme = theme
	node.custom_minimum_size.y = 46
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 16)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		node.add_theme_color_override(state, CityArtDirection.UI_ON_PRIMARY if primary else CityArtDirection.UI_INK)
	node.pressed.connect(func() -> void:
		node.get_viewport().set_input_as_handled()
		callback.call()
	)
	return node

static func panel(parent: Node, theme: Theme) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = theme
	var style := box(Color("fffaf1"), 16, 24)
	style.border_color = CityArtDirection.UI_LINE
	style.set_border_width_all(1)
	style.shadow_color = CityArtDirection.UI_SHADOW
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel
