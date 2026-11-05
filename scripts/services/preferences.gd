class_name CityPreferences
extends RefCounted

var language := "en"
var effects := 0.8
var path: String

func _init(location: String) -> void:
	path = location
	var config := ConfigFile.new()
	if config.load(path) == OK:
		language = str(config.get_value("game", "language", "en"))
		effects = clampf(float(config.get_value("audio", "effects", 0.8)), 0, 1)
	if language not in ["en", "tr"]:
		language = "en"
	CityLocale.set_language(language)

func save() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var config := ConfigFile.new()
	config.set_value("game", "language", language)
	config.set_value("audio", "effects", effects)
	return config.save(path)
