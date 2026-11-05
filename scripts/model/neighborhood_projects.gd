class_name CityProjects
extends RefCounted
## Long-term directions reward different neighbourhood layouts; each pays once.

const DEFINITIONS := {
	"garden":{"name":"Bahçe mahallesi", "detail":"Park bonusu olan dört tamamlanmış konut oluştur.", "target":4, "reward":6500},
	"commerce":{"name":"Ticaret sokağı", "detail":"Kafelerden yararlanan 24 farklı kiracıya ulaş.", "target":24, "reward":7000},
	"prestige":{"name":"Seçkin adresler", "detail":"Üç konutu butik planda ikinci seviyeye yenile.", "target":3, "reward":6500}
}

static func progress(city, id: String, now: int) -> int:
	if id == "commerce" and city.growth_economy:
		return int(city.commerce.allocate(city, now).served)
	var result := 0
	for index in range(city.lots.size()):
		if not city.catalog.is_residential(city.lots[index].kind) or not city.is_complete(index, now): continue
		match id:
			"garden":
				if city.park_bonus(index, now) > 0: result += 1
			"prestige":
				if int(city.lots[index].level) >= 2 and city.lots[index].get("specialization", "neutral") == "boutique": result += 1
			"commerce":
				if not city.is_occupied(index, now): continue
				for cafe in range(city.lots.size()):
					if city.lots[cafe].kind == "cafe" and city.is_complete(cafe, now) and CityStreets.can_reach(city, index, cafe):
						result += city.resident_count(index)
						break
	return result

static func objective(city, now: int) -> Dictionary:
	if city.active_project.is_empty():
		return {"name":"Yeni bir proje seç." if city.completed_projects.size() < DEFINITIONS.size() else "Tüm mahalle projeleri tamamlandı.", "detail":"Yeni proje seçmek için merkezine veya bu düğmeye dokun." if city.completed_projects.size() < DEFINITIONS.size() else "Yeni evler ve işletmelerle kendi hedefini belirle.", "progress":0, "target":1, "reward":0}
	var data: Dictionary = DEFINITIONS[city.active_project].duplicate()
	data.progress = mini(progress(city, city.active_project, now), int(data.target))
	return data
