class_name CityOpeningFocus
extends Node3D
## A short, truthful first-street guide. It reads the same occupants and street
## route as commerce, and fades once that opening has been completed.
var city: CityState
var markers: Dictionary = {}
var pulses: Array[Node3D] = []
var path: Array[Vector3] = []
var path_length := 0.0
var route_visible := false
var signature := ""
var elapsed := 0.0
var refresh_clock := 0.0
var opacity := 0.0
var active := false
var teal: StandardMaterial3D
var paper: StandardMaterial3D

func setup(model: CityState) -> void:
	city = model
	teal = _material(CityArtDirection.UI_PRIMARY)
	paper = _material(CityArtDirection.UI_PAPER)
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NunitoSans.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):800.0}
	var torus := TorusMesh.new()
	torus.inner_radius = .64
	torus.outer_radius = .73
	torus.rings = 40
	torus.ring_segments = 8
	for index: int in [8, 6]:
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = teal
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var label := Label3D.new()
		label.font = font
		label.font_size = 44
		label.pixel_size = .024
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = CityArtDirection.UI_PRIMARY
		label.outline_modulate = CityArtDirection.UI_PAPER
		label.outline_size = 13
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		markers[index] = {"ring":ring, "label":label}
	var dot := SphereMesh.new()
	dot.radius = .15
	dot.height = .10
	dot.radial_segments = 16
	dot.rings = 6
	for i in range(2):
		var pulse := MeshInstance3D.new()
		pulse.mesh = dot
		pulse.material_override = paper if i == 0 else teal
		pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pulse)
		pulses.append(pulse)
	_refresh()

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func hit_target(camera: Camera3D, point: Vector2) -> int:
	if not is_visible_in_tree() or not active: return -1
	var now := int(Time.get_unix_time_from_system())
	var next := CityJourney.describe(city, now)
	var index := int(next.target)
	if next.action != "guide_home" or not markers.has(index): return -1
	var label: Label3D = markers[index].label
	if not label.visible: return -1
	var center := camera.unproject_position(label.global_position)
	var half_width := clampf(label.text.length() * 3.7, 35.0, 110.0)
	var area := Rect2(center - Vector2(half_width, 22), Vector2(half_width * 2.0, 44))
	return index if area.has_point(point) else -1

func _refresh() -> void:
	if city == null or not city.valid_index(8) or not city.valid_index(6): return
	var now := int(Time.get_unix_time_from_system())
	var occupied := city.is_occupied(8, now)
	var customers := city.customers(6, now)
	var next := str(city.opening_stage) + str(occupied) + str(city.resident_count(8)) + str(customers) + CityLocale.language + ",".join(city.street_edges) + str(city.lots[8].kind) + str(city.lots[6].kind) + str(city.is_complete(6, now))
	if next == signature: return
	signature = next
	active = city.opening_stage in [0, 1]
	route_visible = active and city.opening_stage == 1 and occupied and city.lots[6].kind == "cafe" and city.is_complete(6, now) and CityStreets.can_reach(city, 8, 6)
	for index: int in markers:
		var lot: Dictionary = city.lots[index]
		var at := CityRoutines.lot_position(index)
		markers[index].ring.position = at + Vector3(CityRoutines.entrance_x(city, index), .22, 4.75)
		markers[index].label.position = at + Vector3(0, CityArchitecture.height_for(lot.kind, maxi(1, int(lot.level)), str(lot.get("appearance", "veranda"))) + .85, 0)
		if index == 6: markers[index].label.position.y += 1.0
		markers[index].ring.visible = (active or opacity > .001) and lot.kind != ""
		markers[index].label.visible = (active or opacity > .001) and lot.kind != ""
	var home_text := "Boş ev" if CityLocale.language == "tr" else "Vacant home"
	if occupied:
		home_text = str(city.resident_count(8)) + (" komşu" if CityLocale.language == "tr" else " neighbours")
	elif not city.lots[8].lease.is_empty():
		home_text = "Kira hazır" if CityLocale.language == "tr" else "Rent ready"
	markers[8].label.text = home_text
	var count := snappedf(customers, .1)
	var count_text := str(roundi(count)) if is_equal_approx(count, roundf(count)) else str(count)
	markers[6].label.text = CityLocale.f("Cafe · {0} customers", [count_text])
	path.clear()
	path_length = 0
	if route_visible:
		path = CityRoutines.route(city, 8, 6)
		for segment in range(path.size() - 1): path_length += path[segment].distance_to(path[segment + 1])
	for pulse: Node3D in pulses: pulse.visible = route_visible

func _process(delta: float) -> void:
	elapsed += delta
	refresh_clock += delta
	if refresh_clock >= .2:
		refresh_clock = 0
		_refresh()
	opacity = move_toward(opacity, 1.0 if active else 0.0, delta * 2.5)
	visible = opacity > .001
	if not visible: return
	teal.albedo_color = Color(CityArtDirection.UI_PRIMARY, opacity * .85)
	paper.albedo_color = Color(CityArtDirection.UI_PAPER, opacity)
	for index: int in markers:
		markers[index].ring.scale = Vector3.ONE * (1 + .04 * sin(elapsed * 2.5 + index))
		markers[index].label.modulate = Color(CityArtDirection.UI_PRIMARY, opacity)
		markers[index].label.outline_modulate = Color(CityArtDirection.UI_PAPER, opacity)
	if not route_visible or path_length < .01: return
	for i in range(pulses.size()):
		var distance := fposmod(elapsed * 2.0 + i * path_length * .5, path_length)
		for segment in range(path.size() - 1):
			var length := path[segment].distance_to(path[segment + 1])
			if length > .001 and distance <= length:
				pulses[i].position = path[segment].lerp(path[segment + 1], distance / length) + Vector3(0, .12, 0)
				break
			distance -= length
