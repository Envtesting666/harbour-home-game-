extends SceneTree

func _initialize() -> void:
	var font := load("res://assets/fonts/NunitoSans.ttf") as FontFile
	print("FONT_AXES: ", font.get_supported_variation_list())
	var mesh := CityLandscape.foliage_mesh(0)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var dot_sum := 0.0
	for i in range(vertices.size()):
		dot_sum += vertices[i].dot(normals[i])
	print("FOLIAGE_NORMAL_ORIENTATION: ", dot_sum / vertices.size())
	quit()
