class_name CityResidents
extends RefCounted
## Lightweight decorative townspeople, with articulated walk cycles.
## Their routes reflect occupied homes and cafes; they are not a needs simulation.

static func create_person(variant: int, role: String = "resident") -> Node3D:
	var root := Node3D.new()
	root.name = "Resident"
	var shirt: String = ["shutter", "coral", "butter", "slate"][variant % 4]
	if role == "patrol": shirt = "slate"
	elif role == "courier": shirt = "shutter"
	_part(root, "Torso", "box", Vector3(0, 0.76, 0), Vector3(0.3, 0.43, 0.22), shirt)
	_part(root, "Head", "sphere", Vector3(0, 1.16, 0), Vector3(0.16, 0.18, 0.16), "skin")
	_part(root, "Hair", "sphere", Vector3(0, 1.29, -0.025), Vector3(0.17, 0.10, 0.16), "wood")
	for side: int in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegLeft" if side < 0 else "LegRight"
		leg.position = Vector3(side * 0.09, 0.55, 0)
		root.add_child(leg)
		_part(leg, "Trouser", "box", Vector3(0, -0.2, 0), Vector3(0.11, 0.4, 0.13), "slate")
		_part(leg, "Shoe", "box", Vector3(0, -0.43, 0.035), Vector3(0.13, 0.1, 0.22), "metal")
		var arm := Node3D.new()
		arm.name = "ArmLeft" if side < 0 else "ArmRight"
		arm.position = Vector3(side * 0.205, 0.91, 0)
		root.add_child(arm)
		_part(arm, "Sleeve", "box", Vector3(0, -0.08, 0), Vector3(0.1, 0.18, 0.13), shirt)
		_part(arm, "Forearm", "box", Vector3(0, -0.25, 0), Vector3(0.075, 0.21, 0.085), "skin")
	if role == "patrol":
		_part(root, "UniformCap", "sphere", Vector3(0, 1.39, 0), Vector3(.18, .065, .18), "slate")
		_part(root, "CapPeak", "box", Vector3(0, 1.36, .15), Vector3(.27, .035, .18), "slate")
		_part(root, "Badge", "box", Vector3(.07, .85, .122), Vector3(.055, .07, .018), "citrus")
		_part(root, "Belt", "box", Vector3(0, .59, 0), Vector3(.31, .055, .23), "metal")
	elif role == "courier":
		_part(root, "DeliveryCap", "sphere", Vector3(0, 1.39, 0), Vector3(.18, .065, .18), "citrus")
		_part(root, "CapPeak", "box", Vector3(0, 1.36, .15), Vector3(.27, .035, .18), "citrus")
		_part(root, "ParcelBag", "box", Vector3(-.245, .72, -.015), Vector3(.20, .31, .23), "wood")
		_part(root, "BagStrap", "box", Vector3(-.18, .87, -.015), Vector3(.035, .32, .20), "wood")
		_part(root, "ParcelBand", "box", Vector3(-.245, .72, .108), Vector3(.04, .31, .015), "ivory")
	return root

static func _part(parent: Node3D, label: String, mesh: String, position: Vector3, size: Vector3, tone: String) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = CityArchitecture.mesh(mesh)
	part.material_override = CityArchitecture.material(tone)
	part.position = position
	part.scale = size
	parent.add_child(part)

static func animate(person: Node3D, time: float, moving: bool) -> void:
	var swing := sin(time * 7.2) * 0.45 if moving else 0.0
	person.get_node("LegLeft").rotation.x = swing
	person.get_node("LegRight").rotation.x = -swing
	person.get_node("ArmLeft").rotation.x = -swing * 0.7
	person.get_node("ArmRight").rotation.x = swing * 0.7
