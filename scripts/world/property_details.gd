class_name CityPropertyDetails
extends RefCounted
## Stable property identity, applied to the live model and its actual preview.
## Clones of facade materials are cached; shared architectural assets stay intact.
static var facade_materials: Dictionary = {}

static func dress(root: Node3D, seed: int, kind: String, appearance: String, level: int) -> void:
	if root.has_meta("property_details"): return
	root.set_meta("property_details", seed)
	if kind not in ["cottage", "apartments", "villa", "cafe", "office", "hq"]: return
	if kind != "hq": _facade(root, posmod(seed, 4))
	var k := CityArchitecture.new()
	k.node = Node3D.new()
	k.node.name = "PersonalDetails"
	var flower: String = ["flower_white", "flower_yellow", "flower_pink"][posmod(seed, 3)]
	if kind == "cottage":
		match appearance:
			"bay":
				_window_box(k, Vector3(1.15, .92, 3.32), 1.4, flower)
				if seed % 2 == 0: _window_box(k, Vector3(1.15, 3.02, 3.32), 1.4, flower)
				_mailbox(k, Vector3(-3.9, .2, 4.05), "coral" if seed % 2 else "slate")
			"courtyard":
				_pot(k, Vector3(-3.45, .38, 3.25), flower, .9)
				# A restrained flowering vine follows the existing pergola's front post.
				for i in range(5):
					var at := Vector3(2.88 + .11 * sin(i * 2.4), 1.05 + i * .31, 3.25)
					k._ball(at, Vector3(.18, .19, .13), "leaf")
					if i % 2 == seed % 2: k._ball(at + Vector3(.07, .05, .10), Vector3(.09, .08, .08), flower)
			_:
				_pot(k, Vector3(4.1, .2, 3.3), flower)
				if seed % 3 == 0:
					_bench(k, Vector3(-1.9, .36, 2.7))
				else:
					_pot(k, Vector3(-4.1, .2, 3.3), flower, .85)
	elif kind == "apartments":
		for x: float in [-2.9, 2.9]: _window_box(k, Vector3(x, 3.18, 3.47), .95, flower)
		_pot(k, Vector3(4.1, .2, 3.15), flower, 1.05)
	elif kind == "cafe":
		# A small A-board sits beside the terrace, clear of its entrance route.
		for side: int in [-1, 1]:
			k._part("box", Vector3(3.85, .74, 4.0 + side * .16), Vector3(.64, .98, .08), "wood", Vector3(side * .16, 0, 0))
		k._box(Vector3(3.85, .83, 4.205), Vector3(.48, .64, .025), "slate")
		for i in range(3): k._box(Vector3(3.85, 1.01 - i * .14, 4.224), Vector3(.30 - i * .035, .025, .012), "ivory")
		_pot(k, Vector3(-4.1, .2, 3.9), flower)
	elif kind in ["villa", "office", "hq"]:
		for side: int in [-1, 1]: _pot(k, Vector3(side * 4.12, .2, 3.3), flower, .88)
	k._flush()
	root.add_child(k.node)

static func _facade(root: Node3D, variant: int) -> void:
	if variant == 0: return
	var palette := CityArtDirection.WORLD
	var mappings := {"butter":"ivory", "coral":"wall_warm", "ivory":"wall", "azure":"shutter", "wall_warm":"ivory", "wall":"butter"}
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var material := (node as GeometryInstance3D).material_override as StandardMaterial3D
		if material == null: continue
		for tone: String in mappings:
			if not material.albedo_color.is_equal_approx(palette[tone]): continue
			var key := str(material.get_instance_id()) + ":" + str(variant)
			if not facade_materials.has(key):
				var clone := material.duplicate() as StandardMaterial3D
				var mix: float = [.0, .14, .23, .31][variant]
				clone.albedo_color = material.albedo_color.lerp(palette[mappings[tone]], mix)
				facade_materials[key] = clone
			(node as GeometryInstance3D).material_override = facade_materials[key]
			break

static func _pot(k, at: Vector3, flower: String, scale: float = 1.0) -> void:
	k._cylinder(at + Vector3(0, .23, 0) * scale, .24 * scale, .44 * scale, "roof")
	k._cylinder(at + Vector3(0, .46, 0) * scale, .27 * scale, .10 * scale, "roof")
	k._cylinder(at + Vector3(0, .50, 0) * scale, .22 * scale, .035 * scale, "earth")
	for i in range(5):
		var angle := i * 2.4
		var point := at + Vector3(cos(angle) * .16, .66 + .04 * (i % 2), sin(angle) * .16) * scale
		k._ball(point, Vector3(.19, .23, .17) * scale, "leaf_light" if i % 2 else "leaf")
		k._ball(point + Vector3(0, .14, .02) * scale, Vector3(.105, .085, .10) * scale, flower)

static func _window_box(k, at: Vector3, width: float, flower: String) -> void:
	k._box(at, Vector3(width, .20, .30), "wood")
	k._box(at + Vector3(0, .11, 0), Vector3(width - .1, .025, .24), "earth")
	for i in range(4):
		var point := at + Vector3(-width * .35 + i * width * .235, .25, .025)
		k._ball(point, Vector3(.17, .18, .17), "leaf")
		k._ball(point + Vector3(.02, .10, .045), Vector3(.105, .09, .105), flower)

static func _mailbox(k, at: Vector3, color: String) -> void:
	k._box(at + Vector3(0, .47, 0), Vector3(.09, .95, .09), "wood")
	k._box(at + Vector3(0, 1.0, 0), Vector3(.46, .30, .38), color)
	k._box(at + Vector3(0, 1.04, .201), Vector3(.28, .035, .02), "metal")
	k._box(at + Vector3(.25, 1.13, 0), Vector3(.04, .16, .08), "coral")

static func _bench(k, at: Vector3) -> void:
	for side: int in [-1, 1]: k._box(at + Vector3(side * .43, .18, 0), Vector3(.07, .38, .35), "metal")
	k._box(at + Vector3(0, .42, 0), Vector3(1.15, .11, .44), "wood")
	for slat in range(2): k._box(at + Vector3(0, .67 + slat * .16, -.19), Vector3(1.15, .11, .07), "wood")
