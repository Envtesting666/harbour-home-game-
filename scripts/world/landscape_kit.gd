class_name CityLandscape
extends RefCounted
## Shared authored vegetation shapes. Deterministic variation keeps saves stable.
## Crowns use three reusable meshes; distant detail stays in the material.

static var mesh_cache: Dictionary = {}
static var material_cache: Dictionary = {}

static func ground_material() -> ShaderMaterial:
	if material_cache.has("ground"):
		return material_cache.ground
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 grass_color:source_color;
varying vec2 ground_uv;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){ground_uv=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	float broad = noise(ground_uv*.21);
	float fine = noise(ground_uv*2.6);
	vec3 lawn = mix(grass_color.rgb, vec3(.54,.64,.37), .20 + .17*broad);
	ALBEDO = lawn * (.88 + .14*broad + .027*fine);
	ROUGHNESS = .96;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grass_color", CityArtDirection.WORLD.grass)
	material_cache.ground = mat
	return mat

static func foliage_material(tone: String) -> ShaderMaterial:
	if material_cache.has(tone):
		return material_cache[tone]
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 leaf_color:source_color;
void vertex(){float phase=NODE_POSITION_WORLD.x*.19+NODE_POSITION_WORLD.z*.23;float weight=smoothstep(-.6,.8,VERTEX.y);VERTEX.x+=sin(TIME*1.1+phase+VERTEX.z)*.035*weight;VERTEX.z+=cos(TIME*.8+phase)*.018*weight;}
void fragment(){float up=clamp(NORMAL.y*.5+.5,0.,1.);ALBEDO=leaf_color.rgb*mix(.82,1.10,up);ROUGHNESS=.94;}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("leaf_color", CityArtDirection.WORLD.get(tone.trim_prefix("foliage_"), CityArtDirection.WORLD.leaf))
	material_cache[tone] = mat
	return mat

static func foliage_mesh(variant: int) -> ArrayMesh:
	var key := "crown" + str(variant)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS := 6
	const SIDES := 10
	for ring in range(RINGS):
		for side in range(SIDES):
			var a := _crown_point(ring, side, variant, RINGS, SIDES)
			var b := _crown_point(ring + 1, side, variant, RINGS, SIDES)
			var c := _crown_point(ring + 1, side + 1, variant, RINGS, SIDES)
			var d := _crown_point(ring, side + 1, variant, RINGS, SIDES)
			for point: Vector3 in [a, c, b, a, d, c]:
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh_cache[key] = mesh
	return mesh

static func _crown_point(ring: int, side: int, seed: int, rings: int, sides: int) -> Vector3:
	var lat := -PI / 2 + PI * ring / rings
	var angle := TAU * side / sides
	var lobe := 1.0 + 0.14 * sin(angle * 3 + seed * 1.7) + 0.07 * cos(angle * 5 - lat * 3 + seed)
	return Vector3(cos(lat) * cos(angle) * lobe, sin(lat) * (0.94 + 0.06 * sin(angle * 2)), cos(lat) * sin(angle) * lobe)

static func ridge_mesh() -> ArrayMesh:
	if mesh_cache.has("ridge"):
		return mesh_cache.ridge
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(8):
		var a := PI * segment / 8
		var b := PI * (segment + 1) / 8
		var p := Vector3(-0.5, sin(a), cos(a))
		var q := Vector3(0.5, sin(a), cos(a))
		var r := Vector3(0.5, sin(b), cos(b))
		var t := Vector3(-0.5, sin(b), cos(b))
		for point: Vector3 in [p, q, r, p, r, t]:
			surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh_cache.ridge = mesh
	return mesh

static func grass_mesh() -> ArrayMesh:
	if mesh_cache.has("tuft"):
		return mesh_cache.tuft
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(5):
		var angle := blade * 2.4
		var base := Vector3(cos(angle) * 0.13, 0, sin(angle) * 0.13)
		var across := Vector3(cos(angle + PI / 2), 0, sin(angle + PI / 2)) * 0.045
		var tip := base + Vector3(cos(angle) * 0.16, 0.28 + (blade % 3) * 0.055, sin(angle) * 0.16)
		for point: Vector3 in [base - across, base + across, tip, tip, base + across, base - across]:
			surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh_cache.tuft = mesh
	return mesh

static func _branch(k, start: Vector3, end: Vector3, radius: float) -> void:
	var delta := end - start
	var axis := Vector3.UP.cross(delta.normalized())
	var rotation := Vector3.ZERO
	if axis.length() > 0.001:
		rotation = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(delta.normalized()), -1, 1))).get_euler()
	k._part("cylinder", (start + end) * 0.5, Vector3(radius, delta.length(), radius), "wood", rotation)

static func tree(k, position: Vector3, size: float) -> void:
	var seed := absi(roundi(position.x * 31 + position.z * 17))
	var umbrella := seed % 4 == 0
	_branch(k, position + Vector3(0, 0.05, 0), position + Vector3(0.08, 2.6, -0.04) * size, 0.115 * size)
	for root in range(3):
		var angle := root * TAU / 3 + seed
		_branch(k, position + Vector3(0, 0.3, 0) * size, position + Vector3(cos(angle) * 0.32, 0.04, sin(angle) * 0.32) * size, 0.07 * size)
	# Branching structure remains visible through gaps below asymmetric leaf layers.
	for branch in range(5):
		var angle := branch * 2.4 + seed * 0.4
		var spread := 0.95 if umbrella else 0.74
		var end := Vector3(cos(angle) * spread, 2.65 + 0.15 * (branch % 3), sin(angle) * spread)
		_branch(k, position + Vector3(0.04, 1.65 + branch * 0.12, 0) * size, position + end * size, 0.055 * size)
		var radius := Vector3(0.78, 0.5, 0.8) if umbrella else Vector3(0.7, 0.72, 0.69)
		var tone := "foliage_leaf_light" if branch % 3 == 0 else "foliage_leaf"
		k._part("crown" + str((seed + branch) % 3), position + end * size, radius * size, tone, Vector3(0, angle, 0))
	# A high crown and smaller edge clusters give a leaf silhouette, not two ovals.
	k._part("crown1", position + Vector3(-0.13, 3.18 if umbrella else 3.38, 0.06) * size, Vector3(1.02, 0.48 if umbrella else 0.76, 0.94) * size, "foliage_leaf_light")
	for sprig in range(7):
		var angle := sprig * 2.4 + seed * 0.3
		var center := Vector3(cos(angle) * 1.1, 2.9 + 0.4 * sin(angle * 2), sin(angle) * 1.02)
		k._part("crown" + str(sprig % 3), position + center * size, Vector3(0.29, 0.3, 0.31) * size, "foliage_leaf_light" if sprig % 2 else "foliage_leaf")
	for tuft in range(3):
		var angle := tuft * 2.4 + seed
		k._part("grass_tuft", position + Vector3(cos(angle) * 0.4, 0.02, sin(angle) * 0.4) * size, Vector3.ONE * size, "leaf_light")

static func lot_details(k, kind: String) -> void:
	if kind in ["construction", "office", "hq"]:
		return
	for side: int in [-1, 1]:
		for i in range(4):
			var x := side * (4.05 + 0.12 * sin(i * 2.4))
			k._part("grass_tuft", Vector3(x, 0.2, -3.6 + i * 0.42), Vector3.ONE * (0.65 + 0.1 * (i % 3)), "leaf_light")
