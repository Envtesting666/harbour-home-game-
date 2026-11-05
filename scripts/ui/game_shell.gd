class_name CityGameShell
extends CanvasLayer
## Title, pause and preferences stay outside the in-world HUD.

signal action_requested(action: String, value: String)
var root: Control
var ui_theme: Theme
var preferences: CityPreferences
var has_save := false
var page := ""
var return_page := "title"
var card: Control
var headline: Control
var city: CityState
var investment_balance: Label
var investment_collect: Button

func setup(theme: Theme, prefs: CityPreferences, saved: bool) -> void:
	layer = 20
	ui_theme = theme
	preferences = prefs
	has_save = saved
	root = Control.new()
	root.theme = theme
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(_layout)
	root.hide()

func is_open() -> bool:
	return root != null and root.visible

func close() -> void:
	page = ""
	root.hide()

func show_page(mode: String) -> void:
	if mode in ["title", "pause"]:
		return_page = mode
	page = mode
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.show()
	root.theme = ui_theme
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.085, 0.14, 0.64 if mode != "title" else 0.20)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = null
	headline = null
	if mode == "title":
		_title()
	else:
		card = CityUI.panel(root, ui_theme)
		card.custom_minimum_size.x = 490
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 14)
		card.add_child(column)
		match mode:
			"pause": _pause(column)
			"settings": _settings(column)
			"help": _help(column)
			"projects": _projects(column)
			"investments": _investments(column)
			"new_confirm":
				column.add_child(CityUI.label("Yeni bir mahalle kurulsun mu?", 25, CityArtDirection.UI_INK, ui_theme))
				column.add_child(CityUI.label("Mevcut mahalle kaydının yerine yeni bir başlangıç kaydedilecek.", 15, CityArtDirection.UI_MUTED, ui_theme, true))
				column.add_child(CityUI.button("Yeni mahalleyi başlat", func() -> void: action_requested.emit("new_game", ""), ui_theme, true))
				column.add_child(CityUI.button("İptal", func() -> void: show_page("title"), ui_theme))
	_layout()
	call_deferred("_layout")

