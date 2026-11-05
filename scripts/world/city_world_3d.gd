class_name CityWorld3D
extends Node3D
## One coherent orthographic town, built from the same editable architecture kit.

signal plot_pressed(index: int)
signal camera_changed
signal coin_pressed(index: int)
signal street_pressed(key: String)

const CELL := 12.0
const VIEW_SIZE := 35.0
var state: CityState
var camera: Camera3D
var focus := Vector2(-12, 1)
var zoom_factor := 1.0
var selected := -1
var hovered := -1
var preview_kind := ""
var preview_style := "veranda"
var move_source := -1
var displayed: Dictionary = {}
var properties: Dictionary = {}
var ready_labels: Dictionary = {}
var influences: Array[MeshInstance3D] = []
var selection: Node3D
var ghost: Node3D
var ghost_key := ""
var refresh_clock := 0.0
var elapsed := 0.0
var fingers: Dictionary = {}
var dragging := false
var total_drag := 0.0
var pinch_active := false
var previews: Dictionary = {}
var cars: Array[Node3D] = []
var walkers: Array[Dictionary] = []
var walking_signature := ""
var input_locked := false
var income_font: FontVariation
var street_mode := false
var selected_street := ""
var street_view: CityStreetView
var entrance_hint: Sprite3D
var routines: CityRoutines
var camera_motion: Tween
var opening_focus: CityOpeningFocus

func setup(model: CityState) -> void:
	state = model
	income_font = FontVariation.new()
	income_font.base_font = load("res://assets/fonts/NunitoSans.ttf")
	income_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):800.0}
	add_child(CityArchitecture.neighborhood(CityState.COLUMNS, CityState.ROWS, CELL))
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = CityArtDirection.WORLD.grass
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = CityArtDirection.AMBIENT_COLOR
	environment.ambient_light_energy = CityArtDirection.AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = CityArtDirection.SUN_ROTATION
	sun.light_color = CityArtDirection.SUN_COLOR
	sun.light_energy = CityArtDirection.SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 105
	sun.shadow_blur = 2.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.3
	camera.far = 200
	add_child(camera)
	_apply_camera()
	selection = Node3D.new()
	for edge in range(4):
		var line := MeshInstance3D.new()
		line.mesh = CityArchitecture.mesh("box")
		line.material_override = CityArchitecture.material("shutter")
		line.scale = Vector3(9.8, 0.08, 0.12) if edge < 2 else Vector3(0.12, 0.08, 9.8)
		line.position = Vector3(0, 0.28, -4.9 if edge == 0 else 4.9) if edge < 2 else Vector3(-4.9 if edge == 2 else 4.9, 0.28, 0)
		selection.add_child(line)
	add_child(selection)
	selection.hide()
	entrance_hint = Sprite3D.new()
	entrance_hint.texture = load("res://assets/ui/entrance.svg")
	entrance_hint.pixel_size = .04
	entrance_hint.rotation_degrees.x = -90
	entrance_hint.shaded = false
	entrance_hint.position.y = .3
	add_child(entrance_hint)
	entrance_hint.hide()
	for index in range(CityState.COLUMNS * CityState.ROWS):
		var influence := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(9.5, 9.5)
		influence.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CityArtDirection.COVERAGE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		influence.material_override = mat
		influence.position = lot_center(index) + Vector3(0, 0.24, 0)
		influence.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(influence)
		influences.append(influence)
		influence.hide()
	street_view = CityStreetView.new()
	add_child(street_view)
	street_view.setup(state)
	routines = CityRoutines.new()
	add_child(routines)
	routines.setup(state)
	refresh_city()
	opening_focus = CityOpeningFocus.new()
	add_child(opening_focus)
	opening_focus.setup(state)
	for i in range(4):
		var car := CityArchitecture.create_car(["trim", "shutter", "coral", "butter"][i])
		add_child(car)
		cars.append(car)

func preview_textures() -> Dictionary:
	if not previews.is_empty(): return previews
	for kind: String in ["cottage", "apartments", "villa", "cafe", "park", "office"]:
		previews[kind] = _create_preview(kind)
	return previews

