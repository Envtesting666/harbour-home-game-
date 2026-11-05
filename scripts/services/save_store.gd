class_name CitySaveStore
extends RefCounted
## Atomic JSON saves with a last-known-good backup. Reads never mutate the model.

var path: String
var last_error := ""

func _init(save_path: String = "user://city/save.json") -> void:
	path = ProjectSettings.globalize_path(save_path)

func write(state: CityState) -> bool:
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		last_error = "Kayıt klasörü oluşturulamadı."
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Kayıt dosyası açılamadı."
		return false
	file.store_string(JSON.stringify(state.snapshot(), "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var error := DirAccess.rename_absolute(temporary, path)
	if error != OK:
		last_error = "Kayıt tamamlanamadı: " + error_string(error)
		return false
	last_error = ""
	return true

func load_into(state: CityState) -> bool:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var parsed: Variant = parser.data
		if parsed is Dictionary and state.restore(parsed):
			if candidate.ends_with(".bak"):
				last_error = "Yedek kayıt kurtarıldı."
			return true
	return false
