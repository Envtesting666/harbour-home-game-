extends Node2D
## Composition root and interaction state machine. The model is UI-independent.

enum Mode { NORMAL, BUILD, MOVE, STREETS }

var catalog: CityCatalog
var state: CityState
var saves: CitySaveStore
var world: CityWorld3D
var hud: TownHUD
var audio: CityFeedbackAudio
var mode := Mode.NORMAL
var selected := -1
var building_kind := ""
var moving_source := -1
var clock := 0.0
var autosave_clock := 0.0
var capture_dir := ""
var art_review := false
var initialized := false
var preferences: CityPreferences
var shell: CityGameShell
var lease_sheet: CityLeaseSheet
var introduction_pending := false
var pending_placement: Dictionary = {}
var noticed_trade_peak := 0
var journey_review := false
var resume_pending := false
var resume_review := false
var legacy_review := false
var arrival_home := -1

func _ready() -> void:
	get_tree().auto_accept_quit = false
	catalog = CityCatalog.new()
	state = CityState.new(catalog)
	var save_path := "user://city/save.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_path = argument.trim_prefix("--save-dir=").path_join("save.json")
		elif argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
		elif argument == "--mobile-layout":
			get_window().content_scale_size = Vector2i(960, 540)
		elif argument == "--art-review":
			art_review = true
		elif argument == "--journey-review":
			journey_review = true
		elif argument == "--resume-review":
			resume_review = true
		elif argument == "--legacy-review":
			legacy_review = true
	if legacy_review or journey_review:
		state.seed(_now()) # Explicit old-town regression fixture, not the new opening.
	else:
		state.seed_live(_now())
	if not capture_dir.is_empty() and save_path == "user://city/save.json":
		push_error("Visual tests require an explicit --save-dir test profile.")
		get_tree().quit(1)
		return
	preferences = CityPreferences.new(save_path.get_base_dir().path_join("settings.cfg"))
	var boot := CityBootSplash.new()
	add_child(boot)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_window().title = "Harbour & Home · " + str(ProjectSettings.get_setting("application/config/version", "0.5.0"))
	saves = CitySaveStore.new(save_path)
	var restored := saves.load_into(state)
	resume_pending = restored
	introduction_pending = not restored or state.opening_stage == 0 or (state.rent_collected == 0 and state.contracts_signed == 0 and state.milestone == 0)
	state.advance(_now())
	noticed_trade_peak = state.commerce_peak_customers
	world = CityWorld3D.new()
	world.name = "CityWorld"
	world.setup(state)
	add_child(world)
	hud = TownHUD.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.building_previews = world.preview_textures()
	hud.setup(state, null)
	if state.milestone >= 3:
		hud.guide_expanded = false
		hud.refresh_goal()
	audio = CityFeedbackAudio.new()
	add_child(audio)
	audio.set_level(preferences.effects)
	shell = CityGameShell.new()
	add_child(shell)
	shell.setup(hud.root.theme, preferences, restored)
	shell.city = state
	shell.action_requested.connect(_on_action)
	lease_sheet = CityLeaseSheet.new()
	add_child(lease_sheet)
	lease_sheet.setup(hud.root.theme)
	lease_sheet.sign_requested.connect(_on_sign_requested)
	lease_sheet.pen_started.connect(audio.begin_pen)
	lease_sheet.pen_stopped.connect(audio.stop_pen)
	lease_sheet.dismissed.connect(func() -> void:
		hud.root.visible = not shell.is_open()
		if arrival_home >= 0:
			world.property_beat(arrival_home, CityArtDirection.UI_ACCENT_LIGHT, 4.6)
			arrival_home = -1
			_cancel_selection()
			hud.guide_expanded = state.opening_stage >= 0 or state.milestone < 3
			hud.refresh_goal()
			if state.opening_stage == 1:
				var next := CityJourney.describe(state, _now())
				if next.action == "guide_home": _focus_property(int(next.target))
	)
	world.plot_pressed.connect(_on_plot_pressed)
	world.coin_pressed.connect(_on_coin_pressed)
	world.street_pressed.connect(_on_street_pressed)
	world.camera_changed.connect(_position_context)
	hud.action_requested.connect(_on_action)
	state.changed.connect(_on_state_changed)
	state.transaction.connect(_on_transaction)
	initialized = true
	if not restored:
		saves.write(state)
	elif not saves.last_error.is_empty():
		hud.notify_user(saves.last_error, false)
	get_viewport().size_changed.connect(_position_context)
	if not art_review:
		hud.root.hide()
		shell.show_page("title")
		world.ease_camera(Vector2(-16, 0), 1.06, 1.25)
	boot.finish()
	if not capture_dir.is_empty():
		call_deferred("_visual_smoke")

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _process(delta: float) -> void:
	if not initialized:
		return
	world.input_locked = shell.is_open() or lease_sheet.is_open()
	clock += delta
	autosave_clock += delta
	if clock >= 0.2:
		clock = 0.0
		state.advance(_now())
		if state.commerce_peak_customers > noticed_trade_peak:
			if noticed_trade_peak == 0:
				hud.notify_user("Komşuların kafeye geliyor. Sokağında yerel ticaret başladı.")
				audio.play_confirm()
			if state.milestone == 2:
				for cafe in range(state.lots.size()):
					if state.lots[cafe].kind == "cafe" and state.customers(cafe, _now()) > 0:
						_focus_property(cafe)
						break
			noticed_trade_peak = state.commerce_peak_customers
		hud.update_clock()
		shell.update_investment_balance(_now())
		_position_context()
	if autosave_clock >= 15.0:
		autosave_clock = 0.0
		_save()

