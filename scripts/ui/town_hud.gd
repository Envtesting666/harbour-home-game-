class_name TownHUD
extends CityHUD
## The town's architectural palette carries into a quieter, compact tool shelf.
## Interaction/persistence behavior stays shared with the tested native HUD.

var building_previews: Dictionary = {}
var specialization_choice := "boutique"
var level_badge: Label
var body_font: FontVariation
var display_font: FontVariation
var experience_bar: ProgressBar
var street_key := ""
var streets_button: Button
var purpose_label: Label
var neighbourhood_values: Array[Label] = []
var neighbourhood_flow: HBoxContainer
var neighbourhood_caption: Label
var opening_steps: HBoxContainer
var last_opening_stage := -1
var step_labels: Array[Label] = []
const MARINE_PANEL := Color("183b4b")
const MARINE_LINE := Color("3d5d68")
const MARINE_MUTED := Color("c2d8d6")

func _label(text: String, font_size: int = 17, color: Color = INK) -> Label:
	var label := super._label(text, font_size, color)
	if display_font != null and font_size >= 20:
		label.add_theme_font_override("font", display_font)
	return label

func _icon(name: String, size: int = 28) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/" + name + ".svg")
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _panel(color: Color = CityArtDirection.UI_PAPER) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(color, 16)
	style.set_content_margin_all(15)
	style.border_color = CityArtDirection.UI_LINE
	style.set_border_width_all(1)
	style.shadow_color = CityArtDirection.UI_SHADOW
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _theme() -> Theme:
	var theme := super._theme()
	var font := load("res://assets/fonts/NunitoSans.ttf") as FontFile
	var text_server := TextServerManager.get_primary_interface()
	body_font = FontVariation.new()
	body_font.base_font = font
	body_font.variation_opentype = {text_server.name_to_tag("wght"):600.0, text_server.name_to_tag("opsz"):14.0}
	display_font = FontVariation.new()
	display_font.base_font = font
	display_font.variation_opentype = {text_server.name_to_tag("wght"):800.0, text_server.name_to_tag("opsz"):24.0}
	theme.default_font = body_font
	theme.set_font("display", "City", display_font)
	theme.default_font_size = 16
	for name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := _style(CityArtDirection.UI_HOVER, 12)
		style.set_content_margin_all(10)
		if name == "hover":
			style.bg_color = CityArtDirection.UI_HOVER
		elif name == "pressed":
			style.bg_color = CityArtDirection.UI_PRESSED
		elif name == "disabled":
			style.bg_color = CityArtDirection.UI_DISABLED
		elif name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = GREEN
			style.set_border_width_all(2)
		theme.set_stylebox(name, "Button", style)
	theme.set_stylebox("panel", "PopupMenu", _style(PAPER, 5))
	return theme

func _primary(button: Button) -> void:
	for name: String in ["normal", "hover", "pressed"]:
		var style := _style(GREEN if name == "normal" else CityArtDirection.UI_PRIMARY_HOVER, 11)
		style.set_content_margin_all(11)
		button.add_theme_stylebox_override(name, style)
	for name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(name, CityArtDirection.UI_ON_PRIMARY)

