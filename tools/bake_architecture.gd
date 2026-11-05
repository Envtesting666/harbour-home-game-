extends SceneTree
## Rebuild the original Godot model library from the shared architectural rules.
## Packed scenes are used by both the game and the catalog and can be edited in Godot.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models"))
	var count := 0
	for kind: String in ["cottage", "apartments", "villa", "cafe", "park", "hq", "office", "construction"]:
		var maximum := 1 if kind in ["hq", "construction"] else 3
		for level in range(1, maximum + 1):
			var variants: Array[String] = ["neutral"]
			if kind in ["cottage", "apartments", "villa", "office"] and level >= 2:
				variants.append_array(["boutique", "community"])
			for variant: String in variants:
				var appearances: Array[String] = ["veranda"]
				if kind == "cottage":
					appearances.append_array(["bay", "courtyard"])
				for appearance: String in appearances:
					if not _save_model(kind, level, variant, appearance):
						quit(1)
						return
					count += 1
	print("ARCHITECTURE_BAKE_OK: %d native Godot scenes" % count)
	quit()

func _save_model(kind: String, level: int, variant: String, appearance: String) -> bool:
	var builder := CityArchitecture.new()
	builder.batch_instances = false
	var model := builder._build(kind, level, variant, appearance)
	_assign_owners(model, model)
	var scene := PackedScene.new()
	var error := scene.pack(model)
	if error != OK:
		push_error("Model packing failed: " + kind)
		return false
	var path := CityArchitecture.scene_path(kind, level, variant, appearance)
	error = ResourceSaver.save(scene, path)
	model.free()
	if error != OK:
		push_error("Model save failed: " + path)
		return false
	return true


func _assign_owners(parent: Node, owner_node: Node) -> void:
	for child: Node in parent.get_children():
		child.owner = owner_node
		_assign_owners(child, owner_node)