func _on_plot_pressed(index: int) -> void:
	if shell.is_open() or lease_sheet.is_open(): return
	if mode == Mode.NORMAL and index >= 0 and state.opening_stage in [0, 1]:
		var next := CityJourney.describe(state, _now())
		var ready := state.opening_stage == 0 or state.collectible(index, _now()) > 0
		if ready and next.action == "guide_home" and index == int(next.target):
			_on_action("guide_home", str(index))
			return
	if index < 0:
		hud.hide_context()
		selected = -1
		world.selected = -1
		return
	hud.hide_shop()
	hud.guide_expanded = false
	selected = index
	world.selected = index
	if mode == Mode.BUILD:
		hud.show_context(index, "build", building_kind)
		_focus_property(index)
	elif mode == Mode.MOVE:
		if moving_source < 0:
			if not state.is_complete(index, _now()) or state.lots[index].kind == "hq":
				hud.notify_user("Taşımak istediğin tamamlanmış binayı seç.", false)
				return
			moving_source = index
			world.move_source = index
			hud.hide_context()
			hud.set_hint("Yeni konum için boş bir arsaya dokun. · Esc: iptal")
		else:
			hud.show_context(index, "move_target")
	else:
		hud.show_context(index)
	call_deferred("_position_context")

func _on_street_pressed(key: String) -> void:
	if mode != Mode.STREETS or shell.is_open() or lease_sheet.is_open(): return
	world.selected_street = key
	hud.show_street_context(key)

