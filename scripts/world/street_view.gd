class_name CityStreetView
extends Node3D
## The player's owned street graph is also the visible road network. Planning
## guides exist only in street mode; an unbuilt field remains a field.
var city: CityState
var geometry: Node3D
var guides: Node3D
var street_signature := ""
var guide_signature := ""

static func junction_position(point: Vector2i) -> Vector3:
	return Vector3((point.x - CityState.COLUMNS / 2.0) * 12, .14, (point.y - CityState.ROWS / 2.0) * 12)

static func midpoint(key: String) -> Vector3:
	var points := CityStreets.endpoints(key)
	return (junction_position(points[0]) + junction_position(points[1])) * .5 if points.size() == 2 else Vector3.ZERO

func setup(model: CityState) -> void:
	city = model
	refresh(false, "")

func refresh(planning: bool, selected: String) -> void:
	var signature := ",".join(city.street_edges)
	var now := int(Time.get_unix_time_from_system())
	for index in range(city.lots.size()):
		if city.lots[index].kind in ["park", "cafe"]:
			signature += str(index) + city.lots[index].kind + str(city.is_complete(index, now))
	if signature != street_signature or not is_instance_valid(geometry):
		street_signature = signature
		if is_instance_valid(geometry):
			remove_child(geometry)
			geometry.queue_free()
		geometry = _build_streets()
		add_child(geometry)
	var next_guides := signature + str(planning) + selected + str(city.unlocked_columns)
	if next_guides != guide_signature:
		guide_signature = next_guides
		if is_instance_valid(guides):
			remove_child(guides)
			guides.queue_free()
		guides = Node3D.new()
		add_child(guides)
		if planning: _build_guides(selected)

func _build_streets() -> Node3D:
	var k := CityArchitecture.new()
	k.node = Node3D.new()
	k.node.name = "PlayerBuiltStreets"
	var arms := {}
	var destinations := {}
	var now := int(Time.get_unix_time_from_system())
	for index in range(city.lots.size()):
		if city.lots[index].kind in ["park", "cafe"] and city.is_complete(index, now) and city.has_frontage(index):
			destinations[CityStreets.frontage(index)] = city.lots[index].kind
	for key: String in city.street_edges:
		var ends := CityStreets.endpoints(key)
		if ends.size() != 2: continue
		var direction: Vector2i = ends[1] - ends[0]
		for point: Vector2i in ends:
			if not arms.has(point): arms[point] = []
		arms[ends[0]].append(direction)
		arms[ends[1]].append(-direction)
		var horizontal := direction.x != 0
		var center := midpoint(key)
		# Segments stop at the junction boundary. Junctions are generated once below.
		center.y = -.0125
		k._box(center, Vector3(9.4, .175, 2.6) if horizontal else Vector3(2.6, .175, 9.4), "paving")
		center.y = .08
		k._box(center, Vector3(9.4, .04, 1.8) if horizontal else Vector3(1.8, .04, 9.4), "road")
		var crossing := destinations.has(key)
		for side: int in [-1, 1]:
			if crossing:
				_sidewalk(k, center, horizontal, side, -2.9, 3.6)
				_sidewalk(k, center, horizontal, side, 2.9, 3.6)
			else:
				_sidewalk(k, center, horizontal, side, 0, 9.4)
		for offset: float in [-3.5, 0, 3.5]:
			if crossing and absf(offset) < 1.5: continue
			var mark := center + (Vector3(offset, .027, 0) if horizontal else Vector3(0, .027, offset))
			k._box(mark, Vector3(.85, .012, .065) if horizontal else Vector3(.065, .012, .85), "trim")
		if crossing:
			for stripe in range(4): k._box(center + Vector3(-.6 + stripe * .4, .027, 0), Vector3(.22, .012, 1.62), "trim")
	var surfaces := {}
	for tone: String in ["road", "paving", "trim"]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[tone] = surface
	for point: Vector2i in arms:
		var connections: Array = arms[point].duplicate()
		if point == CityStreets.SOURCE: connections.append(Vector2i.LEFT)
		_junction(surfaces, junction_position(point), connections)
	for key: String in destinations:
		# The dropped pavement entries meet the functional crossing without a curb lip.
		var center := midpoint(key)
		for side: int in [-1, 1]:
			var z0 := side * .9
			var z1 := side * 1.3
			_quad(surfaces.paving, center + Vector3(-1.1, -.04, z0), center + Vector3(1.1, -.04, z0), center + Vector3(1.1, 0, z1), center + Vector3(-1.1, 0, z1), Vector3.UP)
	for tone: String in surfaces:
		var instance := MeshInstance3D.new()
		instance.name = "Joined" + tone.capitalize()
		instance.mesh = surfaces[tone].commit()
		var material := CityArchitecture.material(tone).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		k.node.add_child(instance)
	var furnished := {}
	for key: String in destinations:
		var point: Vector2i = CityStreets.endpoints(key)[0]
		if furnished.has(point): continue
		furnished[point] = true
		_lamp(k, junction_position(point) + Vector3(1.08, -.08, 1.08))
		if destinations[key] == "park":
			var at := midpoint(key) + Vector3(3.65, -.08, -1.05)
			k._cylinder(at + Vector3(0, .40, 0), .20, .63, "shutter")
			k._cylinder(at + Vector3(0, .74, 0), .23, .07, "metal")
	k._flush()
	return k.node

