class_name CityCoastalFinish
extends RefCounted
## The public quay shares the town's scale and never occupies a player parcel.

static var finishes: Dictionary = {}

static func material(key: String) -> ShaderMaterial:
	if finishes.has(key):
		return finishes[key]
	var shader := Shader.new()
	match key:
		"harbour_water": shader.code = WATER
		"quay_stone": shader.code = PAVERS
		"glass": shader.code = GLAZING
	var finish := ShaderMaterial.new()
	finish.shader = shader
	finishes[key] = finish
	return finish

static func add_to(builder) -> void:
	builder._box(Vector3(0, -.08, 170), Vector3(512, .04, 277), "harbour_water")
	builder._box(Vector3(0, .02, 28.8), Vector3(164, .2, 6.8), "quay_stone")
	# Recessed masonry with an overhanging cap and a darker tidal course.
	builder._box(Vector3(0, -.045, 32.05), Vector3(164, .62, .54), "stone")
	builder._box(Vector3(0, -.18, 32.36), Vector3(164, .28, .18), "slate")
	for block in range(82):
		var x := -81.0 + block * 2.0
		var tone := "ivory" if block % 5 == 1 else "paving"
		builder._box(Vector3(x, .28, 32.16), Vector3(1.96, .18, .76), tone)
		builder._box(Vector3(x, .08, 32.35), Vector3(1.94, .23, .16), "stone" if block % 4 != 0 else "paving")
	for x in range(-78, 82, 8):
		builder._tree(Vector3(x, .15, 28.8), .8)
		_bench(builder, Vector3(x + 2.7, .12, 29.0))
		_bollard(builder, Vector3(x + 1.0, .37, 32.13))
	_pier(builder, -33.0, 5.4)
	_pier(builder, 7.0, 4.4)
	_skiff(builder, Vector3(-31.1, .01, 37.2), "shutter")
	_skiff(builder, Vector3(5.2, .01, 36.8), "roof")

static func _bench(builder, at: Vector3) -> void:
	for x: float in [-.58, .58]:
		builder._box(at + Vector3(x, .22, 0), Vector3(.10, .44, .48), "metal")
	for row in range(3):
		builder._box(at + Vector3(0, .46, -.18 + row * .17), Vector3(1.74, .09, .15), "wood")
	for slat in range(2):
		builder._box(at + Vector3(0, .65 + slat * .16, .27), Vector3(1.74, .12, .08), "wood")

static func _bollard(builder, at: Vector3) -> void:
	builder._cylinder(at + Vector3(0, .14, 0), .105, .29, "metal")
	builder._cylinder(at + Vector3(0, .30, 0), .155, .065, "metal")

static func _pier(builder, x: float, length: float) -> void:
	var center := Vector3(x, .16, 32.55 + length * .5)
	builder._box(center, Vector3(2.0, .16, length), "wood")
	for plank in range(ceili(length / .35)):
		var z := 32.6 + plank * .35
		builder._box(Vector3(x, .245, z), Vector3(1.95, .04, .31), "paving" if plank % 5 == 1 else "wood")
	for side: int in [-1, 1]:
		for z: float in [33.0, 32.55 + length * .56, 32.37 + length]:
			builder._cylinder(Vector3(x + side * .91, .18, z), .12, .79, "wood")
			builder._cylinder(Vector3(x + side * .91, .59, z), .143, .055, "metal")

static func _skiff(builder, at: Vector3, tone: String) -> void:
	# Nested flat ellipsoids form the hull, painted gunwale and recessed floor.
	builder._ball(at + Vector3(0, .06, 0), Vector3(.56, .24, 1.31), tone)
	builder._ball(at + Vector3(0, .24, 0), Vector3(.55, .12, 1.27), "ivory")
	builder._ball(at + Vector3(0, .31, 0), Vector3(.43, .055, 1.04), "slate")
	for z: float in [-.48, .39]:
		builder._box(at + Vector3(0, .395, z), Vector3(.86, .055, .16), "wood")
	builder._box(at + Vector3(0, .35, -1.03), Vector3(.37, .12, .20), "wood")

const WATER := """shader_type spatial;
render_mode unshaded;
varying vec2 coast;
uniform vec4 shallow: source_color = vec4(.28,.68,.66,1.);
uniform vec4 deep: source_color = vec4(.10,.43,.57,1.);
uniform vec4 glint: source_color = vec4(.64,.88,.82,1.);
void vertex() { coast = (MODEL_MATRIX * vec4(VERTEX, 1.)).xz; }
void fragment() {
	float depth = max(0., coast.y - 32.45);
	float time = TIME * .55;
	float swell = sin(coast.y*.89 + 1.65*sin(coast.x*.17 + time*.39) + time);
	float ripple = sin(coast.x*.66 + coast.y*1.47 + sin(coast.x*.11 - time) - time*.73);
	float patches = .5 + .5*sin(coast.x*.22 - coast.y*.19 + .66*swell);
	float sparkle = smoothstep(.71, 1.18, swell*.68 + ripple*.54) * patches;
	float shore = exp(-depth*.34);
	float wash = exp(-abs(depth - .53 - .12*swell)*2.8);
	vec3 sea = mix(deep.rgb, shallow.rgb, shore*.86 + .11);
	ALBEDO = mix(sea * (1. + .042*swell), glint.rgb, sparkle*.16 + wash*.23);
}
"""

const PAVERS := """shader_type spatial;
varying vec2 stones;
uniform vec4 limestone: source_color = vec4(.82,.74,.60,1.);
void vertex() { stones = (MODEL_MATRIX * vec4(VERTEX,1.)).xz; }
void fragment() {
	float row = floor(stones.y / .82);
	vec2 tile = vec2(stones.x/1.52 + mod(row,2.)*.5, stones.y/.82);
	vec2 interior = min(fract(tile), 1.-fract(tile));
	vec2 blend = max(fwidth(tile), vec2(.008));
	vec2 seams = smoothstep(vec2(.014), vec2(.014)+blend, interior);
	float tone = .94 + .10 * fract(sin(dot(floor(tile), vec2(13.2,91.7))) * 43758.5453);
	ALBEDO = limestone.rgb * tone * mix(.86, 1., seams.x*seams.y);
	ROUGHNESS = .93;
}
"""

const GLAZING := """shader_type spatial;
varying vec3 pane;
uniform vec4 cobalt: source_color = vec4(.095,.25,.34,1.);
uniform vec4 reflected_sky: source_color = vec4(.41,.68,.73,1.);
void vertex() { pane = VERTEX; }
void fragment() {
	float height = clamp(pane.y+.5,0.,1.);
	float diagonal = pane.y + .35*(pane.x - pane.z);
	float band = smoothstep(-.13,-.03,diagonal) * (1.-smoothstep(.03,.14,diagonal));
	float rim = pow(1.-abs(dot(normalize(NORMAL), normalize(VIEW))), 3.);
	ALBEDO = mix(cobalt.rgb, reflected_sky.rgb, .14*height+.20*band+.22*rim);
	ROUGHNESS = .29;
	SPECULAR = .38;
}
"""
