class_name CityResidentialDesigns
extends RefCounted
## Three silhouettes, shared doors/windows/materials and lot scale.
## Appearance is an expressive choice, separate from economic specialization.

const NAMES := {"veranda":"Verandalı sahil evi", "bay":"Cumbalı şehir evi", "courtyard":"Avlulu köşk"}

static func build(kit, level: int, appearance: String) -> void:
	match appearance:
		"bay": _bay(kit, level)
		"courtyard": _courtyard(kit, level)
		_: _veranda(kit, level)

static func _veranda(k, level: int) -> void:
	# A low, wide bungalow with a real covered veranda and white garden fence.
	k._box(Vector3(0, 0.3, -0.7), Vector3(6.6, 0.3, 5.8), "stone")
	k._box(Vector3(0, 1.85, -0.85), Vector3(6, 2.8, 5.2), "butter")
	for x: float in [-1.9, 1.9]:
		k._window(x, 1.75, 1.82, true, 1.0, "slate")
	k._door(0.45, 1.82)
	k._side_window(3.02, 1.75, -1.5)
	k._roof_piece(Vector2(0, -0.85), 6.8, 5.95, 3.28, 1.7)
	k._box(Vector3(0, 0.38, 2.65), Vector3(6.5, 0.25, 1.8), "wood")
	k._part("box", Vector3(0, 2.98, 2.65), Vector3(6.8, 0.16, 2.05), "roof", Vector3(-0.12, 0, 0))
	for x: float in [-2.85, 2.85]:
		k._box(Vector3(x, 1.72, 3.38), Vector3(0.18, 2.55, 0.18), "trim")
		k._box(Vector3(x, 0.7, 3.38), Vector3(0.3, 0.5, 0.3), "trim")
		k._box(Vector3(x * 0.67, 1.22, 3.38), Vector3(1.9, 0.09, 0.1), "trim")
		for spindle in range(5):
			k._box(Vector3(x * 0.67 - 0.8 + spindle * 0.4, 0.89, 3.38), Vector3(0.07, 0.65, 0.07), "trim")
	k._picket_fence(4.35)
	k._flower_bed(-2.8, 3.93, 1.9, "flower_pink")
	k._flower_bed(2.8, 3.93, 1.9, "flower_yellow")
	k._tree(Vector3(-3.9, 0.15, -2.8), 0.73)
	# Mailbox and stepping stones make the entrance readable from the game camera.
	k._box(Vector3(1.13, 0.73, 4.1), Vector3(0.1, 1.05, 0.1), "wood")
	k._box(Vector3(1.13, 1.28, 4.1), Vector3(0.47, 0.31, 0.42), "slate")
	for z: float in [3.7, 4.2]:
		k._cylinder(Vector3(0, 0.24, z), 0.38, 0.09, "paving")
	if level >= 2:
		k._box(Vector3(0.6, 4.0, 0.35), Vector3(1.8, 1.3, 1.5), "butter")
		k._window(0.6, 4.0, 1.15, false, 0.8)
		k._roof_piece(Vector2(0.6, 0.35), 2.2, 1.9, 4.65, 0.9, PI / 2, "slate")
	if level >= 3:
		k._pergola(Vector2(3.75, 0.4), 1.4, 2.5)
		k._flower_bed(3.7, -1.8, 1.4, "flower_white")

