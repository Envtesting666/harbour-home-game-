class_name CityHUD
extends CanvasLayer
## Native Godot controls. Only the selected property's actions are exposed.

signal action_requested(action: String, value: String)

const INK := CityArtDirection.UI_INK
const MUTED := CityArtDirection.UI_MUTED
const PAPER := CityArtDirection.UI_PAPER
const GREEN := CityArtDirection.UI_PRIMARY
const LINE := CityArtDirection.UI_LINE

var state: CityState
var atlas: Texture2D
var root: Control
var header: PanelContainer
var dock: PanelContainer
var objective_panel: PanelContainer
var context_panel: PanelContainer
var shop_panel: PanelContainer
var cash_label: Label
var worth_label: Label
var level_label: Label
var goal_label: Label
var goal_progress: Label
var goal_claim: Button
var goal_detail: Label
var goal_checks: Label
var goal_toggle: Button
var guide_expanded := true
var guide_milestone := -1
var goal_was_ready := false
var toast_label: Label
var toast_panel: PanelContainer
var hint_label: Label
var save_label: Label
var context_body: VBoxContainer
var shop_body: VBoxContainer
var clock_label: Label
var clock_action: Button
var clock_progress: ProgressBar
var cafe_count_label: Label
var cafe_sales_label: Label
var context_index := -1
var context_mode := "normal"
var context_kind := ""
var lease_type := "short"
var active_category := "Konut"
var preferred_shop_width := 740.0
var context_phase := ""
var toast_time := 0.0
var architecture_choice := "veranda"

func setup(model: CityState, texture: Texture2D) -> void:
	state = model
	atlas = texture
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _theme()
	_create_header()
	_create_objective()
	_create_dock()
	context_panel = _panel()
	context_panel.name = "PropertyPanel"
	context_panel.custom_minimum_size.x = 310
	root.add_child(context_panel)
	context_body = _vbox(context_panel)
	context_panel.hide()
	shop_panel = _panel()
	shop_panel.name = "BuildCatalog"
	root.add_child(shop_panel)
	shop_body = _vbox(shop_panel)
	shop_panel.hide()
	toast_panel = _panel(INK)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_label = _label("", 15, CityArtDirection.UI_ON_PRIMARY)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.hide()
	hint_label = _label("", 15, INK)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_label)
	root.resized.connect(_layout)
	_layout()
	refresh()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	for name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := _style(PAPER)
		style.set_content_margin_all(12)
		if name == "hover":
			style.bg_color = CityArtDirection.UI_HOVER
		elif name == "pressed":
			style.bg_color = CityArtDirection.UI_PRESSED
		elif name == "disabled":
			style.bg_color = CityArtDirection.UI_DISABLED
		elif name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = GREEN
		theme.set_stylebox(name, "Button", style)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", CityArtDirection.UI_DISABLED_TEXT)
	theme.set_color("font_color", "Label", INK)
	var track := _style(CityArtDirection.UI_DISABLED, 3)
	track.set_content_margin_all(0)
	var progress := _style(CityArtDirection.UI_GOLD, 3)
	progress.set_content_margin_all(0)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", progress)
	var slider_track := _style(Color("ccdbe5"), 3)
	slider_track.set_content_margin_all(0)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	var slider_fill := slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = CityArtDirection.UI_GOLD
	theme.set_stylebox("slider", "HSlider", slider_track)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	for icon_name: String in ["grabber", "grabber_highlight"]:
		theme.set_icon(icon_name, "HSlider", load("res://assets/ui/slider-thumb.svg"))
	theme.set_stylebox("panel", "PopupMenu", _style(PAPER, 10))
	theme.set_stylebox("hover", "PopupMenu", _style(CityArtDirection.UI_HOVER, 6))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	return theme

func _style(color: Color, radius: int = 11) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(17)
	return style