func _on_action(action: String, value: String = "") -> void:
	# Closing/rebuilding the clicked control during its signal must not let the
	# same release reach the 3D town and immediately select the lot underneath.
	get_viewport().set_input_as_handled()
	# Settle business clocks before a player action changes the customer population.
	state.advance(_now())
	match action:
		"play":
			shell.has_save = true
			shell.close()
			hud.root.show()
			if introduction_pending:
				_begin_introduction()
			elif resume_pending:
				var best := -1
				var largest := 0
				for index in range(state.lots.size()):
					var ready := state.collectible(index, _now())
					if ready > largest: best = index; largest = ready
				if best >= 0:
					_focus_property(best)
					_on_plot_pressed(best)
			resume_pending = false
		"new_game":
			if shell.page != "new_confirm": return
			var fresh := CityState.new(catalog)
			fresh.seed_live(_now())
			state.restore(fresh.snapshot())
			noticed_trade_peak = 0
			introduction_pending = true
			_cancel_selection()
			hud.hide_shop()
			state.changed.emit()
			world.home_camera()
			_on_action("play")
		"pause":
			_cancel_selection()
			hud.hide_shop()
			hud.root.hide()
			shell.show_page("pause")
		"language":
			preferences.language = value
			CityLocale.set_language(value)
			preferences.save()
			_rebuild_hud()
			shell.show_page("settings")
		"effects":
			preferences.effects = clampf(float(value), 0, 1)
			audio.set_level(preferences.effects)
			preferences.save()
		"fullscreen":
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		"how_to_play":
			hud.root.hide()
			shell.show_page("help")
		"projects":
			hud.root.hide()
			shell.show_page("projects")
		"investments":
			hud.root.hide()
			shell.show_page("investments")
		"investment_collect":
			for index in range(state.lots.size()):
				if state.lots[index].kind == "cafe": _collect_property(index)
			shell.update_investment_balance(_now())
		"investment_plan":
			_on_action("play")
			if value == "cafe":
				for index in range(state.lots.size()):
					if state.lots[index].kind == "cafe" and int(state.lots[index].level) < 3:
						_on_action("guide_home", str(index))
						break
			else:
				var site := CityJourney.investment_site(state, value, _now())
				_on_action("choose_building", value)
				if int(site.index) >= 0: _on_plot_pressed(int(site.index))
		"objective":
			_on_plot_pressed(7)
		"journey":
			var next := CityJourney.describe(state, _now())
			if next.action in ["guide_home", "guide_cafe", "guide_renovate", "guide_lease"]:
				_on_action(next.action, str(next.target))
			else:
				_on_action(next.action, next.value)
		"toggle_guide":
			if hud.context_panel.visible or hud.shop_panel.visible:
				_cancel_selection()
				hud.hide_shop()
				hud.guide_expanded = true
			else:
				hud.guide_expanded = not hud.guide_expanded
			hud.refresh_goal()
		"guide_home", "guide_renovate":
			_cancel_selection()
			hud.hide_shop()
			var target := int(value)
			if not state.valid_index(target): target = 8
			if action == "guide_home" and state.opening_stage == 0 and state.catalog.is_residential(state.lots[target].kind) and state.lots[target].lease.is_empty():
				selected = target
				world.selected = target
				hud.lease_type = "long"
				lease_sheet.show_agreement(state, target, "long", _now(), world.property_preview(target), true)
				hud.root.hide()
				audio.play_paper()
				return
			if action == "guide_home" and state.opening_stage == 1 and state.lots[target].kind == "cafe" and state.collectible(target, _now()) > 0:
				selected = target
				_on_action("collect")
				_cancel_selection()
				hud.guide_expanded = true
				hud.refresh_goal()
				return
			if state.milestone == 2: hud.lease_type = "long"
			_focus_property(target)
			_on_plot_pressed(target)
			if action == "guide_renovate" and state.lots[target].lease.is_empty() and int(state.lots[target].level) == 1:
				hud.show_context(target, "renovation")
		"guide_build":
			_cancel_selection()
			hud.show_shop("Çevre" if value == "park" else "Konut")
		"guide_lease":
			_cancel_selection()
			selected = int(value)
			world.selected = selected
			_on_action("lease", hud.lease_type)
		"guide_cafe":
			_on_action("choose_building", "cafe")
			var target := int(value)
			_focus_property(target)
			_on_plot_pressed(target)
		"select_project":
			if state.choose_project(value):
				_on_action("play")
		"quit":
			_save()
			get_tree().quit()
		"catalog":
			_cancel_selection()
			hud.show_shop()
		"streets":
			if mode == Mode.STREETS:
				_finish_street_planning()
			else:
				var intent := {"kind":building_kind, "index":selected, "appearance":hud.architecture_choice} if mode == Mode.BUILD and selected >= 0 else {}
				_cancel_selection()
				pending_placement = intent
				hud.hide_shop()
				mode = Mode.STREETS
				world.street_mode = true
				hud.set_street_planning(true)
				hud.set_hint("Bir bağlantıya dokun. Bitirince Bitti'yi seç.")
		"build_street":
			if state.build_street(value, _now()):
				audio.play_confirm()
				hud.hide_context()
				world.selected_street = ""
		"remove_street":
			if state.remove_street(value, _now()):
				audio.play_confirm()
				hud.hide_context()
				world.selected_street = ""
		"exit_streets":
			_finish_street_planning()
		"category":
			hud.show_shop(value)
		"open_category":
			_cancel_selection()
			hud.show_shop(value)
		"close_shop":
			hud.hide_shop()
		"choose_building":
			_cancel_selection()
			hud.hide_shop()
			mode = Mode.BUILD
			building_kind = value
			world.preview_kind = value
			hud.set_hint(CityLocale.f("{0} · Boş bir arsa seç. · Esc: iptal", [CityLocale.t(catalog.get_building(value).name)]))
		"confirm_build":
			if mode == Mode.BUILD and state.build(selected, building_kind, _now(), hud.architecture_choice):
				mode = Mode.NORMAL
				building_kind = ""
				world.preview_kind = ""
				hud.set_hint("")
				hud.show_context(selected)
				audio.play_confirm()
		"lease_choice":
			hud.lease_type = value
			hud.show_context(selected)
		"architecture_choice":
			hud.architecture_choice = value
			world.preview_style = value
			hud.show_context(selected, "build", building_kind)
		"lease":
			if state.growth_economy and state.cash < int(CityCatalog.LEASES[value].fee): value = "short"
			lease_sheet.show_agreement(state, selected, value, _now(), world.property_preview(selected))
			hud.root.hide()
			audio.play_paper()
		"collect":
			_collect_property(selected)
		"upgrade":
			if state.upgrade(selected, _now()):
				audio.play_confirm()
		"renovation_plan":
			hud.show_context(selected, "renovation")
		"specialization_choice":
			hud.specialization_choice = value
			hud.show_context(selected, "renovation")
		"confirm_renovation":
			if state.upgrade(selected, _now(), hud.specialization_choice):
				hud.show_context(selected)
				audio.play_confirm()
		"claim":
			if state.needs_project():
				_on_action("projects")
			elif state.claim_objective(_now()):
				audio.play_collect()
				_cancel_selection()
				hud.hide_shop()
				if state.milestone >= 3: hud.guide_expanded = false
		"expand":
			if state.expand():
				audio.play_confirm()
		"move":
			_cancel_selection()
			hud.hide_shop()
			mode = Mode.MOVE
			hud.set_hint("Taşımak istediğin binayı seç. · Esc: iptal")
		"confirm_move":
			if mode == Mode.MOVE and state.move_building(moving_source, selected, _now()):
				_cancel_selection()
				audio.play_confirm()
		"home":
			_cancel_selection()
			hud.hide_shop()
			world.home_camera()
		"zoom_in":
			world.change_zoom(1.12)
		"zoom_out":
			world.change_zoom(1.0 / 1.12)
		"close":
			if mode == Mode.STREETS:
				hud.hide_context()
				world.selected_street = ""
			else:
				_cancel_selection()
		"help":
			hud.show_help()
	call_deferred("_position_context")

func _on_sign_requested(index: int, type: String) -> void:
	if lease_sheet.phase != "review": return
	if state.start_lease(index, type, _now()):
		arrival_home = index
		if state.opening_stage == 1: hud.toast_panel.hide()
		lease_sheet.signed()
		audio.play_signature()
	else:
		lease_sheet.close()
		hud.notify_user("Kontratı yeniden kontrol et.", false)

