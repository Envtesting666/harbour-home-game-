class_name CityCatalog
extends RefCounted

const LAND_PRICE := 600
const LEASES := {
	"short": {"name":"Kısa kontrat", "label":"20 saniye", "seconds":20, "factor":1.0, "fee":0},
	"regular": {"name":"Düzenli kiracı", "label":"1 dk 10 sn", "seconds":70, "factor":2.7, "fee":50},
	"long": {"name":"Uzun kontrat", "label":"4 dakika", "seconds":240, "factor":7.2, "fee":120}
}

var definitions: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			definitions = parsed

func get_building(kind: String) -> Dictionary:
	return definitions.get(kind, {})

func is_residential(kind: String) -> bool:
	return int(get_building(kind).get("residents", 0)) > 0

func category_items(category: String) -> Array[String]:
	var items: Array[String] = []
	for kind: String in ["cottage", "apartments", "villa", "office", "cafe", "park"]:
		if get_building(kind).category == category:
			items.append(kind)
	return items