func _create_header() -> void:
	header = PanelContainer.new()
	header.name = "Header"
	header.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var row := _hbox(header, 10)
	var company := _panel()
	var identity_style := _style(MARINE_PANEL, 16)
	identity_style.set_content_margin_all(10)
	identity_style.border_color = MARINE_LINE
	identity_style.set_border_width_all(1)
	identity_style.shadow_color = CityArtDirection.UI_SHADOW
	identity_style.shadow_size = 8
	identity_style.shadow_offset = Vector2(0, 3)
	company.add_theme_stylebox_override("panel", identity_style)
	row.add_child(company)
	var identity_row := _hbox(company, 10)
	var badge := PanelContainer.new()
	var badge_style := _style(Color("295d5c"), 13)
	badge_style.set_content_margin_all(6)
	badge_style.border_color = Color("5e8984")
	badge_style.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(badge)
	level_badge = _label("1", 19, Color.WHITE)
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(level_badge)
	var identity := _vbox(identity_row, 3)
	var name_label := _label("Liman Mahallesi", 17, PAPER)
	name_label.add_theme_font_override("font", display_font)
	identity.add_child(name_label)
	worth_label = _label("", 11, MARINE_MUTED)
	worth_label.mouse_filter = Control.MOUSE_FILTER_PASS
	identity.add_child(worth_label)
	experience_bar = ProgressBar.new()
	experience_bar.show_percentage = false
	experience_bar.max_value = 150
	experience_bar.custom_minimum_size.y = 3
	var xp_background := _style(MARINE_LINE, 2)
	xp_background.set_content_margin_all(0)
	var xp_fill := _style(Color("8dc5ac"), 2)
	xp_fill.set_content_margin_all(0)
	experience_bar.add_theme_stylebox_override("background", xp_background)
	experience_bar.add_theme_stylebox_override("fill", xp_fill)
	identity.add_child(experience_bar)
	level_label = _label("", 12)
	level_label.hide()
	identity.add_child(level_label)
	_spacer(row)
	var funds := _panel()
	var funds_style := identity_style.duplicate() as StyleBoxFlat
	funds_style.bg_color = PAPER
	funds_style.border_color = CityArtDirection.UI_LINE
	funds_style.set_content_margin_all(10)
	funds.add_theme_stylebox_override("panel", funds_style)
	funds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(funds)
	var funds_row := _hbox(funds, 9)
	var coin_icon := _icon("coin", 30)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	funds_row.add_child(coin_icon)
	var funds_text := _vbox(funds_row, 0)
	funds_text.add_child(_label("NAKİT", 10, MUTED))
	cash_label = _label("", 26, INK)
	cash_label.custom_minimum_size.x = 105
	funds_text.add_child(cash_label)
	save_label = _label("", 11)
	save_label.hide()
	row.add_child(save_label)
	var menu := _button("", "pause")
	menu.name = "Menu"
	menu.tooltip_text = CityLocale.t("Menü")
	menu.icon = load("res://assets/ui/menu.svg")
	menu.add_theme_constant_override("icon_max_width", 22)
	menu.custom_minimum_size = Vector2(50, 50)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(menu)