func _begin_introduction() -> void:
	introduction_pending = false
	if state.opening_stage >= 0:
		world.ease_camera(Vector2(-25, -3), 1.2, .48)
		hud.guide_expanded = true
		hud.refresh_goal()
		return
	world.focus = Vector2(-12, 1)
	world.zoom_factor = .84
	world._apply_camera()
	var tween := world.ease_camera(Vector2(-8, 1), 1.04, .65)
	tween.tween_callback(func() -> void:
		if selected < 0 and not shell.is_open() and not lease_sheet.is_open():
			_on_plot_pressed(8)
	)

func _focus_property(index: int) -> void:
	if not state.valid_index(index): return
	var from := world.focus
	var size := get_viewport().get_visible_rect().size
	world._pan(Vector2(size.x * .49, size.y * .48) - world.lot_screen_point(index))
	var target := world.focus
	world.focus = from
	world._apply_camera()
	world.ease_camera(target, world.zoom_factor, .35)

func _finish_street_planning() -> void:
	var intent := pending_placement.duplicate()
	_cancel_selection()
	if not intent.is_empty():
		_on_action("choose_building", intent.kind)
		hud.architecture_choice = intent.appearance
		_on_plot_pressed(int(intent.index))
		hud.notify_user("Yerleşim planın hazır. Yol bağlantısını ve toplam bedeli kontrol et.")

func _on_coin_pressed(index: int) -> void:
	if shell.is_open() or lease_sheet.is_open(): return
	_collect_property(index)

func _collect_property(index: int) -> void:
	var opening := state.opening_stage
	var amount := state.collect(index, _now())
	if amount > 0:
		if opening == 1 and state.opening_stage == 2:
			hud.guide_expanded = true
			hud.refresh_goal()
		world.property_beat(index, CityArtDirection.UI_ACCENT_LIGHT)
		world.add_income(index, amount)
		audio.play_collect()
		hud.collection_feedback(world.lot_screen_point(index))

func _rebuild_hud() -> void:
	_cancel_selection()
	remove_child(hud)
	hud.queue_free()
	hud = TownHUD.new()
	add_child(hud)
	hud.building_previews = world.preview_textures()
	hud.setup(state, null)
	hud.action_requested.connect(_on_action)
	hud.root.visible = not shell.is_open()
	shell.ui_theme = hud.root.theme
	lease_sheet.ui_theme = hud.root.theme

func _cancel_selection() -> void:
	mode = Mode.NORMAL
	selected = -1
	building_kind = ""
	moving_source = -1
	world.selected = -1
	world.move_source = -1
	world.preview_kind = ""
	world.street_mode = false
	world.selected_street = ""
	hud.set_street_planning(false)
	hud.hide_context()
	hud.set_hint("")
	pending_placement.clear()

func _on_state_changed() -> void:
	_save()
	hud.refresh()
	world.refresh_city()
	call_deferred("_position_context")

func _save() -> void:
	if saves.write(state):
		hud.save_label.text = "Kaydedildi"
	else:
		hud.save_label.text = "Kayıt hatası"
		hud.notify_user(saves.last_error, false)

func _on_transaction(message: String, positive: bool) -> void:
	hud.notify_user(message, positive)

func _position_context() -> void:
	if initialized and selected >= 0:
		var screen_point := world.lot_screen_point(selected)
		hud.position_context(screen_point)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if lease_sheet.is_open():
				lease_sheet.close()
			elif shell.is_open():
				if shell.page in ["settings", "help"]: shell.show_page(shell.return_page)
				elif shell.page in ["pause", "investments", "projects"]: _on_action("play")
			elif hud.context_panel.visible or hud.shop_panel.visible:
				_cancel_selection()
				hud.hide_shop()
			else:
				_on_action("pause")
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_M:
			audio.enabled = not audio.enabled
			hud.notify_user("Ses açık" if audio.enabled else "Ses kapalı")

func _notification(what: int) -> void:
	if not initialized:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		state.advance(_now())
		hud.refresh()