func property_preview(index: int) -> Texture2D:
	var lot: Dictionary = state.lots[index]
	var key := "%s_%s_%s_%s_%s" % [lot.kind, lot.level, lot.specialization, lot.appearance, lot.get("visual_seed", index)]
	if not previews.has(key):
		previews[key] = _create_preview(lot.kind, int(lot.level), lot.specialization, lot.appearance, int(lot.get("visual_seed", index)))
	return previews[key]

func _create_preview(kind: String, level: int = 1, specialization: String = "neutral", appearance: String = "veranda", visual_seed: int = -1) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 448)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var model := CityArchitecture.create(kind, level, specialization, appearance)
	if visual_seed >= 0: CityPropertyDetails.dress(model, visual_seed, kind, appearance, level)
	scene.add_child(model)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = CityArtDirection.SUN_ROTATION
	light.light_energy = CityArtDirection.SUN_ENERGY
	light.light_color = CityArtDirection.SUN_COLOR
	scene.add_child(light)
	var world_environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = CityArtDirection.AMBIENT_COLOR
	settings.ambient_light_energy = CityArtDirection.AMBIENT_ENERGY
	world_environment.environment = settings
	scene.add_child(world_environment)
	var view_camera := Camera3D.new()
	view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view_camera.size = maxf(12.3, CityArchitecture.height_for(kind, level, appearance) * 1.5)
	view_camera.position = Vector3(18, 23, 28)
	scene.add_child(view_camera)
	view_camera.look_at(Vector3(0, maxf(2.3, CityArchitecture.height_for(kind, level, appearance) * .4), 0))
	return viewport.get_texture()

func lot_center(index: int) -> Vector3:
	var coordinate := state.coordinate(index)
	return Vector3((coordinate.x - (CityState.COLUMNS - 1) / 2.0) * CELL, 0, (coordinate.y - (CityState.ROWS - 1) / 2.0) * CELL)

func lot_screen_point(index: int) -> Vector2:
	return camera.unproject_position(lot_center(index) + Vector3(0, 0.6, 0))

func hit_test(point: Vector2) -> int:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("lot_index"):
		return int(hit.collider.get_meta("lot_index"))
	var ground: Variant = Plane(Vector3.UP, 0.1).intersects_ray(origin, direction)
	if ground == null:
		return -1
	var column := floori((ground.x + CityState.COLUMNS * CELL / 2) / CELL)
	var row := floori((ground.z + CityState.ROWS * CELL / 2) / CELL)
	if column < 0 or column >= CityState.COLUMNS or row < 0 or row >= CityState.ROWS:
		return -1
	var index := row * CityState.COLUMNS + column
	var center := lot_center(index)
	return index if absf(ground.x - center.x) < 4.8 and absf(ground.z - center.z) < 4.8 else -1

func street_screen_point(key: String) -> Vector2:
	return camera.unproject_position(CityStreetView.midpoint(key))

func _activate(point: Vector2) -> void:
	if input_locked: return
	if street_mode:
		var key := street_view.hit_test(camera, point)
		if not key.is_empty(): street_pressed.emit(key)
		return
	var guided_plot := opening_focus.hit_target(camera, point)
	if guided_plot >= 0:
		plot_pressed.emit(guided_plot)
		return
	for index: int in ready_labels:
		var marker: Node3D = ready_labels[index]
		if marker.visible and camera.unproject_position(marker.global_position).distance_to(point) <= 22:
			coin_pressed.emit(index)
			return
	plot_pressed.emit(hit_test(point))

func _apply_camera() -> void:
	var range_factor := clampf((zoom_factor - .72) / 1.08, 0, 1)
	focus.x = clampf(focus.x, lerpf(-18, -34, range_factor), lerpf(4, 34, range_factor))
	focus.y = clampf(focus.y, lerpf(-8, -24, range_factor), lerpf(8, 24, range_factor))
	camera.size = VIEW_SIZE / zoom_factor
	var target := Vector3(focus.x, 0, focus.y)
	camera.position = target + Vector3(34, 46, 55)
	if is_inside_tree():
		camera.look_at(target)

func home_camera() -> void:
	_stop_camera_motion()
	focus = Vector2(-12, 1)
	zoom_factor = 1.0
	_apply_camera()
	camera_changed.emit()

func zoom_level() -> float:
	return zoom_factor

func change_zoom(factor: float) -> void:
	_stop_camera_motion()
	zoom_factor = clampf(zoom_factor * factor, 0.72, 1.8)
	_apply_camera()
	camera_changed.emit()