static func _sidewalk(k, center: Vector3, horizontal: bool, side: int, offset: float, length: float) -> void:
	var at := center + (Vector3(offset, -.06, side * 1.1) if horizontal else Vector3(side * 1.1, -.06, offset))
	k._box(at, Vector3(length, .24, .4) if horizontal else Vector3(.4, .24, length), "paving")
	var curb := center + (Vector3(offset, .0475, side * .93) if horizontal else Vector3(side * .93, .0475, offset))
	k._box(curb, Vector3(length, .055, .06) if horizontal else Vector3(.06, .055, length), "trim")
	for slab: float in [-3, 0, 3]:
		if absf(slab - offset) >= length * .5 - .1: continue
		var joint := center + (Vector3(slab, .063, side * 1.13) if horizontal else Vector3(side * 1.13, .063, slab))
		k._box(joint, Vector3(.022, .008, .30) if horizontal else Vector3(.30, .008, .022), "stone")

static func _radius(angle: float, half_width: float, connections: Array) -> float:
	var direction := Vector2(cos(angle), sin(angle))
	var result := half_width
	for arm: Vector2i in connections:
		var forward := direction.dot(Vector2(arm))
		if forward <= .00001: continue
		var across := absf(direction.dot(Vector2(-arm.y, arm.x)))
		result = maxf(result, minf(1.3 / forward, half_width / maxf(.00001, across)))
	return result

static func _junction(surfaces: Dictionary, center: Vector3, connections: Array) -> void:
	var angles: Array[float] = []
	for i in range(64): angles.append(TAU * i / 64)
	var corner := atan2(.9, 1.3)
	for quarter in range(4):
		angles.append(fposmod(quarter * PI / 2 + corner, TAU))
		angles.append(fposmod(quarter * PI / 2 - corner, TAU))
	angles.sort()
	center.y = 0
	for i in range(angles.size()):
		var a := angles[i]
		var b := angles[(i + 1) % angles.size()]
		var da := Vector3(cos(a), 0, sin(a))
		var db := Vector3(cos(b), 0, sin(b))
		var ra := _radius(a, .9, connections)
		var rb := _radius(b, .9, connections)
		var oa := _radius(a, 1.3, connections)
		var ob := _radius(b, 1.3, connections)
		var ia := center + da * ra
		var ib := center + db * rb
		var pa := center + da * oa
		var pb := center + db * ob
		_triangle(surfaces.road, center + Vector3(0, .1, 0), ia + Vector3(0, .1, 0), ib + Vector3(0, .1, 0), Vector3.UP)
		_quad(surfaces.paving, pa + Vector3(0, .14, 0), pb + Vector3(0, .14, 0), ib + Vector3(0, .14, 0), ia + Vector3(0, .14, 0), Vector3.UP)
		var outer_normal := Vector3((pb - pa).z, 0, -(pb - pa).x).normalized()
		_quad(surfaces.paving, pa + Vector3(0, -.1, 0), pb + Vector3(0, -.1, 0), pb + Vector3(0, .14, 0), pa + Vector3(0, .14, 0), outer_normal)
		var ca := center + da * minf(oa, ra + .06)
		var cb := center + db * minf(ob, rb + .06)
		_quad(surfaces.trim, ca + Vector3(0, .155, 0), cb + Vector3(0, .155, 0), ib + Vector3(0, .155, 0), ia + Vector3(0, .155, 0), Vector3.UP)
		var inner_normal := -Vector3((ib - ia).z, 0, -(ib - ia).x).normalized()
		_quad(surfaces.trim, ia + Vector3(0, .10, 0), ib + Vector3(0, .10, 0), ib + Vector3(0, .155, 0), ia + Vector3(0, .155, 0), inner_normal)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(surface, a, b, c, normal)
	_triangle(surface, a, c, d, normal)