func _capture(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var panels: Array[Control] = [hud.objective_panel, hud.context_panel, hud.shop_panel, hud.toast_panel]
	if lease_sheet.is_open(): panels.append(lease_sheet.paper)
	if shell.is_open() and is_instance_valid(shell.card): panels.append(shell.card)
	for panel: Control in panels:
		if not panel.is_visible_in_tree():
			continue
		var rect := panel.get_global_rect()
		var viewport_size := get_viewport().get_visible_rect().size
		if rect.position.x < -1 or rect.position.y < -1 or rect.end.x > viewport_size.x + 1 or rect.end.y > viewport_size.y + 1:
			push_error("UI smoke: floating panel exceeds viewport: " + str(panel.name))
			get_tree().quit(1)
			return
	RenderingServer.force_draw(false)
	if CityLocale.language == "en":
		var untranslated := RegEx.new()
		untranslated.compile("[ıİşŞğĞçÇ]|(?i)\\b(kira|konut|seviye|toplam|arsa)\\b")
		for kind: String in ["Label", "Button"]:
			for control: Control in get_tree().root.find_children("*", kind, true, false):
				if control.is_visible_in_tree() and str(control.text) != "Türkçe" and untranslated.search(str(control.text)) != null:
					push_error("UI locale audit: untranslated visible text: " + str(control.text))
					get_tree().quit(1)
					return
	var image := get_viewport().get_texture().get_image()
	image.save_png(capture_dir.path_join(name + ".png"))

func _visual_smoke() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	if state.opening_stage >= 0 and not resume_review and not art_review:
		await _opening_smoke()
		return
	audio.sounds.signature.save_to_wav(capture_dir.path_join("lease-signature.wav"))
	if journey_review:
		await _journey_smoke()
		return
	if resume_review:
		await _capture("00-welcome-back")
		var before := state.cash
		await _click_button("Devam et")
		await _capture("01-ready-income")
		if state.cash != before or selected < 0 or state.collectible(selected, _now()) <= 0:
			push_error("Resume smoke: did not focus actual ready income without changing cash")
			get_tree().quit(1)
			return
		print("CITY_RESUME_SMOKE_OK: real collectible summary and focused return, no auto-award")
		get_tree().quit()
		return
	if art_review:
		await _capture("01-populated-city")
		_on_plot_pressed(20)
		await _capture("02-cafe-coverage")
		_on_action("open_category", "Konut")
		await _capture("03-shared-architecture")
		hud.hide_shop()
		world.change_zoom(.1)
		await _capture("04-wide-district")
		state.lots[8].lease = {}
		_on_plot_pressed(8)
		_on_action("lease", "short")
		await _capture("05-lease-offer")
		await _click_button(CityLocale.t("Uzun") + " · 4m")
		await _capture("06-stable-lease-offer")
		print("CITY_ART_REVIEW_OK: native geometry, shared lighting, populated city")
		get_tree().call_deferred("quit")
		return
	await _capture("00-title")
	await _click_button("Devam et" if shell.has_save else "Mahalleni kur")
	await get_tree().create_timer(.9).timeout
	await _capture("01-city")
	await _touch_plot(13)
	if selected != 13 or not hud.context_panel.visible:
		push_error("UI smoke: native touch selection failed")
		get_tree().quit(1)
		return
	await _capture("02-contracts")
	await _click_button("×")
	await _click_button("İnşa et")
	await _capture("03-build-catalog")
	await _click_button(CityLocale.money(1800))
	await _touch_plot(9)
	await _click_button("Avlu")
	await _capture("03b-blocked-placement")
	await _click_button("Önce sokağı bağla")
	await _touch_street("h:3:2")
	await _capture("02b-street-plan")
	var before_street := state.cash
	await _click_button("Sokağı inşa et")
	if "h:3:2" not in state.street_edges or state.cash != before_street - 180:
		push_error("UI smoke: player-built street was not committed")
		get_tree().quit(1)
		return
	await _click_button("Bitti")
	if mode != Mode.BUILD or selected != 9 or hud.architecture_choice != "courtyard" or not hud.context_panel.visible:
		push_error("UI smoke: street planning lost the selected home, plot or architecture")
		get_tree().quit(1)
		return
	await _capture("04-placement")
	var before := state.cash
	await _click_button("Buraya inşa et")
	if state.lots[9].kind != "cottage" or state.cash != before - 2400 or state.lots[9].appearance != "courtyard":
		push_error("UI smoke: construction transaction failed")
		get_tree().quit(1)
		return
	await _click_button("×")
	await _touch_plot(13)
	await _click_button("Kontratı imzala")
	await _capture("05a-lease-review")
	await _click_button(CityLocale.t("Uzun") + " · 4m")
	var signature_point := lease_sheet.signature.get_global_rect().position + Vector2(32, 40)
	var before_signature := state.cash
	await _send_touch(0, signature_point, true)
	await get_tree().create_timer(.12).timeout
	await _send_touch(0, signature_point, false)
	await get_tree().create_timer(.22).timeout
	if not state.lots[13].lease.is_empty() or state.cash != before_signature:
		push_error("UI smoke: interrupted signature charged or started a lease")
		get_tree().quit(1)
		return
	await _click_button(CityLocale.t("Kısa") + " · 20s")
	signature_point = lease_sheet.signature.get_global_rect().position + Vector2(32, 40)
	await _send_touch(0, signature_point, true)
	await get_tree().create_timer(.1).timeout
	await _capture("05a-signing-gesture")
	await get_tree().create_timer(.22).timeout
	await _send_touch(0, signature_point, false)
	await _capture("05b-signature")
	await get_tree().create_timer(1.0).timeout
	if state.lots[13].lease.is_empty():
		push_error("UI smoke: signing failed")
		get_tree().quit(1)
		return
	await _touch_plot(13)
	await _capture("05-active-lease")
	await _click_button("×")
	await _touch_plot(8)
	var before_rent := state.cash
	await _click_button("Kirayı tahsil et")
	if state.cash != before_rent + 350:
		push_error("UI smoke: rent button failed")
		get_tree().quit(1)
		return
	await _capture("05b-rent-collected")
	await _click_button("JourneyAction")
	if state.milestone != 1:
		push_error("UI smoke: project claim failed")
		get_tree().quit(1)
		return
	await _capture("06-objective-complete")
	await _touch_plot(8)
	await _click_button(CityLocale.t("Yenileme planı"), true)
	await _capture("07-renovation-choice")
	await _click_button("○ " + CityLocale.t("Canlı sokak"), true)
	await _click_button(CityLocale.t("Planı uygula · {0}").split(" · ")[0], true)
	if state.lots[8].get("specialization") != "community" or int(state.lots[8].level) != 2:
		print("RENOVATION_STATE: selected=", selected, " choice=", hud.specialization_choice, " level=", state.lots[8].level, " specialization=", state.lots[8].get("specialization"), " cash=", state.cash)
		await _capture("error-renovation")
		push_error("UI smoke: renovation branch was not applied")
		get_tree().quit(1)
		return
	await get_tree().create_timer(6.3).timeout
	await _capture("08-upgraded-property")
	await _click_button("×")
	if hud.context_panel.visible or selected != -1:
		push_error("UI smoke: property close button did not clear selection")
		get_tree().quit(1)
		return
	var old_position := world.camera.position
	await _send_touch(0, Vector2(100, 350), true)
	await _send_drag(0, Vector2(160, 350), Vector2(60, 0))
	await _send_touch(0, Vector2(160, 350), false)
	if world.camera.position.distance_to(old_position) < 1:
		push_error("UI smoke: touch camera dragging failed")
		get_tree().quit(1)
		return
	var old_zoom := world.zoom_level()
	await _send_touch(0, Vector2(100, 350), true)
	await _send_drag(0, Vector2(100, 120), Vector2(0, -230))
	await _send_touch(0, Vector2(100, 120), false)
	if not world.fingers.is_empty():
		push_error("UI smoke: releasing a town drag over the GUI leaves a stuck finger")
		get_tree().quit(1)
		return
	await _send_touch(0, Vector2(100, 350), true)
	await _send_touch(1, Vector2(140, 350), true)
	await _send_drag(1, Vector2(160, 350), Vector2(20, 0))
	await _send_touch(1, Vector2(160, 350), false)
	await _send_touch(0, Vector2(100, 350), false)
	if world.zoom_level() <= old_zoom:
		push_error("UI smoke: two-finger zoom failed")
		get_tree().quit(1)
		return
	await _click_button("Menu")
	await _capture("09-pause-menu")
	await _click_button("Ayarlar")
	var slider: HSlider = shell.root.find_child("EffectsVolume", true, false)
	var volume_point := slider.global_position + Vector2(slider.size.x * .25, slider.size.y * .5)
	await _send_touch(0, volume_point, true)
	await _send_touch(0, volume_point, false)
	if absf(preferences.effects - .25) > .06 or absf(CityPreferences.new(preferences.path).effects - preferences.effects) > .001:
		push_error("UI smoke: touch volume change did not persist")
		get_tree().quit(1)
		return
	await _capture("10-settings-en")
	await _click_button("Türkçe")
	if CityLocale.language != "tr" or CityPreferences.new(preferences.path).language != "tr":
		push_error("UI smoke: Turkish language preference did not persist")
		get_tree().quit(1)
		return
	await _capture("11-settings-tr")
	await _click_button("Geri")
	await _click_button("Şehre dön")
	await _touch_plot(8)
	await _click_button("Kontratı imzala")
	await _capture("11b-lease-tr")
	await _click_button("İptal")
	await _click_button("Menu")
	await _click_button("Ayarlar")
	await _click_button("English")
	await _click_button("Geri")
	await _click_button("Şehre dön")
	await _capture("12-game-en")
	# Isolated post-intro fixture exercises the advanced project UI using real input.
	state.milestone = 5
	state.changed.emit()
	await _click_button("JourneyAction")
	await _capture("13-projects-en")
	await _click_button("Projeyi seç")
	if state.active_project != "garden" or shell.is_open():
		push_error("UI smoke: selected neighbourhood project was not committed")
		get_tree().quit(1)
		return
	var before_reset := state.cash
	await _click_button("Menu")
	await _click_button("Ana menü")
	await _click_button("Yeni mahalle")
	await _capture("14-new-town-confirmation")
	await _click_button("İptal")
	if state.cash != before_reset or state.active_project != "garden":
		push_error("UI smoke: cancelling a new town changed the save")
		get_tree().quit(1)
		return
	await _click_button("Yeni mahalle")
	await _click_button("Yeni mahalleyi başlat")
	await get_tree().create_timer(.9).timeout
	if state.cash != 2400 or state.milestone != 5 or state.opening_stage != 0 or state.lots[6].kind != "cafe" or not state.active_project.is_empty():
		push_error("UI smoke: new town did not start a fresh company")
		get_tree().quit(1)
		return
	# The old ready-rent fixture separately covers the direct coin hit target.
	# It is not the actual fresh-player opening above.
	var old_town := CityState.new(catalog)
	old_town.seed(_now())
	state.restore(old_town.snapshot())
	state.changed.emit()
	_cancel_selection()
	_focus_property(8)
	await get_tree().create_timer(.45).timeout
	var coin := world.camera.unproject_position(world.ready_labels[8].global_position)
	await _send_touch(0, coin, true)
	await _send_touch(0, coin, false)
	if state.cash != 12350:
		await _capture("error-rent-marker")
		push_error("UI smoke: tapping the rent coin at %s left $%d cash, marker visible: %s" % [coin, state.cash, world.ready_labels[8].visible])
		get_tree().quit(1)
		return
	await _capture("15-first-rent-feedback")
	# A shortcut must change real customer reach, not merely decorate the ground.
	state.cash = 10000
	state.experience = 600
	state.build_street("h:3:3", _now())
	state._install(15, "cafe", _now())
	state.start_lease(8, "long", _now())
	state.changed.emit()
	if state.customers(15, _now()) != 0:
		push_error("UI smoke: shortcut fixture already reaches the cafe")
		get_tree().quit(1)
		return
	if hud.context_panel.visible: await _click_button("×")
	await _click_button("Sokaklar")
	await _touch_street("v:3:2")
	await _capture("16-shortcut-impact")
	await _click_button("Sokağı inşa et")
	if state.customers(15, _now()) != 4:
		push_error("UI smoke: built shortcut did not activate four actual cafe customers")
		get_tree().quit(1)
		return
	await _click_button("Bitti")
	await _capture("17-player-shaped-street")
	print("CITY_VISUAL_SMOKE_OK: title, onboarding, architecture, signature, rent, renovation, camera, language persistence, projects, new-town confirmation and coin collection")
	get_tree().call_deferred("quit")

func _touch_plot(index: int) -> void:
	var point := world.lot_screen_point(index)
	var screen := Rect2(Vector2(20, 20), get_viewport().get_visible_rect().size - Vector2(40, 40))
	if not screen.has_point(point):
		if hud.context_panel.visible: await _click_button("×")
		if hud.shop_panel.visible: await _click_button("×")
		await _click_button("Merkez")
		point = world.lot_screen_point(index)
	if hud.objective_panel.visible and hud.objective_panel.get_global_rect().has_point(point) and hud.guide_expanded:
		await _click_button("GoalSteps")
	if hud.context_panel.visible and hud.context_panel.get_global_rect().has_point(point):
		await _click_button("×")
	if (hud.objective_panel.visible and hud.objective_panel.get_global_rect().has_point(point)) or hud.header.get_global_rect().has_point(point):
		if hud.context_panel.visible: await _click_button("×")
		if hud.shop_panel.visible: await _click_button("×")
		await _click_button("Merkez")
		point = world.lot_screen_point(index)
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.position = point
	release.index = 0
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame
	await get_tree().process_frame

func _send_touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame

func _send_drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame

func _journey_smoke() -> void:
	# A fresh-city regression through visible actions. No fixtures, clock skips,
	# direct domain mutations or automatic reward injection in this walkthrough.
	await _capture("00-welcome")
	await _click_button("Mahalleni kur")
	await get_tree().create_timer(1).timeout
	await _click_button("Kirayı tahsil et")
	await _click_button("JourneyAction")
	await _capture("01-next-clear-step")
	await _click_button("JourneyAction")
	await _touch_street("h:3:2")
	await _click_button("Sokağı inşa et")
	await _click_button("Bitti")
	await _click_button("JourneyAction")
	await _click_button(CityLocale.money(1800))
	await _touch_plot(9)
	await _click_button("Buraya inşa et")
	await _click_button("JourneyAction")
	await _capture("02-cafe-before-lease-clocks")
	await _click_button("JourneyAction")
	await _capture("03-a-place-for-neighbours")
	await _click_button("Buraya inşa et")
	await _click_button("İnşaat sürerken sıradaki adıma geç")
	await _click_button("Kontratı imzala")
	if lease_sheet.lease_type != "long":
		push_error("Journey smoke: learning chapter did not recommend planning time")
		get_tree().quit(1)
		return
	await _gesture_sign()
	await _capture("04-four-neighbours-ready")
	await _click_button("JourneyAction")
	await _click_button("Kontratı imzala")
	await _gesture_sign()
	await get_tree().create_timer(13).timeout
	await _capture("05-a-living-street")
	if state.commerce_peak_customers != 8 or world.walkers.size() < 4 or not state.can_claim_objective(_now()):
		push_error("Journey smoke: guided street did not produce the promised neighbours and cafe achievement")
		get_tree().quit(1)
		return
	await _click_button("JourneyAction")
	if state.milestone != 3:
		push_error("Journey smoke: completed cafe did not lead to a new spatial decision")
		get_tree().quit(1)
		return
	await _capture("06-next-spatial-decision")
	print("CITY_JOURNEY_SMOKE_OK: fresh input-only rent, street, third home, cafe first, two long leases, four walkers, 8 served neighbours, next renovation goal")
	get_tree().quit()

func _gesture_sign() -> void:
	var point := lease_sheet.signature.get_global_rect().position + Vector2(32, 40)
	await _send_touch(0, point, true)
	await get_tree().create_timer(.65).timeout
	await _send_touch(0, point, false)
	await get_tree().create_timer(.6).timeout

func _opening_smoke() -> void:
	# Fresh, input-only actual player opening. No state fixtures or fast clocks.
	var began := Time.get_ticks_msec()
	var use_landmarks := "--world-opening-review" in OS.get_cmdline_user_args()
	audio.sounds.signature.save_to_wav(capture_dir.path_join("lease-signature.wav"))
	await _capture("00-welcome")
	await _click_button("Mahalleni kur")
	await _capture("01-a-working-street")
	var baseline := CityNeighbourhood.describe(state, _now())
	if state.opening_stage != 0 or baseline.residents != 4 or baseline.served != 4:
		push_error("Opening: expected a genuinely working inherited cafe, four neighbours and a vacant home")
		get_tree().quit(1)
		return
	if use_landmarks:
		await _touch_opening_label(8)
	else:
		await _click_button("JourneyAction")
	await _capture("02-your-first-neighbours")
	if not lease_sheet.is_open() or lease_sheet.lease_type != "long":
		push_error("Opening: the first action did not reach a clear actual offer")
		get_tree().quit(1)
		return
	await _gesture_sign()
	await _capture("03-neighbours-walk-to-cafe")
	var after := CityNeighbourhood.describe(state, _now())
	if state.opening_stage != 1 or after.residents != 8 or after.served != 8 or after.trade != 992 or state.contracts_signed != 1:
		push_error("Opening: signature did not produce actual neighbours and connected cafe trade")
		get_tree().quit(1)
		return
	var before := state.cash
	if use_landmarks:
		await _touch_opening_label(6)
	else:
		await _click_button("JourneyAction")
	await _capture("04-earned-income-next-investment")
	if state.opening_stage != 2 or state.cash <= before or state.cash - before >= 700 or state.rent_collected != 0:
		push_error("Opening: first cafe collection was blocked or replaced by a reward")
		get_tree().quit(1)
		return
	print("CITY_OPENING_SMOKE_OK: first offer, real 4-to-8 neighbours, $992/min trade and actual cafe collection in %.2f seconds; no fixture/clock/reward shortcut" % ((Time.get_ticks_msec() - began) / 1000.0))
	await _click_button("Merkez")
	await _click_button("JourneyAction")
	await _capture("05-first-investment-choices")
	var cafe_plan := "--cafe-investment-review" in OS.get_cmdline_user_args()
	var site := CityJourney.investment_site(state, "cottage", _now())
	var price := state.upgrade_price(6) if cafe_plan else int(site.price)
	var deadline := Time.get_ticks_msec() + 38000
	while state.cash + state.collectible(6, _now()) < price and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.25).timeout
	if state.cash < price:
		await _click_button("InvestmentCollect")
	var investment_cash := state.cash
	var built_index := 6 if cafe_plan else int(site.index)
	if cafe_plan:
		await _click_button("PlanCafe")
		await _click_button(CityLocale.f("Yenile · {0}", [CityLocale.money(price)]))
	else:
		await _click_button("PlanCottage")
		if int(site.road) > 0:
			await _click_button("Önce sokağı bağla")
			await _touch_street(CityStreets.frontage(built_index))
			await _click_button("Sokağı inşa et")
			await _click_button("Bitti")
		await _click_button("Avlu")
		await _click_button("Buraya inşa et")
	await _capture("06-your-first-investment")
	if state.cash != investment_cash - price or state.opening_stage != 2:
		push_error("Opening: chosen investment did not use real costs and construction")
		get_tree().quit(1)
		return
	await get_tree().create_timer(8.2).timeout
	await _click_button("×")
	await _capture("07-your-growing-neighbourhood")
	if state.opening_stage != -1 or not state.is_complete(built_index, _now()) or state.can_claim_objective(_now()) or not state.needs_project():
		push_error("Opening: completed investment did not hand over to optional neighbourhood projects")
		get_tree().quit(1)
		return
	print("CITY_OPENING_BUILD_OK: %s paid from working capital, finished in %.2f seconds, optional district projects with no automatic reward" % ["cafe expansion" if cafe_plan else "street and new home", (Time.get_ticks_msec() - began) / 1000.0])
	if not cafe_plan:
		await _click_button("JourneyAction")
		if not lease_sheet.is_open() or lease_sheet.lease_type != "short":
			push_error("Opening: the next action did not offer a lease affordable after construction")
			get_tree().quit(1)
			return
		await _gesture_sign()
		var growing := CityNeighbourhood.describe(state, _now())
		if state.contracts_signed != 2 or growing.reachable != 12 or growing.served != 8:
			push_error("Opening: a new lease should add real demand and expose cafe capacity")
			get_tree().quit(1)
			return
		await _capture("08-new-demand")
		print("CITY_OPENING_LOOP_OK: new home leased without a signing fee; 12 neighbours can walk to an 8-seat cafe")
	if use_landmarks: print("CITY_OPENING_LANDMARKS_OK: actual home and cafe markers accepted native touch")
	get_tree().quit()

func _touch_opening_label(index: int) -> void:
	await get_tree().create_timer(.24).timeout
	var label: Label3D = world.opening_focus.markers[index].label
	var point := world.camera.unproject_position(label.global_position)
	await _send_touch(0, point, true)
	await _send_touch(0, point, false)

func _touch_street(key: String) -> void:
	var point := world.street_screen_point(key)
	await _send_touch(0, point, true)
	await _send_touch(0, point, false)
	await get_tree().create_timer(.12).timeout
	if hud.context_mode != "street" or hud.street_key != key:
		push_error("UI smoke: street touch selected the wrong connection: " + key)
		get_tree().quit(1)

func _click_button(text: String, prefix: bool = false) -> void:
	var requested_name := text
	text = CityLocale.t(text)
	await get_tree().create_timer(0.24).timeout
	var found: Button = null
	for node: Node in get_tree().root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled and ((prefix and button.text.begins_with(text)) or button.text == text or button.name == requested_name):
			found = button
			break
	if found == null:
		await _capture("error-missing-button")
		push_error("UI smoke: visible button missing: " + text)
		get_tree().quit(1)
		return
	var point := found.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = point
	release.global_position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame
	await get_tree().process_frame