func _pan(relative: Vector2) -> void:
	_stop_camera_motion()
	var midpoint := get_viewport().get_visible_rect().size * 0.5
	var plane := Plane(Vector3.UP, 0)
	var a: Variant = plane.intersects_ray(camera.project_ray_origin(midpoint), camera.project_ray_normal(midpoint))
	var b: Variant = plane.intersects_ray(camera.project_ray_origin(midpoint + relative), camera.project_ray_normal(midpoint + relative))
	if a == null or b == null:
		return
	var delta: Vector3 = a - b
	focus.x = clampf(focus.x + delta.x, -34, 34)
	focus.y = clampf(focus.y + delta.z, -24, 24)
	_apply_camera()
	camera_changed.emit()

func ease_camera(to_focus: Vector2, to_zoom: float, seconds: float) -> Tween:
	_stop_camera_motion()
	var from_focus := focus
	var from_zoom := zoom_factor
	camera_motion = create_tween()
	camera_motion.tween_method(func(weight: float) -> void:
		focus = from_focus.lerp(to_focus, weight)
		zoom_factor = lerpf(from_zoom, to_zoom, weight)
		_apply_camera()
		camera_changed.emit()
	, 0.0, 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return camera_motion

func _stop_camera_motion() -> void:
	if is_instance_valid(camera_motion): camera_motion.kill()

func property_beat(index: int, tone: Color, radius: float = 4.1) -> void:
	var beat := CityTownBeat.new()
	add_child(beat)
	beat.play(lot_center(index) + Vector3(0, .29, 0), tone, radius)

func refresh_city() -> void:
	var now := int(Time.get_unix_time_from_system())
	for index in range(state.lots.size()):
		var lot: Dictionary = state.lots[index]
		var stage: String = lot.kind if state.is_complete(index, now) else "construction"
		if lot.kind.is_empty():
			stage = "empty"
		var appearance: String = str(lot.get("appearance", "veranda"))
		var identity := int(lot.get("visual_seed", index))
		var signature := stage + ":" + str(lot.level) + str(lot.get("specialization", "neutral")) + appearance + str(identity)
		if displayed.get(index, "") == signature:
			continue
		var just_completed := str(displayed.get(index, "")).begins_with("construction:") and stage not in ["empty", "construction"]
		displayed[index] = signature
		if properties.has(index):
			properties[index].queue_free()
		var property := Node3D.new()
		property.name = "Property" + str(index)
		property.position = lot_center(index)
		add_child(property)
		properties[index] = property
		if stage != "empty":
			var model := CityArchitecture.create(stage, maxi(1, int(lot.level)), str(lot.get("specialization", "neutral")), appearance)
			CityPropertyDetails.dress(model, identity, stage, appearance, maxi(1, int(lot.level)))
			property.add_child(model)
			if just_completed:
				model.position.y = .48
				model.create_tween().tween_property(model, "position:y", 0.0, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				property_beat(index, CityArtDirection.UI_ACCENT_LIGHT)
		else:
			property.add_child(CityStreetView.meadow(index))
		var body := StaticBody3D.new()
		body.set_meta("lot_index", index)
		property.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(9.5, 0.3, 9.5)
		collider.shape = shape
		body.add_child(collider)
		if stage != "empty":
			var building_shape := CollisionShape3D.new()
			var volume := BoxShape3D.new()
			var height := CityArchitecture.height_for(stage, maxi(1, int(lot.level)), appearance)
			volume.size = Vector3(7.4, height, 6.3)
			building_shape.shape = volume
			building_shape.position = Vector3(0, height / 2, -0.6)
			body.add_child(building_shape)
		var label := Sprite3D.new()
		label.texture = load("res://assets/ui/coin.svg")
		label.pixel_size = 0.04
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(1.7, CityArchitecture.height_for(stage, maxi(1, int(lot.level)), appearance) + 1.1, 0)
		property.add_child(label)
		ready_labels[index] = label
	_update_marks()
	_update_walkers()
	if is_instance_valid(routines): routines.refresh()

func _update_walkers() -> void:
	var signature := ",".join(state.street_edges)
	var now := int(Time.get_unix_time_from_system())
	for index in range(state.lots.size()):
		if state.lots[index].kind == "cafe" or not state.lots[index].lease.is_empty():
			signature += str(index) + str(state.lots[index].kind) + str(state.lots[index].level) + str(state.resident_count(index)) + str(state.lots[index].get("appearance", "veranda")) + str(state.is_complete(index, now)) + str(state.is_occupied(index, now))
	if signature == walking_signature: return
	var first_pass := walking_signature.is_empty()
	walking_signature = signature
	var previous := {}
	for walker: Dictionary in walkers: previous[walker.id] = walker
	walkers.clear()
	var trade: Dictionary = state.commerce.allocate(state, now).destinations if state.growth_economy else {}
	for home in range(state.lots.size()):
		if not state.is_occupied(home, now): continue
		if walkers.size() >= 12: break
		var destinations: Array = trade.get(home, []) if state.growth_economy else []
		if not state.growth_economy:
			var nearest := -1
			var minimum := 100
			for cafe in range(state.lots.size()):
				if state.lots[cafe].kind != "cafe" or not state.is_complete(cafe, now) or not CityStreets.can_reach(state, home, cafe): continue
				var candidate := CityStreets.path(state, home, cafe)
				if candidate.size() < minimum:
					minimum = candidate.size()
					nearest = cafe
			if nearest >= 0:
				for person in range(state.resident_count(home)): destinations.append(nearest)
		for neighbour in range(mini(2, destinations.size())):
			if walkers.size() >= 12: break
			var path := CityRoutines.route(state, home, int(destinations[neighbour]))
			if path.size() < 2: continue
			var id := Vector2i(home, neighbour)
			if previous.has(id) and previous[id].path == path:
				walkers.append(previous[id])
				previous.erase(id)
				continue
			var total := 0.0
			for i in range(path.size() - 1): total += path[i].distance_to(path[i + 1])
			var person := CityResidents.create_person(home + neighbour * 3)
			person.position = path[0]
			add_child(person)
			var start := elapsed - walkers.size() * 6.3 if first_pass else elapsed + neighbour * .55
			walkers.append({"id":id, "node":person, "path":path, "length":total, "start":start})
	for obsolete: Dictionary in previous.values(): obsolete.node.queue_free()

func _update_marks() -> void:
	var now := int(Time.get_unix_time_from_system())
	if is_instance_valid(street_view): street_view.refresh(street_mode, selected_street)
	selection.visible = selected >= 0 and not street_mode
	if selected >= 0:
		selection.position = lot_center(selected)
	var center := selected if selected >= 0 else hovered
	var kind: String = preview_kind if not preview_kind.is_empty() else (str(state.lots[center].kind) if center >= 0 else "")
	for index in range(influences.size()):
		var reached := center >= 0 and (CityStreets.can_reach(state, index, center) if kind == "cafe" else state.distance(center, index) <= 1)
		influences[index].visible = not street_mode and center >= 0 and kind in ["cafe", "park"] and state.accessible(index) and reached
	for index: int in ready_labels:
		if is_instance_valid(ready_labels[index]):
			ready_labels[index].visible = state.collectible(index, now) > 0
	var ghost_kind := preview_kind
	if ghost_kind.is_empty() and move_source >= 0:
		ghost_kind = state.lots[move_source].kind
	var appearance: String = str(state.lots[move_source].get("appearance", "veranda")) if move_source >= 0 else preview_style
	var next_key := str(center) + ghost_kind + appearance if center >= 0 and not ghost_kind.is_empty() and state.lots[center].kind == "" and state.accessible(center) else ""
	entrance_hint.visible = not street_mode and not next_key.is_empty()
	if entrance_hint.visible:
		entrance_hint.position = lot_center(center) + Vector3(0, .3, 5.3)
		entrance_hint.scale = Vector3.ONE * (1 + .04 * sin(elapsed * 3))
	if next_key != ghost_key:
		if is_instance_valid(ghost):
			ghost.queue_free()
		ghost_key = next_key
		if not next_key.is_empty():
			ghost = CityArchitecture.create(ghost_kind, 1, "neutral", appearance)
			ghost.position = lot_center(center)
			var tint := StandardMaterial3D.new()
			tint.albedo_color = CityArtDirection.PREVIEW
			tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for geometry: Node in ghost.find_children("*", "GeometryInstance3D", true, false):
				geometry.material_override = tint
				geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ghost)

func add_income(index: int, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+" + CityLocale.money(amount)
	label.font = income_font
	label.font_size = 38
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = CityArtDirection.UI_ON_PRIMARY
	label.outline_modulate = CityArtDirection.UI_PRIMARY
	label.position = lot_center(index) + Vector3(0, 6, 0)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", 8, 1.4)
	tween.tween_property(label, "modulate:a", 0, 1.4)
	tween.chain().tween_callback(label.queue_free)

func _ready() -> void:
	_apply_camera()

func _process(delta: float) -> void:
	if state == null:
		return
	elapsed += delta
	refresh_clock += delta
	if refresh_clock >= 0.15:
		refresh_clock = 0
		refresh_city()
	# Traffic stays on the public northern boulevard, outside the editable network.
	for i in range(cars.size()):
		var direction := 1.0 if i % 2 == 0 else -1.0
		cars[i].position = Vector3((fposmod(elapsed * (1.1 + i * .12) + i * 23, 92) - 46) * direction, .12, -36 + direction * .5)
		cars[i].rotation.y = 0 if direction > 0 else PI
	for i in range(walkers.size()):
		var walker: Dictionary = walkers[i]
		var id: Vector2i = walker.id
		var speed := .85 + ((id.x + id.y) % 3) * .11
		var walk_time: float = walker.length / speed
		walker.node.visible = elapsed >= float(walker.start)
		if not walker.node.visible: continue
		var phase := fposmod(elapsed - float(walker.start), walk_time * 2 + 8)
		var returning := phase > walk_time + 6
		var moving := phase < walk_time or (returning and phase < walk_time * 2 + 6)
		var distance := minf(phase * speed, walker.length)
		if returning:
			distance = maxf(0, walker.length - (phase - walk_time - 6) * speed)
		var path: Array = walker.path
		for segment in range(path.size() - 1):
			var length: float = path[segment].distance_to(path[segment + 1])
			if distance <= length and length > 0.001:
				walker.node.position = path[segment].lerp(path[segment + 1], distance / length)
				var direction: Vector3 = (path[segment + 1] - path[segment]) * (-1 if returning else 1)
				walker.node.rotation.y = atan2(direction.x, direction.z)
				CityResidents.animate(walker.node, elapsed + i, moving)
				break
			distance -= length

func _input(event: InputEvent) -> void:
	# A gesture may start on the town and finish over a GUI panel. GUI consumes
	# that release before _unhandled_input, so clear any tracked pointer afterward.
	if event is InputEventScreenTouch and not event.pressed and fingers.has(event.index):
		call_deferred("_release_captured_finger", event.index)
	elif event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		call_deferred("_release_captured_mouse")

func _release_captured_finger(index: int) -> void:
	fingers.erase(index)
	if fingers.is_empty():
		pinch_active = false

func _release_captured_mouse() -> void:
	dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if input_locked: return
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_zoom(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_zoom(1.0 / 1.1)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_stop_camera_motion()
				dragging = true
				total_drag = 0
			else:
				if dragging and total_drag < 9 and event.button_index == MOUSE_BUTTON_LEFT:
					_activate(event.position)
				dragging = false
	elif event is InputEventMouseMotion:
		hovered = hit_test(event.position)
		if dragging:
			total_drag += event.relative.length()
			if total_drag >= 9:
				_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		change_zoom(event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_stop_camera_motion()
			fingers[event.index] = event.position
			if fingers.size() == 1:
				total_drag = 0
			else:
				pinch_active = true
		else:
			if fingers.size() == 1 and not pinch_active and total_drag < 10:
				_activate(event.position)
			fingers.erase(event.index)
			if fingers.is_empty():
				pinch_active = false
	elif event is InputEventScreenDrag:
		if fingers.size() == 1:
			total_drag += event.relative.length()
			if total_drag > 10:
				_pan(event.relative)
		elif fingers.size() == 2:
			var positions: Array = fingers.values()
			var before: float = positions[0].distance_to(positions[1])
			fingers[event.index] = event.position
			positions = fingers.values()
			if before > 1:
				change_zoom(float(positions[0].distance_to(positions[1])) / before)
		fingers[event.index] = event.position
