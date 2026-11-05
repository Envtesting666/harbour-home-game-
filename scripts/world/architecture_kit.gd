class_name CityArchitecture
extends RefCounted
## Original, editable architectural kit. Shared dimensions/materials/meshes keep
## all properties in the same visual world. Repeated parts use MultiMesh batches.

static var materials: Dictionary = {}
static var meshes: Dictionary = {}
var node: Node3D
var batches: Dictionary = {}
var batch_instances := true

const PALETTE := CityArtDirection.WORLD

static func neighborhood(columns: int, rows: int, cell: float) -> Node3D:
	var builder := CityArchitecture.new()
	builder.node = Node3D.new()
	builder.node.name = "CoastalLandscape"
	builder._box(Vector3(0, -0.25, 0), Vector3(512, 0.3, 512), "grass")
	# Only the public gateway is permanent. Interior lanes belong to CityStreets.
	builder._box(Vector3(-42, .015, 0), Vector3(12, .12, 2.6), "paving")
	builder._box(Vector3(-42, .09, 0), Vector3(12, .04, 1.8), "road")
	for x: float in [-45, -42, -39]:
		builder._box(Vector3(x, .114, 0), Vector3(.9, .012, .07), "trim")
	CityCoastalFinish.add_to(builder)
	CityDistrictBackdrop.add_to(builder, columns, rows, cell)
	builder._flush()
	return builder.node

static func material(key: String) -> Material:
	if key in ["harbour_water", "quay_stone", "glass"]:
		return CityCoastalFinish.material(key)
	if key == "grass":
		return CityLandscape.ground_material()
	if key.begins_with("foliage_"):
		return CityLandscape.foliage_material(key)
	if not materials.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = PALETTE.get(key, Color.WHITE)
		result.roughness = 0.84
		if key == "water":
			result.roughness = 0.23
			result.metallic = 0.14
		materials[key] = result
	return materials[key]

static func create_car(tone: String) -> Node3D:
	var k := CityArchitecture.new()
	k.node = Node3D.new()
	k._box(Vector3(0, 0.38, 0), Vector3(1.65, 0.35, 0.77), tone)
	k._box(Vector3(-0.12, 0.7, 0), Vector3(0.85, 0.38, 0.66), "glass")
	k._box(Vector3(-0.12, 0.9, 0), Vector3(0.9, 0.09, 0.72), tone)
	for x: float in [-0.53, 0.53]:
		for z: float in [-0.4, 0.4]:
			k._part("cylinder", Vector3(x, 0.21, z), Vector3(0.2, 0.13, 0.2), "metal", Vector3(PI / 2, 0, 0))
	for z: float in [-0.26, 0.26]:
		k._box(Vector3(0.84, 0.44, z), Vector3(0.035, 0.14, 0.19), "trim")
	k._flush()
	return k.node

static func mesh(type: String) -> Mesh:
	if type.begins_with("crown"):
		return CityLandscape.foliage_mesh(type.trim_prefix("crown").to_int())
	if type == "ridge_cap":
		return CityLandscape.ridge_mesh()
	if type == "grass_tuft":
		return CityLandscape.grass_mesh()
	if not meshes.has(type):
		match type:
			"box":
				meshes[type] = BoxMesh.new()
			"cylinder":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 1
				cylinder.bottom_radius = 1
				cylinder.height = 1
				cylinder.radial_segments = 20
				meshes[type] = cylinder
			_:
				var sphere := SphereMesh.new()
				sphere.radius = 1
				sphere.height = 2
				sphere.radial_segments = 16
				sphere.rings = 8
				meshes[type] = sphere
	return meshes[type]

static func create(kind: String, level: int = 1, specialization: String = "neutral", appearance: String = "veranda") -> Node3D:
	var path := scene_path(kind, level, specialization, appearance)
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			var instance := scene.instantiate() as Node3D
			_optimize_instances(instance)
			return instance
	var builder := CityArchitecture.new()
	return builder._build(kind, level, specialization, appearance)

static func scene_path(kind: String, level: int, specialization: String, appearance: String = "veranda") -> String:
	var suffix := "_" + appearance if kind == "cottage" and appearance != "veranda" else ""
	return "res://assets/models/%s_%d_%s%s.tscn" % [kind, level, specialization, suffix]

