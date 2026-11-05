class_name CityCommerce
extends RefCounted
## Assign each resident to at most one reachable seat. An occupied seat can
## change hands if its current patron has another route to a spare seat.

const SEATS_PER_LEVEL := 8
var key: Array = []
var result: Dictionary = {}

func allocate(city, now: int, planned_cafe: int = -1) -> Dictionary:
	var homes := {}
	var cafes := {}
	for index in range(city.lots.size()):
		if index == planned_cafe:
			cafes[index] = SEATS_PER_LEVEL
		elif city.is_complete(index, now):
			if city.lots[index].kind == "cafe":
				cafes[index] = city.cafe_capacity(index)
			elif city.is_occupied(index, now):
				homes[index] = city.resident_count(index)
	var signature := [city.street_edges.duplicate(), homes, cafes]
	if signature == key: return result
	var options := {}
	var reachable := 0
	for home: int in homes:
		var routes: Array[Vector2i] = []
		for cafe: int in cafes:
			var path := CityStreets.path(city, home, cafe)
			if path.size() in range(1, CityStreets.SERVICE_RANGE + 1):
				routes.append(Vector2i(path.size(), cafe))
		routes.sort()
		options[home] = []
		for route in routes: options[home].append(route.y)
		if not routes.is_empty(): reachable += int(homes[home])
	var seats := {}
	for cafe: int in cafes: seats[cafe] = []
	for home: int in homes:
		for person in range(int(homes[home])):
			if not _seat(home, options, cafes, seats, {}): break
	var counts := {}
	var destinations := {}
	var served := 0
	for cafe: int in seats:
		counts[cafe] = seats[cafe].size()
		served += int(counts[cafe])
		for home: int in seats[cafe]:
			if not destinations.has(home): destinations[home] = []
			destinations[home].append(cafe)
	key = signature
	result = {"counts":counts, "destinations":destinations, "reachable":reachable, "served":served}
	return result

func _seat(home: int, options: Dictionary, capacity: Dictionary, seats: Dictionary, visited: Dictionary) -> bool:
	for cafe: int in options[home]:
		if not visited.has(cafe) and seats[cafe].size() < int(capacity[cafe]):
			seats[cafe].append(home)
			return true
	for cafe: int in options[home]:
		if visited.has(cafe): continue
		visited[cafe] = true
		var patrons: Array = seats[cafe]
		for seat in range(patrons.size()):
			if _seat(int(patrons[seat]), options, capacity, seats, visited):
				patrons[seat] = home
				return true
	return false
