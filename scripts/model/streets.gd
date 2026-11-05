class_name CityStreets
extends RefCounted
## Shared street topology for construction, local trade, forecasts and walkers.
## Keys address parcel-boundary segments on a 7 by 5 junction lattice.

const PRICE := 180
const REFUND := 90
const SOURCE := Vector2i(0, 2)
const SERVICE_RANGE := 2
static var graphs: Dictionary = {}

static func seed_edges() -> Array[String]:
	return ["h:0:2", "h:1:2", "h:2:2", "v:1:2", "h:1:3", "h:2:3"]

static func all_edges() -> Array[String]:
	var result: Array[String] = []
	for y in range(5):
		for x in range(6): result.append("h:%d:%d" % [x, y])
	for y in range(4):
		for x in range(7): result.append("v:%d:%d" % [x, y])
	return result

static func valid_key(key: String) -> bool:
	var pieces := key.split(":")
	if pieces.size() != 3 or pieces[0] not in ["h", "v"]: return false
	if not pieces[1].is_valid_int() or not pieces[2].is_valid_int(): return false
	var x := int(pieces[1])
	var y := int(pieces[2])
	if key != "%s:%d:%d" % [pieces[0], x, y]: return false
	return x >= 0 and y >= 0 and (x < 6 and y < 5 if pieces[0] == "h" else x < 7 and y < 4)

static func endpoints(key: String) -> Array[Vector2i]:
	if not valid_key(key): return []
	var pieces := key.split(":")
	var start := Vector2i(int(pieces[1]), int(pieces[2]))
	return [start, start + (Vector2i.RIGHT if pieces[0] == "h" else Vector2i.DOWN)]

static func frontage(index: int) -> String:
	return "h:%d:%d" % [index % 6, int(index / 6) + 1]

static func key_within_columns(key: String, columns: int) -> bool:
	if not valid_key(key): return false
	var pieces := key.split(":")
	return int(pieces[1]) < columns if pieces[0] == "h" else int(pieces[1]) <= columns

static func _graph(city) -> Dictionary:
	var key := ",".join(city.street_edges)
	if graphs.has(key): return graphs[key]
	var adjacency := {}
	for edge: String in city.street_edges:
		var ends := endpoints(edge)
		if ends.is_empty(): continue
		for junction: Vector2i in ends:
			if not adjacency.has(junction): adjacency[junction] = []
		adjacency[ends[0]].append(ends[1])
		adjacency[ends[1]].append(ends[0])
	var connected := {SOURCE:true}
	var queue: Array[Vector2i] = [SOURCE]
	var cursor := 0
	while cursor < queue.size():
		var here := queue[cursor]
		cursor += 1
		for next: Vector2i in adjacency.get(here, []):
			if connected.has(next): continue
			connected[next] = true
			queue.append(next)
	var graph := {"adjacency":adjacency, "connected":connected, "paths":{}}
	if graphs.size() >= 64: graphs.erase(graphs.keys()[0])
	graphs[key] = graph
	return graph

static func reachable(city) -> Dictionary:
	return _graph(city).connected

static func has_frontage(city, index: int) -> bool:
	if not city.valid_index(index): return false
	var key := frontage(index)
	return key in city.street_edges and endpoints(key)[0] in reachable(city)

static func valid_network(edges: Array) -> bool:
	if edges.size() > 58: return false
	var seen := {}
	for edge: Variant in edges:
		if not edge is String or not valid_key(edge) or seen.has(edge): return false
		seen[edge] = true
	# A saved network must form one source-connected component. The mutation
	# API only grows that component; disconnected arbitrary files are rejected.
	var connected := {SOURCE:true}
	var changed := true
	while changed:
		changed = false
		for edge: String in edges:
			var ends := endpoints(edge)
			if ends[0] in connected or ends[1] in connected:
				for junction: Vector2i in ends:
					if junction not in connected:
						connected[junction] = true
						changed = true
	for edge: String in edges:
		if endpoints(edge)[0] not in connected: return false
	return true

static func path(city, home: int, cafe: int) -> Array[Vector2i]:
	if not has_frontage(city, home) or not has_frontage(city, cafe): return []
	var graph := _graph(city)
	var pair := "%d:%d" % [home, cafe]
	if graph.paths.has(pair): return graph.paths[pair].duplicate()
	var home_ends := endpoints(frontage(home))
	var cafe_ends := endpoints(frontage(cafe))
	var best: Array[Vector2i] = []
	for origin: Vector2i in home_ends:
		var previous := {origin:origin}
		var queue: Array[Vector2i] = [origin]
		var cursor := 0
		while cursor < queue.size():
			var here := queue[cursor]
			cursor += 1
			for next: Vector2i in graph.adjacency.get(here, []):
				if previous.has(next): continue
				previous[next] = here
				queue.append(next)
		for target: Vector2i in cafe_ends:
			if not previous.has(target): continue
			var route: Array[Vector2i] = [target]
			var junction := target
			while junction != origin:
				junction = previous[junction]
				route.push_front(junction)
			if best.is_empty() or route.size() < best.size(): best = route
	graph.paths[pair] = best
	return best.duplicate()

static func can_reach(city, home: int, cafe: int) -> bool:
	var route := path(city, home, cafe)
	return not route.is_empty() and route.size() <= SERVICE_RANGE