static func _lamp(k, at: Vector3) -> void:
	k._cylinder(at + Vector3(0, .14, 0), .14, .12, "metal")
	k._cylinder(at + Vector3(0, 1.37, 0), .055, 2.35, "metal")
	k._box(at + Vector3(0, 2.58, 0), Vector3(.34, .07, .34), "metal")
	k._box(at + Vector3(0, 2.79, 0), Vector3(.25, .36, .25), "butter")
	for x: float in [-.145, .145]:
		for z: float in [-.145, .145]: k._box(at + Vector3(x, 2.79, z), Vector3(.035, .38, .035), "metal")
	k._box(at + Vector3(0, 3.01, 0), Vector3(.39, .075, .39), "metal")
	k._cylinder(at + Vector3(0, 3.11, 0), .045, .14, "metal")

func _build_guides(selected: String) -> void:
	var reached := CityStreets.reachable(city)
	for key: String in CityStreets.all_edges():
		var owned := key in city.street_edges
		if not _can_plan(key, reached): continue
		var points := CityStreets.endpoints(key)
		var a := junction_position(points[0])
		var b := junction_position(points[1])
		var horizontal := points[0].y == points[1].y
		var chosen := key == selected
		var tone := CityArtDirection.UI_GOLD if chosen else CityArtDirection.WORLD.shutter
		if owned and not chosen: continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tone, .50 if chosen else .25)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var strip := MeshInstance3D.new()
		strip.mesh = CityArchitecture.mesh("box")
		strip.material_override = mat
		strip.position = (a + b) * .5 + Vector3(0, .03, 0)
		strip.scale = Vector3(10.8, .025, 1.5) if horizontal else Vector3(1.5, .025, 10.8)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		guides.add_child(strip)
		if not owned:
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = .27
			sphere.height = .54
			marker.mesh = sphere
			marker.material_override = mat
			marker.position = strip.position + Vector3(0, .18, 0)
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			guides.add_child(marker)

func hit_test(camera: Camera3D, point: Vector2) -> String:
	var closest := 24.0
	var found := ""
	var reached := CityStreets.reachable(city)
	for key: String in CityStreets.all_edges():
		if not _can_plan(key, reached): continue
		var ends := CityStreets.endpoints(key)
		var a := camera.unproject_position(junction_position(ends[0]))
		var b := camera.unproject_position(junction_position(ends[1]))
		# Keep a small inset at intersections to reduce ambiguity between branches.
		var nearest := Geometry2D.get_closest_point_to_segment(point, a.lerp(b, .12), a.lerp(b, .88))
		var distance := point.distance_to(nearest)
		if distance < closest:
			closest = distance
			found = key
	return found

func _can_plan(key: String, reached: Dictionary) -> bool:
	if key in city.street_edges: return true
	if not CityStreets.key_within_columns(key, city.unlocked_columns): return false
	var points := CityStreets.endpoints(key)
	return points.size() == 2 and (reached.has(points[0]) or reached.has(points[1]))

static func meadow(index: int) -> Node3D:
	var k := CityArchitecture.new()
	k.node = Node3D.new()
	k.node.name = "Meadow"
	var random := RandomNumberGenerator.new()
	random.seed = 1372 + index * 9781
	for tuft in range(6):
		var at := Vector3(random.randf_range(-3.7, 3.7), -.07, random.randf_range(-3.7, 3.7))
		k._part("grass_tuft", at, Vector3.ONE * random.randf_range(.8, 1.6), "leaf_light")
	if index % 5 == 0:
		k._tree(Vector3(random.randf_range(-2.7, 1.5), -.08, random.randf_range(-2.7, 1.5)), .65)
	else:
		var center := Vector3(random.randf_range(-2.8, 2.8), -.08, random.randf_range(-2.8, 2.8))
		for flower in range(5):
			var at := center + Vector3(random.randf_range(-.45, .45), .15, random.randf_range(-.45, .45))
			k._cylinder(at, .022, .3, "leaf")
			k._ball(at + Vector3(0, .16, 0), Vector3(.085, .045, .085), "flower_white" if flower % 2 else "flower_yellow")
	k._flush()
	return k.node
