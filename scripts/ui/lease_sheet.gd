class_name CityLeaseSheet
extends CanvasLayer
## A property-led offer: inspect the real home, compare rent and local trade,
## then complete one signature gesture. Only completion requests a transaction.
signal sign_requested(index: int, lease_type: String)
signal dismissed
signal pen_started
signal pen_stopped
var root: Control
var paper: Panel
var signature: CityLeaseSignature
var ui_theme: Theme
var index := -1
var lease_type := "short"
var phase := "closed"
var property_texture: Texture2D
var heading: Label
var subheading: Label
var cancel: Button
var exit_button: Button
var pop: Tween
var fit := Vector2.ONE

func setup(theme: Theme) -> void:
	layer = 30
	ui_theme = theme
	root = Control.new()
	root.theme = theme
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(_layout)
	root.hide()

func is_open() -> bool:
	return phase != "closed"

func show_agreement(city: CityState, lot_index: int, type: String, now: int, preview: Texture2D = null, guided: bool = false) -> void:
	var opening := phase != "review" or index != lot_index
	pen_stopped.emit()
	index = lot_index
	lease_type = type
	property_texture = preview
	phase = "review"
	if is_instance_valid(pop): pop.kill()
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.show()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.12, .69)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper = Panel.new()
	paper.name = "LeasePaper"
	paper.theme = ui_theme
	var style := CityUI.box(Color("fffaf1"), 18, 0)
	style.shadow_color = Color(0.01, .04, .08, .34)
	style.shadow_size = 28
	style.shadow_offset = Vector2(0, 12)
	paper.add_theme_stylebox_override("panel", style)
	root.add_child(paper)
	var hero := Panel.new()
	hero.add_theme_stylebox_override("panel", CityUI.box(Color("183b4b"), 18, 0))
	_place(hero, Vector2.ZERO, Vector2(246, 484))
	var chart := TextureRect.new()
	chart.texture = preload("res://assets/ui/harbour-chart.svg")
	chart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(chart, Vector2(0, 13), Vector2(246, 270))
	_place(CityUI.label("HARBOUR & HOME", 12, Color("c8dfdf"), ui_theme), Vector2(24, 22), Vector2(206, 24))
	var image := TextureRect.new()
	image.texture = property_texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, Vector2(8, 66), Vector2(230, 204))
	var lot: Dictionary = city.lots[index]
	var property_name := CityLocale.t(CityResidentialDesigns.NAMES.get(str(lot.get("appearance", "veranda")), "")) if lot.kind == "cottage" else CityLocale.t(city.catalog.get_building(lot.kind).name)
	_place(CityUI.label(property_name, 22, Color.WHITE, ui_theme, true), Vector2(24, 290), Vector2(200, 59))
	_place(CityUI.label(CityLocale.f("SEVİYE {0} · MÜLK {1}", [int(lot.level), "%03d" % (index + 1)]), 11, Color("b7d1dc"), ui_theme), Vector2(24, 354), Vector2(210, 24))
	var bonus := roundi(city.park_bonus(index, now) * 100)
	_place(CityUI.label(CityLocale.f("Bahçe değeri +%{0}", [bonus]) if bonus > 0 else "Kendi hikâyesini bekleyen bir ev.", 12, CityArtDirection.UI_GOLD, ui_theme, true), Vector2(24, 385), Vector2(200, 36))
	cancel = CityUI.button("İptal", close, ui_theme)
	_place(cancel, Vector2(24, 426), Vector2(198, 34))
	_place(CityUI.label("YENİ KONTRAT", 11, Color("2b8276"), ui_theme), Vector2(278, 24), Vector2(400, 22))
	heading = CityUI.label("Your first neighbours" if guided else "Welcome new neighbours", 29, CityArtDirection.UI_INK, ui_theme)
	_place(heading, Vector2(278, 47), Vector2(470, 42))
	var names := ["Alex Morgan", "Jamie Parker", "Taylor Reed", "Robin Blake", "Sam Bennett", "Jordan Ellis"]
	subheading = CityUI.label(names[index % names.size()] + "  ·  " + CityLocale.f("{0} yeni komşu", [city.resident_count(index)]), 15, CityArtDirection.UI_MUTED, ui_theme)
	_place(subheading, Vector2(278, 91), Vector2(500, 28))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	_place(choices, Vector2(278, 132), Vector2(516, 44))
	for option: String in ["short", "regular", "long"]:
		var term: Dictionary = CityCatalog.LEASES[option]
		var seconds := int(term.seconds)
		var length := CityLocale.compact_duration(seconds)
		var title := CityLocale.t({"short":"Kısa", "regular":"Düzenli", "long":"Uzun"}[option])
		var button := CityUI.button(title + " · " + length, func() -> void:
			if phase == "review": show_agreement(city, index, option, int(Time.get_unix_time_from_system()), property_texture)
		, ui_theme, option == type)
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		choices.add_child(button)
	if guided:
		choices.hide()
		_place(CityUI.label(CityLocale.f("{0} lease · time to grow your street", [CityLocale.compact_duration(int(CityCatalog.LEASES[type].seconds))]), 15, CityArtDirection.UI_INK, ui_theme), Vector2(278, 138), Vector2(330, 30))
		var compare := CityUI.button("Compare leases", func() -> void:
			if phase == "review": show_agreement(city, index, lease_type, int(Time.get_unix_time_from_system()), property_texture)
		, ui_theme)
		compare.add_theme_font_size_override("font_size", 12)
		_place(compare, Vector2(622, 132), Vector2(172, 40))
	var quote := CityLeaseForecast.quote(city, index, type, now)
	_place(CityUI.label("KİRA GETİRİSİ", 11, CityArtDirection.UI_MUTED, ui_theme), Vector2(278, 193), Vector2(260, 20))
	_place(CityUI.label(CityLocale.money(int(quote.rent)), 36, CityArtDirection.UI_INK, ui_theme), Vector2(278, 212), Vector2(275, 48))
	_place(CityUI.label("İMZA GİDERİ", 11, CityArtDirection.UI_MUTED, ui_theme), Vector2(620, 193), Vector2(160, 20))
	_place(CityUI.label(CityLocale.money(int(quote.fee)), 24, CityArtDirection.UI_INK, ui_theme), Vector2(620, 218), Vector2(160, 36))
	var per_minute := roundi(float(quote.net_rent) * 60 / int(quote.seconds))
	_place(CityUI.label(CityLocale.f("Net {0} · {1}/dk", [CityLocale.money(int(quote.net_rent)), CityLocale.money(per_minute)]), 12, CityArtDirection.UI_MUTED, ui_theme), Vector2(278, 260), Vector2(500, 22))
	var impact := Panel.new()
	impact.add_theme_stylebox_override("panel", CityUI.box(Color("ecf1e9"), 10, 0))
	_place(impact, Vector2(278, 294), Vector2(516, 51))
	var impact_title := CityLocale.f("Yerel ticaret +{0}", [CityLocale.money(int(quote.local_trade))]) if int(quote.local_trade) > 0 else CityLocale.t("Bu komşulara mahalle kafesi aç")
	var impact_detail := CityLocale.t("Kontrat boyunca yakındaki kafelerin ek kazanç tahmini.") if int(quote.local_trade) > 0 else CityLocale.t("Yakındaki bir kafe, kiracılarını yerel müşteriye dönüştürür.")
	if guided and CityStreets.can_reach(city, index, 6):
		impact_title = CityLocale.f("{0} new neighbours → your cafe", [city.resident_count(index)])
		impact_detail = CityLocale.t("Sign, then watch them walk down your street.")
	_place(CityUI.label(impact_title, 15, Color("2d6e5a"), ui_theme), Vector2(292, 297), Vector2(485, 24))
	_place(CityUI.label(impact_detail, 11, CityArtDirection.UI_MUTED, ui_theme), Vector2(292, 320), Vector2(485, 20))
	_place(CityUI.label("İMZANIZ", 10, CityArtDirection.UI_MUTED, ui_theme), Vector2(278, 354), Vector2(500, 18))
	signature = CityLeaseSignature.new()
	_place(signature, Vector2(278, 376), Vector2(516, 82))
	signature.completed.connect(func() -> void:
		if phase == "review": sign_requested.emit(index, lease_type)
	)
	signature.pen_started.connect(func() -> void: pen_started.emit())
	signature.pen_stopped.connect(func() -> void: pen_stopped.emit())
	if city.cash < int(quote.fee):
		signature.mouse_filter = Control.MOUSE_FILTER_IGNORE
		signature.focus_mode = Control.FOCUS_NONE
		signature.set_process(false)
		signature.hint.text = CityLocale.t("Nakit yetersiz. Ücretsiz kısa kontratı seçebilirsin.")
	exit_button = CityUI.button("×", close, ui_theme)
	exit_button.set_meta("intent", "quiet")
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]: exit_button.add_theme_color_override(color_name, CityArtDirection.UI_INK)
	_place(exit_button, Vector2(760, 18), Vector2(34, 34))
	_layout()
	paper.pivot_offset = paper.size * .5
	if opening:
		paper.scale = fit * .985
		paper.modulate.a = 0
		pop = create_tween().set_parallel(true)
		pop.tween_property(paper, "scale", fit, .14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(paper, "modulate:a", 1.0, .12)

func _place(node: Control, position: Vector2, size: Vector2) -> void:
	paper.add_child(node)
	node.position = position
	node.size = size

func _layout() -> void:
	if not is_instance_valid(paper): return
	paper.size = Vector2(824, 484)
	var available := root.get_viewport_rect().size
	fit = Vector2.ONE * minf(1, minf((available.x - 32) / 824, (available.y - 32) / 484))
	paper.pivot_offset = paper.size * .5
	paper.position = (available - paper.size) / 2
	paper.scale = fit

func signed() -> void:
	phase = "signing"
	cancel.hide()
	exit_button.hide()
	heading.text = CityLocale.t("Sokağın canlanıyor.")
	signature.hint.text = CityLocale.t("Kontrat onaylandı. Yeni komşuların yerleşiyor.")
	signature.hint.add_theme_color_override("font_color", Color("2d7866"))
	var tween := create_tween()
	tween.tween_interval(.34)
	tween.tween_property(paper, "modulate:a", 0.0, .14)
	tween.parallel().tween_property(paper, "scale", fit * .99, .14)
	tween.tween_callback(_dismiss)

func _dismiss() -> void:
	phase = "closed"
	pen_stopped.emit()
	root.hide()
	dismissed.emit()

func close() -> void:
	if phase == "signing": return
	_dismiss()