func _create_objective() -> void:
	objective_panel = _panel()
	objective_panel.custom_minimum_size.x = 292
	root.add_child(objective_panel)
	var column := _vbox(objective_panel, 9)
	purpose_label = _label("Build a thriving neighbourhood", 17, INK)
	purpose_label.add_theme_font_override("font", display_font)
	purpose_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose_label.custom_minimum_size.x = 260
	column.add_child(purpose_label)
	opening_steps = _hbox(column, 6)
	for text: String in ["Sign", "Collect", "Build"]:
		var step := _label(text, 12, MUTED)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opening_steps.add_child(step)
		step_labels.append(step)
	var metric_surface := PanelContainer.new()
	var metric_style := _style(Color("edf2e9"), 10)
	metric_style.set_content_margin_all(8)
	metric_surface.add_theme_stylebox_override("panel", metric_style)
	column.add_child(metric_surface)
	neighbourhood_flow = _hbox(metric_surface, 5)
	for caption: String in ["Homes", "Neighbours", "Cafe visitors"]:
		var cell := _vbox(neighbourhood_flow, 1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _label("0", 22, CityArtDirection.UI_PRIMARY)
		cell.add_child(value)
		cell.add_child(_label(caption, 11, MUTED))
		neighbourhood_values.append(value)
	neighbourhood_caption = _label("", 12, MUTED)
	neighbourhood_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neighbourhood_caption.custom_minimum_size.x = 260
	column.add_child(neighbourhood_caption)
	var row := _hbox(column, 9)
	row.add_child(_icon("star", 21))
	goal_label = _label("", 15, INK)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size.x = 176
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(goal_label)
	goal_progress = _label("", 12, CityArtDirection.UI_PRIMARY)
	row.add_child(goal_progress)
	goal_toggle = _button("−", "toggle_guide")
	goal_toggle.set_meta("intent", "quiet")
	goal_toggle.name = "GoalSteps"
	goal_toggle.custom_minimum_size = Vector2(34, 34)
	goal_toggle.add_theme_font_size_override("font_size", 15)
	row.add_child(goal_toggle)
	goal_detail = _label("", 13, MUTED)
	goal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(goal_detail)
	goal_checks = _label("", 13, CityArtDirection.UI_PRIMARY)
	goal_checks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(goal_checks)
	goal_claim = _button("", "journey", "", true)
	goal_claim.name = "JourneyAction"
	goal_claim.add_theme_font_size_override("font_size", 14)
	goal_claim.custom_minimum_size.y = 44
	column.add_child(goal_claim)

func refresh_goal() -> void:
	if state.growth_economy and last_opening_stage == 2 and state.opening_stage < 0:
		guide_expanded = true
	last_opening_stage = state.opening_stage
	super.refresh_goal()
	if neighbourhood_values.is_empty(): return
	var now := int(Time.get_unix_time_from_system())
	var pulse := CityNeighbourhood.describe(state, now)
	for index in range(3):
		var number := str(pulse[["homes", "residents", "served"][index]])
		var label := neighbourhood_values[index]
		if label.text != number and label.is_visible_in_tree():
			label.pivot_offset = label.size * .5
			var emphasis := create_tween()
			emphasis.tween_property(label, "scale", Vector2.ONE * 1.12, .12)
			emphasis.tween_property(label, "scale", Vector2.ONE, .25)
		label.text = number
	var inspecting := context_panel.visible or shop_panel.visible
	var saving_for_district := state.growth_economy and state.opening_stage < 0 and state.unlocked_columns < CityState.COLUMNS and state.active_project.is_empty()
	neighbourhood_flow.get_parent().visible = not inspecting and state.opening_stage != 0
	opening_steps.visible = state.opening_stage >= 0 and not inspecting
	if opening_steps.visible:
		var labels := ["Sign", "Collect", "Invest" if state.growth_economy else "Build"]
		for index in range(3):
			step_labels[index].text = ("✓ " if index < state.opening_stage else str(index + 1) + " · ") + CityLocale.t(labels[index])
			step_labels[index].add_theme_color_override("font_color", GREEN if index <= state.opening_stage else MUTED)
			step_labels[index].add_theme_font_override("font", display_font if index == state.opening_stage else body_font)
	purpose_label.visible = true
	neighbourhood_caption.visible = inspecting or not guide_expanded or pulse.served < pulse.reachable
	worth_label.text = CityLocale.f("Current income {0}/min", [money(pulse.income)])
	worth_label.tooltip_text = CityLocale.f("Rent {0}/min · cafes {1}/min", [money(roundi(pulse.rent)), money(pulse.trade)]) + "\n" + CityLocale.t("Active leases: net rent averaged per minute. Cafes: current connected trade. Rewards are excluded; income changes when leases end.")
	if pulse.residents == 0:
		neighbourhood_caption.text = CityLocale.t("Sign leases → welcome neighbours → open local shops.")
	elif pulse.served < pulse.reachable:
		neighbourhood_caption.text = CityLocale.f("Cafes are full · {0} neighbours waiting", [pulse.reachable - pulse.served])
	elif pulse.reachable < pulse.residents:
		neighbourhood_caption.text = CityLocale.f("{0} neighbours need a walkable cafe.", [pulse.residents - pulse.served])
	else:
		neighbourhood_caption.text = CityLocale.t("Every neighbour has a walkable cafe.")
	if inspecting and state.milestone < 3:
		neighbourhood_caption.text = CityLocale.t("Sign leases → welcome neighbours → open local shops.")
	var names := ["1 · Collect your starting capital", "2 · Make room for a third home", "3 · Turn neighbours into customers", "4 · Choose your home's role", "5 · Open eight more plots"]
	if state.milestone < names.size(): goal_label.text = CityLocale.t(names[state.milestone])
	if state.opening_stage in [0, 1]:
		goal_label.text = CityLocale.t("Tap the empty home to sign." if state.opening_stage == 0 else "Your cafe is earning")
		neighbourhood_caption.text = CityLocale.t("Homes bring neighbours. Neighbours keep cafes busy.")
		goal_claim.visible = not inspecting
		if state.opening_stage == 1:
			var next := CityJourney.describe(state, now)
			if next.action == "guide_home":
				var available := state.collectible(int(next.target), now)
				if available > 0: goal_claim.text = CityLocale.f("Tahsil et {0}", [money(available)])
	elif state.opening_stage == 2:
		goal_label.text = CityLocale.t("Choose your first investment" if state.growth_economy else "Make room for another home")
		if not state.growth_economy and state.street_edges.size() > CityStreets.seed_edges().size() and state.count_kind("Konut") >= 3:
			goal_label.text = CityLocale.t("Your new home is taking shape")
			goal_claim.hide()
	elif saving_for_district:
		goal_label.text = CityLocale.t("Grow into the next district")
		goal_progress.show()
		goal_progress.text = CityLocale.f("{0} / {1}", [money(mini(state.cash, CityState.EXPANSION_PRICE)), money(CityState.EXPANSION_PRICE)])
	goal_label.custom_minimum_size.x = 116 if saving_for_district else 176
	# The live neighbourhood is the persistent HUD. Instructions are an optional
	# layer; avoid repeating the same purpose as a paragraph and a checklist.
	goal_detail.visible = false
	goal_checks.visible = false
	goal_label.tooltip_text = "\n".join(CityJourney.describe(state, int(Time.get_unix_time_from_system())).checks)
	objective_panel.reset_size()
	dock.visible = not context_panel.visible and not shop_panel.visible and state.opening_stage not in [0, 1]

func _create_dock() -> void:
	dock = _panel()
	var rail := _style(MARINE_PANEL, 17)
	rail.set_content_margin_all(7)
	rail.border_color = MARINE_LINE
	rail.set_border_width_all(1)
	rail.shadow_color = CityArtDirection.UI_SHADOW
	rail.shadow_size = 12
	rail.shadow_offset = Vector2(0, 4)
	dock.add_theme_stylebox_override("panel", rail)
	root.add_child(dock)
	var row := _hbox(dock, 3)
	var build := CityUI.button("İnşa et", func() -> void: action_requested.emit("catalog", ""), root.theme, true)
	build.custom_minimum_size = Vector2(120, 50)
	build.icon = load("res://assets/ui/house.svg")
	build.add_theme_constant_override("icon_max_width", 21)
	build.add_theme_font_size_override("font_size", 14)
	row.add_child(build)
	var streets := _button("Sokaklar", "streets")
	streets_button = streets
	_dock_button(streets)
	streets.custom_minimum_size = Vector2(112, 50)
	streets.icon = load("res://assets/ui/streets.svg")
	streets.add_theme_constant_override("icon_max_width", 20)
	row.add_child(streets)
	var move := _button("Taşı", "move")
	_dock_button(move)
	move.custom_minimum_size = Vector2(96, 50)
	move.icon = load("res://assets/ui/move.svg")
	move.add_theme_constant_override("icon_max_width", 19)
	row.add_child(move)
	var home := _button("Merkez", "home")
	_dock_button(home)
	home.custom_minimum_size = Vector2(126, 50)
	home.icon = load("res://assets/ui/compass.svg")
	home.add_theme_constant_override("icon_max_width", 19)
	row.add_child(home)
	var zoom := _panel()
	var zoom_style := rail.duplicate() as StyleBoxFlat
	zoom_style.bg_color = PAPER
	zoom_style.border_color = CityArtDirection.UI_LINE
	zoom_style.set_content_margin_all(5)
	zoom_style.set_corner_radius_all(17)
	zoom.add_theme_stylebox_override("panel", zoom_style)
	zoom.name = "ZoomControls"
	root.add_child(zoom)
	var zoom_row := _hbox(zoom, 0)
	for spec: Array in [["−", "zoom_out"], ["+", "zoom_in"]]:
		var button := _button(spec[0], spec[1])
		button.set_meta("intent", "quiet")
		button.custom_minimum_size = Vector2(39, 42)
		zoom_row.add_child(button)

func _dock_button(button: Button) -> void:
	button.set_meta("intent", "quiet_dark")
	button.add_theme_font_size_override("font_size", 14)
	for name: String in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		button.add_theme_color_override(name, PAPER)

func _build_design_picker() -> void:
	var row := _hbox(context_body, 5)
	row.name = "HomeArchitecture"
	for design: String in CityState.HOME_DESIGNS:
		var button := _button({"veranda":"Veranda", "bay":"Cumba", "courtyard":"Avlu"}[design], "architecture_choice", design, architecture_choice == design)
		button.custom_minimum_size = Vector2(82, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		row.add_child(button)
	_text(context_body, CityResidentialDesigns.NAMES[architecture_choice], 12, MUTED)

func refresh() -> void:
	super.refresh()
	cash_label.text = _compact_money(state.cash)
	experience_bar.value = state.experience % 150
	cash_label.tooltip_text = money(state.cash)
	if is_instance_valid(level_badge):
		level_badge.text = str(state.level())

func _compact_money(amount: int) -> String:
	if amount < 1000000:
		return money(amount)
	var divisor := 1000000000.0 if amount >= 1000000000 else 1000000.0
	var number := "%.2f" % (amount / divisor)
	if CityLocale.language == "en":
		return "$" + number + ("B" if divisor > 1000000 else "M")
	return number.replace(".", ",") + (" Mr $" if divisor > 1000000 else " Mn $")

func pulse_cash() -> void:
	cash_label.pivot_offset = cash_label.size * .5
	var tween := create_tween()
	tween.tween_property(cash_label, "scale", Vector2.ONE * 1.08, .09)
	tween.tween_property(cash_label, "scale", Vector2.ONE, .22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func collection_feedback(point: Vector2) -> void:
	var flight := CityCollectionFeedback.new()
	root.add_child(flight)
	flight.delivered.connect(pulse_cash, CONNECT_ONE_SHOT)
	flight.play(point, cash_label.get_global_rect().get_center())

func _layout() -> void:
	super._layout()
	if header == null:
		return
	if state.opening_stage in [0, 1]:
		dock.hide()
	header.position = Vector2(24, 18)
	header.size.y = 66
	objective_panel.position = Vector2(24, 110)
	objective_panel.size.x = 292
	if context_panel.visible:
		context_panel.size.x = 294

func _context_heading(title: String, kicker: String) -> void:
	if state.valid_index(context_index):
		var specialization: String = str(state.lots[context_index].get("specialization", "neutral"))
		if specialization != "neutral":
			kicker += " · " + CityLocale.t("Butik" if specialization == "boutique" else "Canlı sokak")
	var row := _hbox(context_body, 8)
	var text := _vbox(row, 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(CityLocale.t(kicker).to_upper(), 10, MUTED))
	var heading := _label(title, 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(heading)
	var close := _button("×", "close")
	close.custom_minimum_size = Vector2(36, 36)
	row.add_child(close)

func show_context(index: int, mode: String = "normal", kind: String = "") -> void:
	if mode == "street":
		show_street_context(street_key)
		return
	if mode != "renovation":
		super.show_context(index, mode, kind)
		return
	context_index = index
	context_mode = mode
	context_kind = ""
	context_phase = _phase(index)
	clock_label = null
	clock_action = null
	clock_progress = null
	_clear(context_body)
	_context_heading("Binanın geleceği", "Yenileme planı")
	_text(context_body, "İkinci seviyede binanın mahalledeki rolünü seç.", 14, MUTED)
	for choice: String in ["boutique", "community"]:
		var title := CityLocale.t("Butik konut" if choice == "boutique" else "Canlı sokak")
		var detail := CityLocale.t("+%20 kira · %25 daha az kiracı" if choice == "boutique" else "+%50 kiracı · %10 daha az kira")
		var button := _button(("● " if choice == specialization_choice else "○ ") + title + "\n" + detail, "specialization_choice", choice)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		context_body.add_child(button)
	_text(context_body, "Oranlar ikinci seviyenin standart değerlerine göredir. Kiracı sayısı yakın işletmelerin müşterisini değiştirir.", 12, MUTED)
	context_body.add_child(_button(CityLocale.f("Planı uygula · {0}", [money(state.upgrade_price(index))]), "confirm_renovation", "", true))
	context_panel.show()
	context_panel.size = Vector2(310, 0)
	context_panel.reset_size()
	dock.hide()

func show_street_context(key: String) -> void:
	street_key = key
	context_index = -1
	context_mode = "street"
	context_phase = "street"
	clock_label = null
	clock_action = null
	clock_progress = null
	_clear(context_body)
	var now := int(Time.get_unix_time_from_system())
	var built: bool = key in state.street_edges
	var quote := state.street_quote(key, now)
	var shortcut := not built and int(quote.income_change) > 0
	_context_heading("Sokağı şekillendir" if built else ("Daha kısa bir yol" if shortcut else "Yeni bir bağlantı"), "SOKAK PLANI")
	if built:
		_text(context_body, "Bu sokak mahallendeki evleri ve yerel işletmeleri birbirine bağlıyor.", 14, MUTED)
		var error := state.street_error(key, true)
		if error.is_empty():
			_text(context_body, CityLocale.f("Geri kazanılan {0}", [money(int(quote.refund))]), 20)
			context_body.add_child(_button("Sokağı kaldır", "remove_street", key))
		else:
			_text(context_body, error, 13, MUTED)
	else:
		_text(context_body, money(int(quote.price)), 28)
		var plots := int(quote.new_frontages)
		if plots > 0:
			_text(context_body, CityLocale.t("1 arsaya yeni erişim") if plots == 1 else CityLocale.f("{0} arsaya yeni erişim", [plots]), 17)
		if float(quote.customer_change) > 0:
			_text(context_body, CityLocale.f("+{0} yerel müşteri", [snappedf(float(quote.customer_change), .1)]), 17)
		elif plots == 0:
			_text(context_body, "Bir sonraki sokağın için yeni bir yön.", 15, MUTED)
		var delta := int(quote.income_change)
		_text(context_body, CityLocale.f("Yerel gelir {0} / 30 sn", [("+" if delta >= 0 else "") + money(delta)]) if delta != 0 else CityLocale.t("Mevcut ticaret geliri değişmiyor."), 17 if delta != 0 else 13, Color("2d7866") if delta != 0 else MUTED)
		_text(context_body, "Tahmin mevcut kiracılara göre. Yeni konutlar ve kısayollar işletmelerin erişimini değiştirir.", 12, MUTED)
		var error := state.street_error(key)
		if not error.is_empty(): _text(context_body, error, 13, CityArtDirection.UI_ALERT)
		var button := _button("Sokağı inşa et", "build_street", key, true)
		button.disabled = not error.is_empty()
		context_body.add_child(button)
	context_body.add_child(_button("Şehre dön", "exit_streets"))
	context_panel.show()
	context_panel.size = Vector2(310, 0)
	context_panel.reset_size()
	dock.hide()
	_layout()

func set_street_planning(active: bool) -> void:
	if not is_instance_valid(streets_button): return
	streets_button.text = CityLocale.t("Bitti" if active else "Sokaklar")
	streets_button.set_meta("intent", "gold" if active else "quiet_dark")
	(streets_button as CityGameButton).apply_ink()
	streets_button.queue_redraw()

func _upgrade_button(index: int) -> void:
	if state.catalog.is_residential(state.lots[index].kind) and int(state.lots[index].level) == 1:
		var button := _button(CityLocale.f("Yenileme planı · {0}", [money(state.upgrade_price(index))]), "renovation_plan")
		button.add_theme_font_size_override("font_size", 14)
		button.disabled = state.cash < state.upgrade_price(index)
		context_body.add_child(button)
	else:
		super._upgrade_button(index)

func show_shop(category: String = "Konut") -> void:
	active_category = category
	preferred_shop_width = 740 if category == "Konut" else 580
	hide_context()
	_clear(shop_body)
	var heading := _hbox(shop_body, 12)
	heading.add_child(_label("Yapı kataloğu", 21))
	_spacer(heading)
	for name: String in ["Konut", "İşletme", "Çevre"]:
		var button := _button(name, "category", name, name == category)
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size.y = 36
		heading.add_child(button)
	heading.add_child(_button("×", "close_shop"))
	var row := _hbox(shop_body, 12)
	for kind: String in state.catalog.category_items(category):
		var definition := state.catalog.get_building(kind)
		var card := PanelContainer.new()
		var card_style := _style(Color("f1f3ea"), 12)
		card_style.set_content_margin_all(8)
		card_style.border_color = CityArtDirection.UI_LINE
		card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var column := _vbox(card, 4)
		column.custom_minimum_size.x = 146
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var preview := TextureRect.new()
		preview.texture = building_previews.get(kind)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(146, 108)
		column.add_child(preview)
		var name := _text(column, definition.name, 14)
		name.add_theme_font_override("font", display_font)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var role: String = {"cottage":"4 kiracı · 3 tasarım", "apartments":"12 kiracı · yoğun konut", "villa":"3 kiracı · yüksek kira", "office":"18 kiracı · kurumsal", "cafe":"2 sokak parçası erişim", "park":"Komşuya +%12 kira"}.get(kind, "")
		var role_label := _text(column, role, 11, MUTED)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var unlocked := state.level() >= int(definition.unlock_level)
		var button := _button(money(int(definition.price)) if unlocked else CityLocale.f("Şirket seviyesi {0}", [int(definition.unlock_level)]), "choose_building", kind)
		button.add_theme_font_size_override("font_size", 14)
		button.disabled = not unlocked or state.cash < int(definition.price)
		column.add_child(button)
	_text(shop_body, "Arsa bedeli ve mahalle etkileri yerleşim önizlemesinde gösterilir.", 12, MUTED)
	shop_panel.show()
	objective_panel.hide()
	dock.hide()
	_layout()

func hide_shop() -> void:
	super.hide_shop()
	objective_panel.show()

func set_hint(text: String) -> void:
	super.set_hint(text)
	hint_label.add_theme_color_override("font_outline_color", PAPER)
	hint_label.add_theme_constant_override("outline_size", 4)