func _panel(color: Color = PAPER) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(color, 14)
	style.shadow_color = CityArtDirection.UI_SHADOW
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _vbox(parent: Node, gap: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _hbox(parent: Node, gap: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _label(text: String, font_size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = CityLocale.t(text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _text(parent: Node, text: String, font_size: int = 17, color: Color = INK) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text: String, action: String, value: String = "", primary: bool = false) -> Button:
	var button := CityGameButton.new()
	button.set_meta("intent", "gold" if primary else ("quiet" if action in ["close", "close_shop", "category", "architecture_choice", "specialization_choice"] else "navy"))
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, INK if primary or str(button.get_meta("intent")) == "quiet" else Color.WHITE)
	button.text = CityLocale.t(text)
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: action_requested.emit(action, value))
	if primary:
		_primary(button)
	return button

func _primary(button: Button) -> void:
	for name: String in ["normal", "hover", "pressed"]:
		var style := _style(GREEN if name == "normal" else CityArtDirection.UI_PRIMARY_HOVER, 10)
		style.set_content_margin_all(13)
		button.add_theme_stylebox_override(name, style)
	for name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(name, CityArtDirection.UI_ON_PRIMARY)

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	return spacer

func _create_header() -> void:
	header = _panel()
	header.name = "Header"
	root.add_child(header)
	var row := _hbox(header, 26)
	var identity := _vbox(row, 2)
	identity.add_child(_label("Liman Mahallesi", 23))
	level_label = _label("Şirket seviyesi 1", 13, MUTED)
	identity.add_child(level_label)
	_spacer(row)
	var funds := _vbox(row, 0)
	funds.add_child(_label("NAKİT", 11, MUTED))
	cash_label = _label("", 24)
	funds.add_child(cash_label)
	var worth := _vbox(row, 0)
	worth.add_child(_label("ŞİRKET DEĞERİ", 11, MUTED))
	worth_label = _label("", 21)
	worth.add_child(worth_label)
	var save_info := _vbox(row, 3)
	save_label = _label("Otomatik kayıt", 12, MUTED)
	save_info.add_child(save_label)
	var help := _button("?", "help")
	help.custom_minimum_size = Vector2(44, 44)
	row.add_child(help)

func _create_objective() -> void:
	objective_panel = _panel()
	objective_panel.name = "CurrentObjective"
	root.add_child(objective_panel)
	var column := _vbox(objective_panel, 6)
	var row := _hbox(column, 12)
	goal_label = _label("", 16)
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(goal_label)
	goal_progress = _label("", 13, MUTED)
	row.add_child(goal_progress)
	goal_claim = _button("", "claim", "", true)
	goal_claim.custom_minimum_size.y = 36
	goal_claim.add_theme_font_size_override("font_size", 14)
	column.add_child(goal_claim)

func _create_dock() -> void:
	dock = _panel()
	root.add_child(dock)
	var row := _hbox(dock, 5)
	row.add_child(_button("＋  İnşa et", "catalog", "", true))
	row.add_child(_button("Taşı", "move"))
	row.add_child(_button("Merkeze dön", "home"))
	var zoom := _panel()
	zoom.name = "ZoomControls"
	root.add_child(zoom)
	var zoom_row := _hbox(zoom, 3)
	zoom_row.add_child(_button("−", "zoom_out"))
	zoom_row.add_child(_button("+", "zoom_in"))

func _layout() -> void:
	if root == null:
		return
	var size := root.get_viewport_rect().size
	var margin := 22.0
	header.position = Vector2(margin, 18)
	header.size = Vector2(size.x - 2 * margin, 84)
	objective_panel.position = Vector2(margin, 116)
	objective_panel.size = Vector2(maxf(308, objective_panel.get_combined_minimum_size().x), objective_panel.get_combined_minimum_size().y)
	dock.visible = not context_panel.visible and not shop_panel.visible
	dock.reset_size()
	dock.position = Vector2((size.x - dock.size.x) / 2, size.y - dock.size.y - 20)
	var zoom: Control = root.get_node("ZoomControls")
	zoom.reset_size()
	zoom.position = Vector2(margin, size.y - zoom.size.y - 20)
	if size.x < 1000:
		zoom.hide()
	else:
		zoom.show()
	hint_label.position = Vector2(0, size.y - dock.size.y - 62)
	hint_label.size.x = size.x
	shop_panel.custom_minimum_size.x = minf(preferred_shop_width, size.x - 44)
	shop_panel.size = Vector2(shop_panel.custom_minimum_size.x, shop_panel.get_combined_minimum_size().y)
	shop_panel.position = Vector2((size.x - shop_panel.size.x) / 2, maxf(215, size.y - shop_panel.size.y - dock.size.y - 32))
	toast_panel.custom_minimum_size.x = minf(360, size.x * 0.4)
	toast_panel.size = Vector2(toast_panel.custom_minimum_size.x, toast_panel.get_combined_minimum_size().y)
	toast_panel.position = Vector2(24, size.y - toast_panel.size.y - 110)
	if context_panel.visible:
		position_context(Vector2(size.x * 0.55, size.y * 0.48))

func money(value: int) -> String:
	return CityLocale.money(value)

func duration(seconds: int) -> String:
	if seconds >= 60:
		return CityLocale.f("{0} dk {1} sn", [int(seconds / 60), "%02d" % (seconds % 60)])
	return CityLocale.f("{0} sn", [maxi(seconds, 0)])

func refresh() -> void:
	cash_label.text = money(state.cash)
	worth_label.text = money(state.net_worth())
	level_label.text = CityLocale.f("Şirket seviyesi {0} · {1}/150 XP", [state.level(), state.experience % 150])
	refresh_goal()
	if context_panel.visible:
		show_context(context_index, context_mode, context_kind)
	_layout()
	call_deferred("_layout")

func refresh_goal() -> void:
	if guide_milestone != state.milestone:
		guide_milestone = state.milestone
		guide_expanded = true
	var goal := state.objective(int(Time.get_unix_time_from_system()))
	var journey := CityJourney.describe(state, int(Time.get_unix_time_from_system()))
	var ready := state.can_claim_objective(int(Time.get_unix_time_from_system()))
	if ready and not goal_was_ready: guide_expanded = true
	goal_was_ready = ready
	goal_label.text = CityLocale.t(goal.name)
	goal_progress.text = str(mini(int(goal.progress), int(goal.target))) + "/" + str(goal.target)
	goal_progress.visible = state.milestone >= 5 and int(goal.reward) > 0
	var inspecting := context_panel.visible or shop_panel.visible or not guide_expanded
	if is_instance_valid(goal_toggle): goal_toggle.text = "+" if inspecting else "−"
	goal_claim.visible = guide_expanded and (not inspecting or ready or state.needs_project())
	goal_claim.text = CityLocale.t(journey.label)
	if is_instance_valid(goal_detail):
		goal_detail.text = CityLocale.t(journey.detail)
		goal_detail.visible = not inspecting
	if is_instance_valid(goal_checks):
		goal_checks.text = "\n".join(journey.checks)
		goal_checks.visible = not inspecting and not journey.checks.is_empty()
	goal_label.tooltip_text = CityLocale.t(goal.detail)
	objective_panel.size.y = 0
	objective_panel.reset_size()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _context_heading(title: String, kicker: String) -> void:
	_text(context_body, kicker.to_upper(), 11, MUTED)
	var row := _hbox(context_body, 10)
	var label := _label(title, 21)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var close := _button("×", "close")
	close.custom_minimum_size = Vector2(42, 42)
	row.add_child(close)

func show_context(index: int, mode: String = "normal", kind: String = "") -> void:
	if not state.valid_index(index):
		hide_context()
		return
	context_index = index
	context_mode = mode
	context_kind = kind
	context_phase = _phase(index)
	clock_label = null
	clock_action = null
	clock_progress = null
	cafe_count_label = null
	cafe_sales_label = null
	_clear(context_body)
	context_panel.show()
	var now := int(Time.get_unix_time_from_system())
	var lot: Dictionary = state.lots[index]
	if not state.accessible(index):
		_context_heading("Yeni semt", "Genişleme alanı")
		_text(context_body, "Sekiz yeni parsel. Yeni konutlar ve işletmeler için daha fazla alan.", 16, MUTED)
		_text(context_body, CityLocale.f("Şirket seviyesi 3 · {0}", [money(CityState.EXPANSION_PRICE)]), 17)
		var button := _button("Bölgeyi aç", "expand", "", true)
		button.disabled = state.level() < CityState.EXPANSION_LEVEL or state.cash < CityState.EXPANSION_PRICE
		context_body.add_child(button)
	elif mode == "build" and not kind.is_empty():
		var definition := state.catalog.get_building(kind)
		_context_heading(definition.name, "Yerleşim önizlemesi")
		if kind != "cafe": _text(context_body, definition.description, 15, MUTED)
		if kind == "cottage":
			_build_design_picker()
		if kind == "cafe":
			var forecast := state.cafe_projection(index, now)
			_text(context_body, CityLocale.f("{0} müşteri · {1} / 30 sn", [snappedf(float(forecast.customers), 0.1), money(forecast.income)]), 17)
			var delta: int = forecast.district_change
			if state.count_kind("İşletme") > 0:
				_text(context_body, CityLocale.f("Mahalle geliri {0} / 30 sn", [("+" if delta >= 0 else "") + money(delta)]) + "\n" + CityLocale.t("Diğer kafelerle müşteri paylaşımı dahil."), 13, MUTED)
			_text(context_body, "Yapım tamamlandığındaki talebe göre.", 12, MUTED)
			var potential := 0
			for home in range(state.lots.size()):
				if state.catalog.is_residential(state.lots[home].kind) and state.is_complete(home, now) and CityStreets.can_reach(state, home, index): potential += state.resident_count(home)
			_text(context_body, CityLocale.f("{0} komşu buraya yürüyebilir. Evlerine kiracı alarak kafeyi canlandır.", [potential]), 13, MUTED)
		elif kind == "park":
			_text(context_body, CityLocale.f("{0} konut yeni kontratta yararlanır", [state.park_projection(index, now)]), 16)
		elif state.catalog.is_residential(kind):
			var bonus := roundi(state.park_bonus(index, now) * 100)
			_text(context_body, CityLocale.f("Bu arsada park etkisi +%{0} kira", [bonus]), 13, MUTED)
		_text(context_body, CityLocale.f("Yapı {0} · Arsa {1}", [money(int(definition.price)), money(0 if lot.owned else CityCatalog.LAND_PRICE)]), 15)
		_text(context_body, CityLocale.f("Toplam {0}", [money(state.build_price(index, kind))]), 23)
		var error := state.build_error(index, kind)
		if not error.is_empty():
			_text(context_body, error, 14, CityArtDirection.UI_ALERT)
		if state.accessible(index) and not state.has_frontage(index):
			context_body.add_child(_button("Önce sokağı bağla", "streets", "", true))
		else:
			var button := _button("Buraya inşa et", "confirm_build", "", true)
			button.disabled = not error.is_empty()
			context_body.add_child(button)
	elif mode == "move_target":
		_context_heading("Binayı buraya taşı", "Yeni konum")
		_text(context_body, "Yeni konum park etkilerini ve işletmelerin müşterilerini değiştirir.", 15, MUTED)
		_text(context_body, CityLocale.f("Arsa bedeli {0}", [money(0 if lot.owned else CityCatalog.LAND_PRICE)]), 16)
		context_body.add_child(_button("Taşımayı tamamla", "confirm_move", "", true))
	elif lot.kind.is_empty():
		_context_heading("Boş arsa", "Yeni yatırım")
		_text(context_body, "Bu parseli satın alıp konut, işletme veya park yerleştirebilirsin.", 16, MUTED)
		_text(context_body, CityLocale.f("Arsa bedeli {0}", [money(0 if lot.owned else CityCatalog.LAND_PRICE)]), 17)
		if state.has_frontage(index):
			context_body.add_child(_button("Bir yapı seç", "catalog", "", true))
		else:
			_text(context_body, "Önce bu arsaya ulaşan bir sokak kur.", 14, MUTED)
			context_body.add_child(_button("Sokağı planla", "streets", "", true))
	else:
		var definition := state.catalog.get_building(lot.kind)
		var title: String = CityResidentialDesigns.NAMES.get(str(lot.get("appearance", "veranda")), definition.name) if lot.kind == "cottage" else str(definition.name)
		_context_heading(title, CityLocale.f("{0} · Seviye {1}", [CityLocale.t(definition.category), int(lot.level)]))
		if not state.is_complete(index, now):
			_text(context_body, "Ekibin çalışıyor. Bu sırada mahalleni planlamaya devam edebilirsin.", 16, MUTED)
			clock_label = _text(context_body, "", 22)
			clock_action = _button("İnşaat sürerken sıradaki adıma geç", "journey", "", true)
			context_body.add_child(clock_action)
		elif state.catalog.is_residential(lot.kind):
			_show_residential(index, now)
		elif lot.kind == "cafe":
			_text(context_body, "Yürüyüş bağlantısı olan kiracılar", 14, MUTED)
			cafe_count_label = _text(context_body, "", 23)
			cafe_sales_label = _text(context_body, "", 17)
			if state.growth_economy and int(lot.level) < 3:
				_text(context_body, CityLocale.f("Expand to {0} seats · +35% base sales per customer", [state.cafe_capacity(index) + CityCommerce.SEATS_PER_LEVEL]), 14, MUTED)
			elif not state.growth_economy:
				_text(context_body, "Yakındaki kafeler aynı müşterileri paylaşır.", 14, MUTED)
			var pending := state.collectible(index, now)
			var collect := _button(CityLocale.f("Tahsil et {0}", [money(pending)]), "collect", "", true)
			clock_action = collect
			collect.disabled = pending == 0
			context_body.add_child(collect)
			_upgrade_button(index)
		elif lot.kind == "park":
			_text(context_body, CityLocale.f("Komşu konutlarda +%{0} kira", [int(lot.level) * 12]), 21)
			_text(context_body, "Bonus yeni imzalanan kontratlara eklenir. Parkların toplam etkisi en çok %36.", 15, MUTED)
			_upgrade_button(index)
		elif lot.kind == "hq":
			var goal := state.objective(now)
			_text(context_body, goal.name, 18)
			_text(context_body, goal.detail, 15, MUTED)
			if state.can_claim_objective(now):
				context_body.add_child(_button("Proje ödülünü al", "claim", "", true))
			if state.milestone >= 5:
				context_body.add_child(_button("Proje seç", "projects"))
			if state.unlocked_columns < CityState.COLUMNS:
				if state.growth_economy:
					_text(context_body, CityLocale.f("8 more plots · Company level {0}/{1}", [mini(state.level(), CityState.EXPANSION_LEVEL), CityState.EXPANSION_LEVEL]), 15, MUTED)
				var expand := _button(CityLocale.f("Yeni semt · {0}", [money(CityState.EXPANSION_PRICE)]), "expand")
				expand.disabled = state.level() < CityState.EXPANSION_LEVEL or state.cash < CityState.EXPANSION_PRICE
				context_body.add_child(expand)
			else:
				_text(context_body, "Yeni semt açık. Şehrini büyütmeye devam et.", 16)
	context_panel.size = Vector2(310, 0)
	context_panel.reset_size()
	dock.hide()
	update_clock()

func _build_design_picker() -> void:
	pass

func _show_residential(index: int, now: int) -> void:
	var lot: Dictionary = state.lots[index]
	if not lot.lease.is_empty():
		_text(context_body, "İmzalanmış kontrat", 14, MUTED)
		_text(context_body, money(int(lot.lease.amount)), 28)
		clock_progress = ProgressBar.new()
		clock_progress.show_percentage = false
		clock_progress.custom_minimum_size.y = 6
		context_body.add_child(clock_progress)
		clock_label = _text(context_body, "", 15, MUTED)
		clock_action = _button("", "collect", "", true)
		context_body.add_child(clock_action)
		return
	var bonus := roundi(state.park_bonus(index, now) * 100)
	_text(context_body, CityLocale.f("{0} kiracı", [state.resident_count(index)]) + (CityLocale.f(" · Park bonusu +%{0}", [bonus]) if bonus > 0 else ""), 14, MUTED)
	_text(context_body, "Compare lease terms, then sign to welcome your neighbours.", 14, MUTED)
	context_body.add_child(_button("Kontratı imzala", "lease", lease_type, true))
	_upgrade_button(index)

func _upgrade_button(index: int) -> void:
	if int(state.lots[index].level) >= 3:
		_text(context_body, "Bu yapı en yüksek seviyede.", 14, MUTED)
		return
	var price := state.upgrade_price(index)
	var button := _button(CityLocale.f("Yenile · {0}", [money(price)]), "upgrade")
	button.disabled = state.cash < price
	button.add_theme_font_size_override("font_size", 14)
	context_body.add_child(button)

func _phase(index: int) -> String:
	if not state.valid_index(index):
		return "none"
	var now := int(Time.get_unix_time_from_system())
	if not state.is_complete(index, now):
		return "build"
	return "ready" if state.collectible(index, now) > 0 else "active"

func update_clock() -> void:
	refresh_goal()
	if not context_panel.visible or not state.valid_index(context_index):
		return
	if context_phase != _phase(context_index):
		show_context(context_index, context_mode, context_kind)
		return
	var now := int(Time.get_unix_time_from_system())
	var lot: Dictionary = state.lots[context_index]
	if lot.kind == "cafe" and state.is_complete(context_index, now) and is_instance_valid(clock_action):
		var pending := state.collectible(context_index, now)
		clock_action.text = CityLocale.f("Tahsil et {0}", [money(pending)])
		clock_action.disabled = pending <= 0
		var customers := state.customers(context_index, now)
		cafe_count_label.text = CityLocale.f("{0}/{1} seats filled", [int(customers), state.cafe_capacity(context_index)]) if state.growth_economy else CityLocale.f("{0} müşteri", [snappedf(customers, 0.1)])
		cafe_sales_label.text = money(state.business_income(context_index, now)) + (" / 30 sec" if CityLocale.language == "en" else " / 30 sn")
	if is_instance_valid(clock_label):
		if not state.is_complete(context_index, now):
			clock_label.text = CityLocale.f("{0} kaldı", [duration(int(lot.build_end) - now)])
		elif not lot.lease.is_empty():
			var remaining := maxi(int(lot.lease.end) - now, 0)
			clock_label.text = CityLocale.f("{0} sonra hazır", [duration(remaining)]) if remaining > 0 else CityLocale.t("Kiran hazır. Tahsil edebilirsin.")
			if is_instance_valid(clock_action):
				clock_action.text = CityLocale.t("Kirayı tahsil et" if remaining == 0 else "Kontrat devam ediyor")
				clock_action.disabled = remaining > 0
				clock_action.visible = remaining == 0
			if is_instance_valid(clock_progress):
				var length := maxi(int(lot.lease.end) - int(lot.lease.start), 1)
				clock_progress.value = 100.0 * (1.0 - float(remaining) / length)

func position_context(_screen_point: Vector2) -> void:
	if not context_panel.visible:
		return
	var size := root.get_viewport_rect().size
	context_panel.reset_size()
	var width := context_panel.size.x
	# A stable inspector preserves the click target while text/clock layout settles.
	# It also reserves the left side for the neighborhood goal on compact screens.
	context_panel.position = Vector2(maxf(20, size.x - width - 20), 112)

func hide_context() -> void:
	context_panel.hide()
	context_index = -1
	dock.visible = not shop_panel.visible

func show_shop(category: String = "Konut") -> void:
	active_category = category
	hide_context()
	_clear(shop_body)
	var title_row := _hbox(shop_body)
	title_row.add_child(_label("Yeni yatırım", 21))
	_spacer(title_row)
	title_row.add_child(_button("×", "close_shop"))
	var tabs := _hbox(shop_body, 6)
	for item: String in ["Konut", "İşletme", "Çevre"]:
		var button := _button(item, "category", item, item == category)
		button.custom_minimum_size.y = 40
		tabs.add_child(button)
	var row := _hbox(shop_body, 10)
	for kind: String in state.catalog.category_items(category):
		var definition := state.catalog.get_building(kind)
		var card := _vbox(row, 5)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.x = 150
		var image := TextureRect.new()
		image.texture = atlas_texture(int(definition.sprite))
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(150, 110)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var title := _text(card, definition.name, 15)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var unlocked := state.level() >= int(definition.unlock_level)
		var button := _button(money(int(definition.price)) if unlocked else "Seviye " + str(int(definition.unlock_level)), "choose_building", kind)
		button.disabled = not unlocked or state.cash < int(definition.price)
		button.add_theme_font_size_override("font_size", 15)
		card.add_child(button)
	_text(shop_body, "Yeni arsa için ayrıca 600 $. Önizlemede toplam maliyeti görürsün.", 13, MUTED)
	shop_panel.show()
	dock.hide()
	_layout()

func atlas_texture(sprite: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var cell := Vector2(atlas.get_width() / 4.0, atlas.get_height() / 2.0)
	texture.region = Rect2(Vector2(sprite % 4, int(sprite / 4)) * cell, cell)
	return texture

func hide_shop() -> void:
	shop_panel.hide()
	dock.visible = not context_panel.visible

func set_hint(text: String) -> void:
	hint_label.text = CityLocale.t(text)

func notify_user(text: String, positive: bool = true) -> void:
	toast_label.text = CityLocale.t(text)
	toast_label.add_theme_color_override("font_color", CityArtDirection.UI_ON_PRIMARY if positive else CityArtDirection.UI_ACCENT_LIGHT)
	toast_time = 3.2
	toast_panel.show()
	_layout()

func show_help() -> void:
	action_requested.emit("how_to_play", "")

func _process(delta: float) -> void:
	if hint_label != null:
		hint_label.visible = not hint_label.text.is_empty() and not context_panel.visible and not shop_panel.visible
	# Autowrapped native labels settle after the container layout pass. Shrink floating
	# panels to their content instead of retaining their initial zero-width height.
	if shop_panel != null and shop_panel.visible:
		var size := root.get_viewport_rect().size
		shop_panel.size.y = shop_panel.get_combined_minimum_size().y
		shop_panel.position = Vector2((size.x - shop_panel.size.x) / 2, maxf(112, size.y - shop_panel.size.y - 20))
	if context_panel != null and context_panel.visible:
		context_panel.size.y = context_panel.get_combined_minimum_size().y
	if toast_panel != null and toast_panel.visible:
		toast_panel.size.y = toast_panel.get_combined_minimum_size().y
		toast_panel.position.y = root.get_viewport_rect().size.y - toast_panel.size.y - 110
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_panel.hide()