static func _optimize_instances(root: Node3D) -> void:
	# Keep editable transforms in .tscn files. Build GPU MultiMeshes at runtime;
	# headless/dummy renderers cannot reliably serialize server-side buffers.
	var groups: Dictionary = {}
	var remove: Array[Node] = []
	_collect_primitives(root, Transform3D.IDENTITY, groups, remove)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group.mesh
		multimesh.instance_count = group.transforms.size()
		for index in range(multimesh.instance_count):
			multimesh.set_instance_transform(index, group.transforms[index])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = group.material
		batch.cast_shadow = group.shadow
		root.add_child(batch)
	for part: Node in remove:
		part.get_parent().remove_child(part)
		part.free()

static func _collect_primitives(parent: Node3D, accumulated: Transform3D, groups: Dictionary, remove: Array[Node]) -> void:
	for child: Node in parent.get_children():
		if not child is Node3D:
			continue
		var transform: Transform3D = accumulated * child.transform
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0 and child.visible and child.material_override != null:
			var key := str(child.mesh.get_instance_id()) + ":" + str(child.material_override.get_instance_id()) + ":" + str(child.cast_shadow)
			if not groups.has(key):
				groups[key] = {"mesh":child.mesh, "material":child.material_override, "shadow":child.cast_shadow, "transforms":[]}
			groups[key].transforms.append(transform)
			remove.append(child)
		else:
			_collect_primitives(child, transform, groups, remove)

static func height_for(kind: String, level: int, appearance: String = "veranda") -> float:
	match kind:
		"cottage": return (5.3 if level == 1 else 6.1) if appearance == "veranda" else (7.3 if appearance == "bay" else (5.0 if level == 1 else 7.0))
		"apartments": return (2 + level) * 2.1 + 2.2
		"villa": return (3 if level >= 3 else 2) * 2.1 + 0.7
		"cafe": return 4.6
		"hq": return 11.4
		"office": return (3 + level) * 2.1 + 0.8
		"park": return 3.8
		_: return 3.6

