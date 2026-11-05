class_name CityRoutines
extends Node3D
## Small visible civic/delivery routines. These actors use real streets and
## occupied homes; they never modify rent, safety, currency or customer counts.
var city: CityState
var actors: Dictionary = {}
var signature := ""
var elapsed := 0.0

func setup(model: CityState) -> void:
	city = model
	refresh()

static func lot_position(index: int) -> Vector3:
	return Vector3((index % CityState.COLUMNS - (CityState.COLUMNS - 1) / 2.0) * 12, 0, (int(index / CityState.COLUMNS) - (CityState.ROWS - 1) / 2.0) * 12)

static func entrance_x(city: CityState, index: int) -> float:
	if city.lots[index].kind != "cottage": return 0.0
	match str(city.lots[index].get("appearance", "veranda")):
		"bay": return -1.55
		"courtyard": return .2
		_: return 0.0

static func route(city: CityState, source: int, target: int) -> Array[Vector3]:
	var junctions := CityStreets.path(city, source, target)
	if junctions.is_empty(): return []
	var a := lot_position(source)
	var b := lot_position(target)
	var ax := entrance_x(city, source)
	var bx := entrance_x(city, target)
	var result: Array[Vector3] = []
	for point: Vector3 in [a + Vector3(ax, .16, 4.4), a + Vector3(ax, .16, 5.1), a + Vector3(0, .16, 5.1), a + Vector3(0, .16, 6)]:
		_append_point(result, point)
	for junction: Vector2i in junctions:
		var point := CityStreetView.junction_position(junction)
		point.y = .16
		_append_point(result, point)
	if source == target: return result # A public frontage corner when no park exists.
	for point: Vector3 in [b + Vector3(0, .16, 6), b + Vector3(0, .16, 5.1), b + Vector3(bx, .16, 5.1), b + Vector3(bx, .16, 4.4)]:
		_append_point(result, point)
	return result

static func _append_point(path: Array[Vector3], point: Vector3) -> void:
	if path.is_empty() or path[-1].distance_to(point) > .01: path.append(point)

func refresh() -> void:
	if city == null: return
	var now := int(Time.get_unix_time_from_system())
	var next := ",".join(city.street_edges)
	var headquarters := -1
	var homes: Array[int] = []
	var parks: Array[int] = []
	for index in range(city.lots.size()):
		var lot: Dictionary = city.lots[index]
		next += str(index) + lot.kind + str(lot.get("appearance", "veranda")) + str(city.is_complete(index, now)) + str(city.is_occupied(index, now))
		if not city.is_complete(index, now) or not city.has_frontage(index): continue
		if lot.kind == "hq": headquarters = index
		elif lot.kind == "park": parks.append(index)
		elif city.is_occupied(index, now): homes.append(index)
	if next == signature: return
	signature = next
	var wanted := {}
	if headquarters >= 0:
		var park := _nearest(headquarters, parks)
		_keep("patrol", headquarters, park if park >= 0 else headquarters, "patrol", 1.04, 4.0, 3.5, 15.0)
		wanted.patrol = true
		var home := _nearest(headquarters, homes)
		if home >= 0:
			_keep("courier", headquarters, home, "courier", 1.26, 2.3, 4.5, 0.0)
			wanted.courier = true
	var visitor := 0
	for home: int in homes:
		if visitor >= 2: break
		var park := _nearest(home, parks)
		if park < 0: continue
		var id := "visitor" + str(visitor)
		_keep(id, home, park, "resident", .82 + visitor * .09, 7.0, 5.0, visitor * 5.3)
		wanted[id] = true
		visitor += 1
	for id: String in actors.keys():
		if wanted.has(id): continue
		actors[id].node.queue_free()
		actors.erase(id)

func _nearest(source: int, targets: Array[int]) -> int:
	var best := -1
	var distance := 1000
	for target: int in targets:
		if target == source: continue
		var path := CityStreets.path(city, source, target)
		if not path.is_empty() and path.size() < distance:
			distance = path.size()
			best = target
	return best

func _keep(id: String, source: int, target: int, role: String, speed: float, door_stop: float, home_stop: float, offset: float) -> void:
	var key := ",".join(city.street_edges) + ":%d:%d:" % [source, target] + str(entrance_x(city, source)) + str(entrance_x(city, target))
	if actors.has(id) and actors[id].key == key: return
	var path := route(city, source, target)
	if path.size() < 2: return
	var node: Node3D
	if actors.has(id):
		node = actors[id].node
		offset = float(actors[id].clock)
	else:
		node = CityResidents.create_person(source + target, role)
		node.name = id.capitalize()
		add_child(node)
	var length := 0.0
	for segment in range(path.size() - 1): length += path[segment].distance_to(path[segment + 1])
	actors[id] = {"node":node,"key":key,"path":path,"length":length,"clock":offset,"speed":speed,"door_stop":door_stop,"home_stop":home_stop,"source":source,"target":target,"role":role}
	_animate_actor(actors[id], 0)

func _process(delta: float) -> void:
	elapsed += delta
	for id: String in actors: _animate_actor(actors[id], delta)

func _animate_actor(actor: Dictionary, delta: float) -> void:
	actor.clock = float(actor.clock) + delta
	var travel: float = actor.length / actor.speed
	var period: float = 2 * travel + actor.door_stop + actor.home_stop
	var phase := fposmod(float(actor.clock), period)
	var returning: bool = phase >= travel + actor.door_stop
	var moving: bool = phase < travel or (returning and phase < travel * 2 + actor.door_stop)
	var distance: float = minf(phase * actor.speed, actor.length)
	if returning: distance = maxf(0, actor.length - (phase - travel - actor.door_stop) * actor.speed)
	var path: Array = actor.path
	for segment in range(path.size() - 1):
		var length: float = path[segment].distance_to(path[segment + 1])
		if distance <= length and length > .001:
			actor.node.position = path[segment].lerp(path[segment + 1], distance / length)
			var direction: Vector3 = (path[segment + 1] - path[segment]) * (-1 if returning else 1)
			actor.node.rotation.y = atan2(direction.x, direction.z)
			CityResidents.animate(actor.node, elapsed, moving)
			return
		distance -= length