func _title() -> void:
	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.46, 1])
	gradient.colors = PackedColorArray([Color("102f4b"), Color(0.04, 0.14, 0.23, 0.91), Color(0.04, 0.14, 0.23, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 8
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	backdrop.texture = texture
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 350
	column.add_theme_constant_override("separation", 9)
	root.add_child(column)
	headline = column
	column.add_child(CityUI.label("HARBOUR", 48, Color.WHITE, ui_theme))
	column.add_child(CityUI.label("& HOME", 27, CityArtDirection.UI_GOLD, ui_theme))
	var available := 0
	if has_save and city != null:
		for index in range(city.lots.size()): available += city.collectible(index, int(Time.get_unix_time_from_system()))
	column.add_child(CityUI.label(CityLocale.f("{0} tahsil edilmeyi bekliyor", [CityLocale.money(available)]) if available > 0 else CityLocale.t("Kendi mahalleni kur."), 18, Color("d3e4f2"), ui_theme))
	if not has_save:
		column.add_child(CityUI.label("Rent out homes and grow your seaside town.", 16, Color("d3e4f2"), ui_theme, true))
	var gap := Control.new()
	gap.custom_minimum_size.y = 15
	column.add_child(gap)
	column.add_child(CityUI.button("Devam et" if has_save else "Mahalleni kur", func() -> void: action_requested.emit("play", ""), ui_theme, true))
	if has_save:
		column.add_child(CityUI.button("Yeni mahalle", func() -> void: show_page("new_confirm"), ui_theme))
	column.add_child(CityUI.button("Ayarlar", func() -> void: show_page("settings"), ui_theme))
	column.add_child(CityUI.button("Nasıl oynanır", func() -> void: show_page("help"), ui_theme))
	column.add_child(CityUI.button("Çıkış", func() -> void: action_requested.emit("quit", ""), ui_theme))
	column.modulate.a = .55
	column.create_tween().tween_property(column, "modulate:a", 1.0, .24)

func _pause(column: VBoxContainer) -> void:
	column.add_child(CityUI.label("Şehir seni bekliyor.", 27, CityArtDirection.UI_INK, ui_theme))
	column.add_child(CityUI.label("Kiran hazır olduğunda bekler. Geri döndüğünde tahsil edebilirsin.", 14, CityArtDirection.UI_MUTED, ui_theme, true))
	column.add_child(CityUI.button("Şehre dön", func() -> void: action_requested.emit("play", ""), ui_theme, true))
	column.add_child(CityUI.button("Ayarlar", func() -> void: show_page("settings"), ui_theme))
	column.add_child(CityUI.button("Nasıl oynanır", func() -> void: show_page("help"), ui_theme))
	if city != null and city.milestone >= 5:
		column.add_child(CityUI.button("Proje seç", func() -> void: show_page("projects"), ui_theme))
	column.add_child(CityUI.button("Ana menü", func() -> void: show_page("title"), ui_theme))
	column.add_child(CityUI.button("Çıkış", func() -> void: action_requested.emit("quit", ""), ui_theme))

func _settings(column: VBoxContainer) -> void:
	column.add_child(CityUI.label("Ayarlar", 28, CityArtDirection.UI_INK, ui_theme))
	column.add_child(CityUI.label("Dil", 14, CityArtDirection.UI_MUTED, ui_theme))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	for locale: String in ["en", "tr"]:
		var button := CityUI.button("English" if locale == "en" else "Türkçe", func() -> void: action_requested.emit("language", locale), ui_theme, preferences.language == locale)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	column.add_child(CityUI.label("Ses efektleri", 14, CityArtDirection.UI_MUTED, ui_theme))
	var slider := CityVolumeSlider.new()
	slider.name = "EffectsVolume"
	slider.max_value = 100
	slider.value = preferences.effects * 100
	slider.custom_minimum_size.y = 36
	slider.value_changed.connect(func(value: float) -> void: action_requested.emit("effects", str(value / 100)))
	column.add_child(slider)
	column.add_child(CityUI.button("Tam ekran", func() -> void: action_requested.emit("fullscreen", ""), ui_theme))
	column.add_child(CityUI.label("Değişiklikler otomatik kaydedilir.", 12, CityArtDirection.UI_MUTED, ui_theme))
	column.add_child(CityUI.button("Geri", func() -> void: show_page(return_page), ui_theme, true))

func _help(column: VBoxContainer) -> void:
	column.add_child(CityUI.label("Mahalleni şekillendir", 26, CityArtDirection.UI_INK, ui_theme))
	for text: String in ["Sokak kur → Evleri bağla → Kontrat imzala → Mahalleni büyüt", "Kafeler yürünebilir sokak bağlantısı olan kiracılara hizmet verir. Parklar komşu evlerin kirasını artırır.", "Ekranı sürükle. Tekerlek veya iki parmakla yakınlaş. Esc menüyü açar.", "Kiran hazır olduğunda bekler. Geri döndüğünde tahsil edebilirsin."]:
		column.add_child(CityUI.label(text, 15, CityArtDirection.UI_MUTED, ui_theme, true))
	column.add_child(CityUI.button("Geri", func() -> void: show_page(return_page), ui_theme, true))

func _projects(column: VBoxContainer) -> void:
	column.add_child(CityUI.label("Mahallene bir yön ver", 27, CityArtDirection.UI_INK, ui_theme))
	column.add_child(CityUI.label("İstediğin zaman yön değiştirebilirsin. Kazanılan ödüller bir kez alınır.", 13, CityArtDirection.UI_MUTED, ui_theme, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for id: String in CityProjects.DEFINITIONS:
		var definition: Dictionary = CityProjects.DEFINITIONS[id]
		var content := VBoxContainer.new()
		content.custom_minimum_size.x = 240
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		row.add_child(content)
		content.add_child(CityUI.label(definition.name, 20, CityArtDirection.UI_INK, ui_theme))
		content.add_child(CityUI.label(definition.detail, 14, CityArtDirection.UI_MUTED, ui_theme, true))
		var progress := ProgressBar.new()
		progress.show_percentage = false
		progress.max_value = int(definition.target)
		progress.value = CityProjects.progress(city, id, int(Time.get_unix_time_from_system()))
		progress.custom_minimum_size.y = 6
		content.add_child(progress)
		content.add_child(CityUI.label(CityLocale.t("ÖDÜL") + "  " + CityLocale.money(int(definition.reward)), 14, CityArtDirection.UI_INK, ui_theme))
		var done: bool = id in city.completed_projects
		var button := CityUI.button("Tamamlandı" if done else "Projeyi seç", func() -> void: action_requested.emit("select_project", id), ui_theme, city.active_project == id)
		button.disabled = done
		content.add_child(button)
	column.add_child(CityUI.button("Şehre dön", func() -> void: action_requested.emit("play", ""), ui_theme))

func _investments(column: VBoxContainer) -> void:
	var now := int(Time.get_unix_time_from_system())
	column.add_child(CityUI.label("Choose your first investment", 27, CityArtDirection.UI_INK, ui_theme))
	var funding := HBoxContainer.new()
	funding.add_theme_constant_override("separation", 10)
	column.add_child(funding)
	investment_balance = CityUI.label("", 15, CityArtDirection.UI_INK, ui_theme)
	investment_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	funding.add_child(investment_balance)
	investment_collect = CityUI.button("", func() -> void: action_requested.emit("investment_collect", ""), ui_theme)
	investment_collect.name = "InvestmentCollect"
	funding.add_child(investment_collect)
	for kind: String in ["cottage", "cafe", "park"]:
		var title: String
		var detail: String
		var target := -1
		var price := 0
		match kind:
			"cottage", "park":
				var site := CityJourney.investment_site(city, kind, now)
				target = int(site.index)
				price = int(site.price)
				title = "Build a home" if kind == "cottage" else "Build a park"
				detail = "Lease a home for rent and bring four more neighbours." if kind == "cottage" else "Add 12% to new leases in neighbouring homes."
				if int(site.road) > 0:
					detail = CityLocale.t(detail) + " " + CityLocale.f("Includes a {0} street.", [CityLocale.money(int(site.road))])
			"cafe":
				for index in range(city.lots.size()):
					if city.lots[index].kind == "cafe" and int(city.lots[index].level) < 3:
						target = index
						break
				if target >= 0: price = city.upgrade_price(target)
				title = "Expand your cafe"
				detail = "Add eight seats and earn more per customer."
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		copy.add_child(CityUI.label(title, 18, CityArtDirection.UI_INK, ui_theme))
		copy.add_child(CityUI.label(detail, 14, CityArtDirection.UI_MUTED, ui_theme, true))
		var choice := CityUI.button(CityLocale.money(price) if target >= 0 else CityLocale.t("Find a site"), func() -> void: action_requested.emit("investment_plan", kind), ui_theme)
		choice.name = "Plan" + kind.capitalize()
		choice.tooltip_text = CityLocale.t("Preview investment")
		choice.custom_minimum_size.x = 112
		row.add_child(choice)
	column.add_child(CityUI.button("Keep exploring", func() -> void: action_requested.emit("play", ""), ui_theme))
	update_investment_balance(now)

func update_investment_balance(now: int) -> void:
	if page != "investments" or not is_instance_valid(investment_balance): return
	var pending := 0
	for index in range(city.lots.size()):
		if city.lots[index].kind == "cafe": pending += city.collectible(index, now)
	investment_balance.text = CityLocale.f("Cash on hand  {0}", [CityLocale.money(city.cash)])
	investment_collect.text = CityLocale.f("Tahsil et {0}", [CityLocale.money(pending)])
	investment_collect.disabled = pending <= 0

func _layout() -> void:
	if root == null:
		return
	var available := root.get_viewport_rect().size
	if is_instance_valid(headline):
		headline.position = Vector2(48, 24 if available.y < 620 else maxf(25, available.y * 0.12))
		headline.size.x = 350
	if is_instance_valid(card):
		card.custom_minimum_size.x = minf(860 if page == "projects" else 490, available.x - 48)
		card.size = Vector2(card.custom_minimum_size.x, 0)
		card.reset_size()
		card.position = Vector2((available.x - card.size.x) / 2, maxf(16, (available.y - card.size.y) / 2))