func _part(type: String, position: Vector3, scale: Vector3, color: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var key := type + ":" + color
	if not batches.has(key):
		batches[key] = []
	var basis := Basis.from_euler(rotation) * Basis.from_scale(scale)
	batches[key].append(Transform3D(basis, position))

func _box(position: Vector3, size: Vector3, color: String) -> void:
	_part("box", position, size, color)

func _cylinder(position: Vector3, radius: float, height: float, color: String) -> void:
	_part("cylinder", position, Vector3(radius, height, radius), color)

func _ball(position: Vector3, radius: Vector3, color: String) -> void:
	_part("sphere", position, radius, color)

func _flush() -> void:
	for key: String in batches:
		var parts := key.split(":")
		if not batch_instances:
			for transform: Transform3D in batches[key]:
				var editable := MeshInstance3D.new()
				editable.mesh = mesh(parts[0])
				editable.material_override = material(parts[1])
				editable.transform = transform
				node.add_child(editable)
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh(parts[0])
		multimesh.instance_count = batches[key].size()
		for index in range(multimesh.instance_count):
			multimesh.set_instance_transform(index, batches[key][index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material(parts[1])
		node.add_child(instance)

func _build(kind: String, level: int, specialization: String, appearance: String = "veranda") -> Node3D:
	node = Node3D.new()
	node.name = kind.capitalize()
	_box(Vector3(0, 0.09, 0), Vector3(9.5, 0.18, 9.5), "grass")
	match kind:
		"cottage": _cottage(level, appearance)
		"apartments": _apartments(level)
		"villa": _villa(level)
		"cafe": _cafe(level)
		"park": _park(level)
		"hq": _headquarters()
		"office": _office(level)
		"construction": _construction()
	CityLandscape.lot_details(self, kind)
	if specialization == "community":
		for x: float in [-1.5, 1.5]:
			_box(Vector3(x, 0.65, 3.7), Vector3(1.3, 0.12, 0.45), "wood")
			_box(Vector3(x, 0.9, 3.9), Vector3(1.3, 0.5, 0.1), "wood")
	elif specialization == "boutique":
		_box(Vector3(0, 2.75, 2.9), Vector3(2.1, 0.16, 1.2), "shutter")
		for x: float in [-2.1, 2.1]:
			_box(Vector3(x, 3.0, 2.65), Vector3(1.1, 0.25, 0.35), "wood")
			_box(Vector3(x, 3.2, 2.65), Vector3(0.95, 0.26, 0.28), "leaf")
	_flush()
	return node

func _plinth(width: float, depth: float) -> void:
	_box(Vector3(0, 0.3, -0.65), Vector3(width + 0.35, 0.3, depth + 0.35), "stone")
	_box(Vector3(0, 0.2, 3.6), Vector3(1.5, 0.12, 2.0), "paving")

func _window(x: float, y: float, z: float, shutter: bool = true, width: float = 1.0, shutter_tone: String = "shutter") -> void:
	_box(Vector3(x, y, z), Vector3(width + 0.22, 1.43, 0.16), "trim")
	_box(Vector3(x, y, z + 0.1), Vector3(width, 1.18, 0.07), "glass")
	_box(Vector3(x, y, z + 0.15), Vector3(0.055, 1.2, 0.045), "trim")
	_box(Vector3(x, y - 0.13, z + 0.15), Vector3(width, 0.055, 0.045), "trim")
	_box(Vector3(x, y - 0.75, z + 0.1), Vector3(width + 0.4, 0.12, 0.35), "trim")
	if shutter:
		for side: int in [-1, 1]:
			_box(Vector3(x + side * (width / 2 + 0.3), y, z + 0.04), Vector3(0.32, 1.28, 0.11), shutter_tone)

func _door(y: float, z: float, grand: bool = false, x: float = 0.0) -> void:
	var width := 1.4 if grand else 1.0
	var height := 2.35 if grand else 1.95
	_box(Vector3(x, y + height / 2, z), Vector3(width + 0.35, height + 0.25, 0.25), "trim")
	_box(Vector3(x, y + height / 2, z + 0.14), Vector3(width, height, 0.09), "glass" if grand else "shutter")
	_box(Vector3(x + width * 0.25, y + height * 0.45, z + 0.21), Vector3(0.045, 0.22, 0.04), "wood")
	for step in range(3):
		_box(Vector3(x, 0.2 + step * 0.08, z + 0.7 - step * 0.22), Vector3(width + 0.7, 0.15, 0.75), "paving")

func _roof(width: float, depth: float, base: float, rise: float, dark: bool = false, tone: String = "") -> void:
	var w := width / 2
	var d := depth / 2
	var center_z := -0.65
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = [
		Vector3(-w, base, center_z + d), Vector3(w, base, center_z + d), Vector3(w, base + rise, center_z),
		Vector3(-w, base, center_z + d), Vector3(w, base + rise, center_z), Vector3(-w, base + rise, center_z),
		Vector3(w, base, center_z - d), Vector3(-w, base, center_z - d), Vector3(-w, base + rise, center_z),
		Vector3(w, base, center_z - d), Vector3(-w, base + rise, center_z), Vector3(w, base + rise, center_z)
	]
	for vertex: Vector3 in vertices:
		surface.set_uv(Vector2((vertex.x + w) / width, absf(vertex.z - center_z) / d))
		surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	var roof := MeshInstance3D.new()
	roof.mesh = surface.commit()
	var shader := Shader.new()
	shader.code = """shader_type spatial; render_mode cull_disabled;
uniform vec4 roof_color:source_color;
float tile_hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){vec2 p=UV*vec2(18.,9.);p.x+=mod(floor(p.y),2.)*.5;vec2 g=fract(p);float aa=max(fwidth(p.x),fwidth(p.y))*.45;float joint=1.-smoothstep(.018-aa,.055+aa,min(g.x,g.y));float tint=tile_hash(floor(p));float barrel=sin(g.x*3.14159);ALBEDO=roof_color.rgb*(.93+.10*tint+.045*barrel-.17*joint);ROUGHNESS=.80+.12*tint;NORMAL_MAP=normalize(vec3(-cos(g.x*3.14159)*.21,(1.-smoothstep(.03,.18,g.y))*.16,1.))*.5+.5;NORMAL_MAP_DEPTH=.38;}
"""
	var roof_material := ShaderMaterial.new()
	roof_material.shader = shader
	roof_material.set_shader_parameter("roof_color", PALETTE.get(tone, PALETTE.roof_dark if dark else PALETTE.roof))
	roof.material_override = roof_material
	node.add_child(roof)
	# Physical overlapping ridge caps and a narrow gutter remain visible at play scale.
	var caps := maxi(2, ceili(width / 0.43))
	for cap in range(caps):
		_part("ridge_cap", Vector3(-w + width * (cap + 0.5) / caps, base + rise + 0.015, center_z), Vector3(width / caps + 0.04, 0.15, 0.18), "roof_dark" if dark or tone == "slate" else "roof")
	_part("cylinder", Vector3(0, base - 0.12, center_z + d + 0.05), Vector3(0.045, width, 0.045), "metal", Vector3(0, 0, PI / 2))
	# Gable end walls and thick eaves share the facade material.
	for side: int in [-1, 1]:
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in [Vector3(side * w * 0.95, base, center_z - d * 0.95), Vector3(side * w * 0.95, base, center_z + d * 0.95), Vector3(side * w * 0.95, base + rise * 0.96, center_z)]:
			gable.add_vertex(vertex)
		gable.generate_normals()
		var end := MeshInstance3D.new()
		end.mesh = gable.commit()
		var mat := material("wall").duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		end.material_override = mat
		node.add_child(end)
	_box(Vector3(0, base - 0.05, center_z + d), Vector3(width, 0.18, 0.18), "trim")
	_box(Vector3(0, base - 0.05, center_z - d), Vector3(width, 0.18, 0.18), "trim")
	_box(Vector3(-width * 0.28, base + rise * 0.7, -1.1), Vector3(0.6, 1.65, 0.55), "wall_warm")
	_box(Vector3(-width * 0.28, base + rise * 0.7 + 0.83, -1.1), Vector3(0.8, 0.16, 0.72), "trim")

func _hedge(x: float, z: float, width: float) -> void:
	_box(Vector3(x, 0.45, z), Vector3(width, 0.46, 0.5), "leaf")

func _tree(position: Vector3, scale: float = 1.0) -> void:
	CityLandscape.tree(self, position, scale)

func _garden() -> void:
	_hedge(-3.35, 4.0, 2.15)
	_hedge(3.35, 4.0, 2.15)
	for side: int in [-1, 1]:
		_box(Vector3(side * 4.1, 0.45, 1.0), Vector3(0.42, 0.5, 5.4), "leaf")
		_tree(Vector3(side * 3.6, 0.15, -3.5), 0.7)

func _cottage(level: int, appearance: String) -> void:
	CityResidentialDesigns.build(self, level, appearance)

func _roof_piece(center: Vector2, width: float, depth: float, base: float, rise: float, angle: float = 0, tone: String = "roof") -> void:
	var kit := CityArchitecture.new()
	kit.batch_instances = batch_instances
	kit.node = Node3D.new()
	kit._roof(width, depth, base, rise, false, tone)
	kit._flush()
	kit.node.position.z = 0.65
	var pivot := Node3D.new()
	pivot.name = "RoofModule"
	pivot.position = Vector3(center.x, 0, center.y)
	pivot.rotation.y = angle
	pivot.add_child(kit.node)
	node.add_child(pivot)

func _side_window(x: float, y: float, z: float, width: float = 1.0) -> void:
	_box(Vector3(x, y, z), Vector3(0.15, 1.45, width + 0.22), "trim")
	_box(Vector3(x + 0.1, y, z), Vector3(0.07, 1.18, width), "glass")
	_box(Vector3(x + 0.15, y, z), Vector3(0.04, 1.2, 0.05), "trim")
	_box(Vector3(x + 0.15, y - 0.13, z), Vector3(0.04, 0.05, width), "trim")
	_box(Vector3(x + 0.1, y - 0.75, z), Vector3(0.35, 0.12, width + 0.4), "trim")

func _flower_bed(x: float, z: float, width: float = 1.4, tone: String = "flower_pink") -> void:
	_box(Vector3(x, 0.3, z), Vector3(width, 0.22, 0.65), "earth")
	for i in range(5):
		var px := x - width * 0.4 + width * 0.2 * i
		_ball(Vector3(px, 0.52, z), Vector3(0.18, 0.26, 0.22), "leaf")
		_ball(Vector3(px, 0.73, z + 0.08 * (i % 2)), Vector3(0.15, 0.12, 0.15), tone)

func _picket_fence(z: float, tone: String = "trim") -> void:
	for side: int in [-1, 1]:
		_box(Vector3(side * 2.9, 0.75, z), Vector3(2.7, 0.08, 0.09), tone)
		_box(Vector3(side * 2.9, 0.44, z), Vector3(2.7, 0.08, 0.09), tone)
		for post in range(8):
			_box(Vector3(side * 2.9 - 1.35 + post * 0.385, 0.63, z), Vector3(0.12, 0.85, 0.13), tone)

func _pergola(center: Vector2, width: float, depth: float) -> void:
	for x: float in [-width / 2 + 0.12, width / 2 - 0.12]:
		for z: float in [-depth / 2 + 0.12, depth / 2 - 0.12]:
			_box(Vector3(center.x + x, 1.5, center.y + z), Vector3(0.16, 2.5, 0.16), "wood")
	for slat in range(8):
		_box(Vector3(center.x - width / 2 + width * slat / 7.0, 2.8, center.y), Vector3(0.11, 0.17, depth + 0.25), "wood")
	for z: float in [-depth / 2 + 0.1, depth / 2 - 0.1]:
		_box(Vector3(center.x, 2.65, center.y + z), Vector3(width + 0.25, 0.2, 0.16), "wood")

func _railing(x: float, y: float, z: float, width: float) -> void:
	_box(Vector3(x, y + 0.8, z), Vector3(width, 0.055, 0.06), "metal")
	for i in range(7):
		_box(Vector3(x - width / 2 + width * i / 6.0, y + 0.4, z), Vector3(0.035, 0.8, 0.035), "metal")

func _apartments(level: int) -> void:
	var floors := 3 + level - 1
	var height := floors * 2.1
	_plinth(7.8, 6.0)
	_box(Vector3(0, 0.45 + height / 2, -0.65), Vector3(7.8, height, 6), "wall_warm")
	for floor in range(floors):
		_box(Vector3(0, 0.5 + floor * 2.1, -0.65), Vector3(8, 0.15, 6.15), "trim")
		for x: float in [-2.9, -0.96, 0.96, 2.9]:
			_window(x, 1.55 + floor * 2.1, 2.4, false, 0.95)
			if floor > 0:
				_box(Vector3(x, 0.6 + floor * 2.1, 2.9), Vector3(1.5, 0.13, 1.05), "trim")
				_railing(x, 0.7 + floor * 2.1, 3.4, 1.45)
		for z: float in [-2.4, 0.2]:
			_side_window(3.93, 1.55 + floor * 2.1, z, 1.1)
	_door(0.4, 2.5, true)
	_roof(8.35, 6.6, height + 0.5, 1.65)
	_hedge(-3.3, 4.1, 1.9)
	_hedge(3.3, 4.1, 1.9)

func _villa(level: int) -> void:
	var floors := 2 if level < 3 else 3
	var height := floors * 2.1
	_box(Vector3(-1.1, 0.3, -0.9), Vector3(6.5, 0.3, 6.2), "paving")
	_box(Vector3(-1.5, height / 2 + 0.45, -1.1), Vector3(5.3, height, 5.2), "trim")
	for floor in range(floors):
		for x: float in [-3.0, -1.1, 0.8]:
			_window(x, 1.55 + floor * 2.1, 1.56, false, 1.25)
		_box(Vector3(-1.5, 0.5 + floor * 2.1, 1.75), Vector3(5.6, 0.18, 0.4), "wall")
		for z: float in [-2.5, -0.2]:
			_side_window(1.18, 1.55 + floor * 2.1, z, 1.25)
	_box(Vector3(-1.5, height + 0.55, -1.1), Vector3(5.7, 0.25, 5.6), "wall")
	_box(Vector3(-1.5, height + 0.72, -1.1), Vector3(5.2, 0.1, 5.1), "paving")
	for x: float in [-4.25, 1.25]:
		_box(Vector3(x, height + 0.95, -1.1), Vector3(0.16, 0.6, 5.6), "trim")
	for z: float in [-3.8, 1.6]:
		_box(Vector3(-1.5, height + 0.95, z), Vector3(5.6, 0.6, 0.16), "trim")
	_part("box", Vector3(-1.7, height + 0.92, -1.4), Vector3(2.2, 0.09, 1.15), "glass", Vector3(-0.2, 0, 0))
	for x: float in [-3.4, 0.4]:
		_box(Vector3(x, height + 0.9, -2.9), Vector3(0.6, 0.35, 0.65), "stone")
		_ball(Vector3(x, height + 1.25, -2.9), Vector3(0.34, 0.35, 0.34), "leaf")
	_box(Vector3(3.0, 0.23, 0.2), Vector3(2.5, 0.18, 5.2), "paving")
	_box(Vector3(3.0, 0.34, 0.2), Vector3(2.0, 0.05, 4.5), "water")
	_box(Vector3(0, 0.22, 3.4), Vector3(7.8, 0.1, 2.0), "paving")
	for x: float in [-2.5, -0.5]:
		_box(Vector3(x, 0.45, 3.45), Vector3(0.65, 0.35, 1.5), "wood")
	_tree(Vector3(-3.8, 0.15, -3.8), 0.75)
	if level >= 2:
		_box(Vector3(0, 2.8, 3.2), Vector3(5.8, 0.18, 1.7), "wood")
		for x: float in [-2.7, 2.7]:
			_box(Vector3(x, 1.5, 3.9), Vector3(0.12, 2.7, 0.12), "wood")

func _cafe(level: int) -> void:
	_plinth(7.1, 5.4)
	_box(Vector3(0, 1.8, -1.0), Vector3(7.1, 2.8, 5.4), "wall")
	for x: float in [-2.35, 2.35]:
		_window(x, 1.55, 1.78, false, 1.65)
	_door(0.35, 1.8, true)
	_side_window(3.58, 1.6, -1.1, 1.9)
	_roof(7.6, 6.0, 3.25, 1.25)
	# One shared striped awning is geometry, not a pasted shop sprite.
	for stripe in range(14):
		_part("box", Vector3(-3.2 + stripe * 0.49, 2.7, 2.55), Vector3(0.49, 0.11, 1.6), "shutter" if stripe % 2 == 0 else "trim", Vector3(-0.19, 0, 0))
	_box(Vector3(0, 2.48, 3.35), Vector3(6.9, 0.25, 0.12), "shutter")
	# A sculpted cup sign gives commerce a recognizable silhouette at town scale.
	_cylinder(Vector3(2.5, 4.4, 0.2), 0.53, 0.8, "trim")
	_cylinder(Vector3(2.5, 4.82, 0.2), 0.43, 0.025, "wood")
	_box(Vector3(3.1, 4.4, 0.2), Vector3(0.24, 0.5, 0.18), "trim")
	_box(Vector3(0, 0.23, 3.15), Vector3(8.5, 0.08, 2.75), "paving")
	for x: float in [-2.4, 2.4]:
		_cylinder(Vector3(x, 1.02, 3.35), 0.58, 0.12, "wood")
		_cylinder(Vector3(x, 0.63, 3.35), 0.07, 0.8, "metal")
		for side: int in [-1, 1]:
			_cylinder(Vector3(x + side * 0.83, 0.54, 3.35), 0.22, 0.17, "shutter")
			_box(Vector3(x + side * 0.93, 0.85, 3.35), Vector3(0.08, 0.6, 0.45), "shutter")
	if level >= 2:
		_tree(Vector3(-4, 0.2, 1.3), 0.7)
		_tree(Vector3(4, 0.2, 1.3), 0.7)

func _park(level: int) -> void:
	_box(Vector3(0, 0.22, 0), Vector3(2.2, 0.1, 8.8), "paving")
	_box(Vector3(0, 0.23, 0), Vector3(8.8, 0.1, 2.2), "paving")
	_cylinder(Vector3(0, 0.39, 0), 1.95, 0.28, "stone")
	_cylinder(Vector3(0, 0.55, 0), 1.7, 0.06, "water")
	_cylinder(Vector3(0, 1.05, 0), 0.22, 1.0, "trim")
	_cylinder(Vector3(0, 1.62, 0), 0.78, 0.18, "trim")
	_cylinder(Vector3(0, 1.73, 0), 0.65, 0.035, "water")
	_ball(Vector3(0, 2.05, 0), Vector3(0.15, 0.3, 0.15), "trim")
	for x: float in [-3.2, 3.2]:
		for z: float in [-3.1, 3.1]:
			_tree(Vector3(x, 0.18, z), 0.9 + 0.05 * level)
	for z: float in [-2.8, 2.8]:
		_box(Vector3(0, 0.65, z), Vector3(1.8, 0.1, 0.5), "wood")
		_box(Vector3(0, 0.95, z - 0.25), Vector3(1.8, 0.5, 0.1), "wood")
		for x: float in [-0.65, 0.65]:
			_box(Vector3(x, 0.42, z), Vector3(0.08, 0.5, 0.4), "metal")

func _headquarters() -> void:
	_plinth(7.7, 6.0)
	_box(Vector3(0, 3.5, -0.65), Vector3(7.7, 6.1, 6.0), "wall")
	for floor in range(3):
		_box(Vector3(0, 0.5 + floor * 2.1, -0.65), Vector3(7.95, 0.18, 6.2), "trim")
		for x: float in [-2.5, 0.0, 2.5]:
			if floor == 0 and x == 0:
				continue
			_window(x, 1.6 + floor * 2.1, 2.4, false, 1.1)
		for z: float in [-2.5, 0.2]:
			_side_window(3.88, 1.6 + floor * 2.1, z, 1.2)
	_door(0.4, 2.5, true)
	for x: float in [-3.6, 3.6]:
		_box(Vector3(x, 3.4, 2.5), Vector3(0.32, 5.9, 0.38), "trim")
	_roof(8.2, 6.6, 6.6, 1.7, true)
	# Civic clock tower distinguishes the company hub from rental apartments.
	_box(Vector3(-2.35, 8.0, -1.2), Vector3(1.8, 3.3, 1.8), "ivory")
	_box(Vector3(-2.35, 9.7, -1.2), Vector3(2.1, 0.2, 2.1), "trim")
	_roof_piece(Vector2(-2.35, -1.2), 2.4, 2.4, 9.8, 1.4, 0, "slate")
	_part("cylinder", Vector3(-2.35, 8.7, -0.24), Vector3(0.57, 0.1, 0.57), "trim", Vector3(PI / 2, 0, 0))
	_box(Vector3(-2.35, 8.88, -0.16), Vector3(0.055, 0.4, 0.06), "metal")
	_box(Vector3(-2.2, 8.69, -0.15), Vector3(0.35, 0.055, 0.06), "metal")
	_hedge(-3.3, 4.0, 2.0)
	_hedge(3.3, 4.0, 2.0)

func _office(level: int) -> void:
	var floors := 4 + level - 1
	var height := floors * 2.1
	_plinth(7.4, 6.1)
	_box(Vector3(0, height / 2 + 0.45, -0.65), Vector3(7.4, height, 6.1), "wall")
	for floor in range(floors):
		for x: float in [-2.8, -0.95, 0.95, 2.8]:
			_window(x, 1.55 + floor * 2.1, 2.45, false, 1.5)
		for z: float in [-2.6, -0.65, 1.3]:
			_side_window(3.74, 1.55 + floor * 2.1, z, 1.25)
		_box(Vector3(0, 0.5 + floor * 2.1, -0.65), Vector3(7.65, 0.22, 6.25), "trim")
	_box(Vector3(0, height + 0.55, -0.65), Vector3(7.9, 0.25, 6.5), "trim")
	_door(0.4, 2.6, true)
	_box(Vector3(0, 2.7, 3.0), Vector3(3.6, 0.15, 1.25), "metal")

func _construction() -> void:
	_box(Vector3(0, 0.27, -0.4), Vector3(7.5, 0.28, 6.5), "stone")
	for x: float in [-3.3, 3.3]:
		for z: float in [-3.0, 2.2]:
			_box(Vector3(x, 1.3, z), Vector3(0.35, 2.2, 0.35), "wall")
	for x: float in [-3.7, 3.7]:
		for z: float in [-3.4, -0.6, 2.7]:
			_box(Vector3(x, 1.9, z), Vector3(0.09, 3.3, 0.09), "construction")
		_box(Vector3(x, 1.9, -0.3), Vector3(0.6, 0.08, 6.4), "wood")
	for i in range(4):
		_box(Vector3(-1.5 + i * 0.9, 0.65, 3.7), Vector3(0.7, 0.75, 0.55), "construction")
	_box(Vector3(0, 0.65, -2.8), Vector3(6.5, 0.8, 0.3), "wall_warm")
