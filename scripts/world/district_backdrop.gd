class_name CityDistrictBackdrop
extends RefCounted
## Non-interactive surrounding blocks and a connected perimeter frame the playable district.

static func add_to(k, columns: int, rows: int, cell: float) -> void:
	var half_width := columns * cell / 2 + 12
	var north := -rows * cell / 2 - 12
	var south := rows * cell / 2
	for x: float in [-half_width, half_width]:
		k._box(Vector3(x, .015, (north + south) / 2), Vector3(3.6, .12, south - north + 4), "paving")
		k._box(Vector3(x, .09, (north + south) / 2), Vector3(2.6, .04, south - north + 3), "road")
	k._box(Vector3(0, .015, north), Vector3(half_width * 2 + 3.6, .12, 3.6), "paving")
	k._box(Vector3(0, .09, north), Vector3(half_width * 2 + 2.6, .04, 2.6), "road")
	for x in range(-42, 45, 4):
		k._box(Vector3(x, .12, north), Vector3(.9, .01, .07), "trim")
	for side: int in [-1, 1]:
		for row in range(4):
			var z := -24.0 + row * 12
			var property := CityArchitecture.create("cottage" if row % 2 else "apartments", 1, "neutral", CityState.HOME_DESIGNS[row % 3])
			property.position = Vector3(side * 60, 0, z)
			k.node.add_child(property)
			k._box(Vector3(side * 53.5, .19, z + 4.0), Vector3(13, .08, 1.0), "paving")
			k._tree(Vector3(side * 42, .1, z + 3), .9)
	for i in range(5):
		var x := -28.0 + i * 14
		var property := CityArchitecture.create("villa" if i % 3 == 0 else "cottage", 1, "neutral", CityState.HOME_DESIGNS[i % 3])
		property.position = Vector3(x, 0, -48)
		k.node.add_child(property)
		k._box(Vector3(x, .18, -40), Vector3(1.3, .08, 8), "paving")
	for i in range(20):
		var x := -74.0 + i * 7.7
		var z := -63.0 - 5 * sin(i * 2.4)
		k._tree(Vector3(x, 0, z), 1.0 + .15 * (i % 3))
		k._ball(Vector3(x, -2.5, z - 14), Vector3(15, 7 + i % 4, 12), "grass_light")
	# A small marina provides a deliberate shoreline end instead of a cut-off slab.
	for x: float in [-61, 60]:
		k._box(Vector3(x, .12, 38), Vector3(2.2, .32, 12), "wood")
		for side: int in [-1, 1]:
			k._box(Vector3(x + side * 2.2, .1, 38), Vector3(1.4, .38, 3.5), "trim")
			k._box(Vector3(x + side * 2.2, .4, 38), Vector3(.9, .25, 1.3), "slate")