static func _bay(k, level: int) -> void:
	# Narrow two-storey coral house. A projecting bay and front-facing gable
	# break the mass, rather than reusing the bungalow with another paint color.
	k._box(Vector3(-0.3, 0.3, -0.7), Vector3(5.9, 0.3, 6.0), "stone")
	k._box(Vector3(-0.3, 2.65, -0.75), Vector3(5.5, 4.4, 5.5), "coral")
	k._roof_piece(Vector2(-0.3, -0.75), 6.2, 6.15, 4.9, 1.85, PI / 2, "slate")
	for floor in range(2):
		k._window(-1.55, 1.6 + floor * 2.1, 2.05, true, 0.95, "slate")
		k._side_window(2.48, 1.6 + floor * 2.1, -1.5)
		k._box(Vector3(-0.3, 0.55 + floor * 2.1, 2.08), Vector3(5.8, 0.13, 0.22), "trim")
	# Ground-level entry sits beside the bay, not in the middle of its glass.
	k._door(0.42, 2.12, false, -1.55)
	k._box(Vector3(1.15, 2.7, 2.35), Vector3(2.05, 4.5, 1.45), "ivory")
	for floor in range(2):
		k._window(1.15, 1.65 + floor * 2.1, 3.1, false, 1.4)
		k._side_window(2.2, 1.65 + floor * 2.1, 2.35, 0.7)
	k._roof_piece(Vector2(1.15, 2.35), 2.5, 1.95, 4.98, 0.8, 0, "slate")
	k._box(Vector3(-1.55, 2.66, 2.7), Vector3(1.65, 0.16, 1.05), "trim")
	k._railing(-1.55, 2.75, 3.2, 1.65)
	k._box(Vector3(-1.55, 0.22, 3.65), Vector3(1.55, 0.1, 2.0), "paving")
	k._hedge(2.7, 4.2, 2.8)
	k._flower_bed(2.7, 3.9, 2.2, "flower_white")
	k._tree(Vector3(-4, 0.15, -2.7), 0.7)
	for i in range(3):
		k._box(Vector3(3.8, 0.25, -0.7 + i * 1.2), Vector3(0.6, 0.13, 0.8), "paving")
	if level >= 2:
		k._flower_bed(-1.55, 3.45, 1.45, "flower_pink")
		k._pergola(Vector2(3.5, 1.0), 1.6, 2.4)
	if level >= 3:
		k._box(Vector3(-0.5, 5.8, -0.7), Vector3(1.4, 0.9, 1.5), "coral")
		k._roof_piece(Vector2(-0.5, -0.7), 1.8, 1.9, 6.25, 0.75, 0, "slate")

static func _courtyard(k, level: int) -> void:
	# L-shaped white-and-turquoise home around an open citrus courtyard.
	var h := 2.7 if level == 1 else 4.8
	k._box(Vector3(0, 0.25, -0.2), Vector3(8.2, 0.18, 8.2), "paving")
	k._box(Vector3(-2.45, 0.45 + h / 2, -0.6), Vector3(2.8, h, 6.0), "ivory")
	k._box(Vector3(0.7, 1.8, -2.3), Vector3(5.7, 2.7, 2.6), "azure")
	k._roof_piece(Vector2(-2.45, -0.6), 6.7, 3.35, 0.45 + h, 1.25, PI / 2)
	k._roof_piece(Vector2(0.7, -2.3), 6.1, 3.25, 3.2, 1.2)
	k._window(-2.45, 1.65, 2.44, true, 0.9)
	k._door(0.42, -0.95, false, 0.55)
	k._window(2.45, 1.65, -0.95, true, 0.9)
	k._side_window(3.58, 1.65, -2.3)
	if level >= 2:
		k._window(-2.45, 3.75, 2.44, true, 0.9)
		k._side_window(-1.02, 3.75, -0.1)
	# Courtyard tiles, citrus planters, shade and a small table.
	for x in range(4):
		for z in range(4):
			if (x + z) % 2 == 0:
				k._box(Vector3(-0.25 + x * 0.8, 0.37, 0.2 + z * 0.8), Vector3(0.67, 0.03, 0.67), "ivory")
	k._pergola(Vector2(1.1, 1.6), 3.8, 3.5)
	k._cylinder(Vector3(1.1, 0.62, 1.7), 0.1, 0.7, "metal")
	k._cylinder(Vector3(1.1, 1.0, 1.7), 0.65, 0.12, "azure")
	for x: float in [-0.25, 2.6]:
		k._box(Vector3(x, 0.5, 3.55), Vector3(0.7, 0.65, 0.7), "roof")
		k._tree(Vector3(x, 0.7, 3.55), 0.55)
		for dx: float in [-0.25, 0.25]:
			k._ball(Vector3(x + dx, 2.07, 3.8), Vector3(0.13, 0.13, 0.13), "citrus")
	k._box(Vector3(0, 0.65, 4.05), Vector3(8.1, 0.7, 0.23), "ivory")
	k._box(Vector3(0.2, 0.64, 4.09), Vector3(1.0, 0.72, 0.1), "shutter")
	if level >= 3:
		k._flower_bed(1.0, -0.25, 2.2, "flower_pink")
