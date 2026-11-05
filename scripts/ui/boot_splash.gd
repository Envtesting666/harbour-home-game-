class_name CityBootSplash
extends CanvasLayer

var root: Control

func _ready() -> void:
	layer = 100
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("102f4b")
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NunitoSans.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):800.0}
	for text: String in ["HARBOUR & HOME", CityLocale.t("Mahallen hazırlanıyor…")]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 34 if text == "HARBOUR & HOME" else 15)
		label.add_theme_color_override("font_color", Color.WHITE if text == "HARBOUR & HOME" else Color("e5ba68"))
		column.add_child(label)

func finish() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Control in root.find_children("*", "Control", true, false):
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(root, "modulate:a", 0.0, .22)
	fade.tween_callback(queue_free)
