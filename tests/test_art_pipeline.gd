extends SceneTree

func _initialize() -> void:
	var directory := DirAccess.open("res://assets/models")
	var checked := 0
	var failures := 0
	for filename: String in directory.get_files():
		if not filename.ends_with(".tscn"):
			continue
		var scene := load("res://assets/models/" + filename) as PackedScene
		if scene == null:
			push_error("Cannot load model scene: " + filename)
			failures += 1
			continue
		var model := scene.instantiate()
		var geometry := model.find_children("*", "MeshInstance3D", true, false)
		if geometry.size() < 8 or not model.find_children("*", "MultiMeshInstance3D", true, false).is_empty():
			push_error("Editable geometry is missing or GPU-only in: " + filename)
			failures += 1
		for part: MeshInstance3D in geometry:
			if part.mesh == null or absf(part.transform.basis.determinant()) < 0.0000001:
				push_error("Invalid geometry transform: " + filename)
				failures += 1
		if not _within_lot(model, Transform3D.IDENTITY):
			push_error("Geometry stretches outside its lot/height budget: " + filename)
			failures += 1
		model.free()
		checked += 1
	if checked != 50:
		push_error("Expected 50 native model scenes, got " + str(checked))
		failures += 1
	print("ART_PIPELINE_TESTS: %d scenes, %d failures" % [checked, failures])
	quit(0 if failures == 0 else 1)

func _within_lot(parent: Node3D, accumulated: Transform3D) -> bool:
	for child: Node in parent.get_children():
		if not child is Node3D:
			continue
		var transform: Transform3D = accumulated * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var bounds: AABB = transform * child.get_aabb()
			if bounds.position.y < -0.5 or bounds.end.y > 16 or bounds.position.x < -6 or bounds.end.x > 6 or bounds.position.z < -6 or bounds.end.z > 6:
				return false
		if not _within_lot(child, transform):
			return false
	return true
