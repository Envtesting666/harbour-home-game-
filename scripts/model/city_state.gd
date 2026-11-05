class_name CityState
extends RefCounted
## Domain state. Currency, spatial economy and transactions never depend on UI.

signal changed
signal transaction(message: String, positive: bool)

const COLUMNS := 6
const ROWS := 4
const SAVE_VERSION := 6
const HOME_DESIGNS := ["veranda", "bay", "courtyard"]
const BUSINESS_CYCLE := 30
const OFFLINE_LIMIT := 8 * 3600
const EXPANSION_PRICE := 10000
const EXPANSION_LEVEL := 3

var catalog: CityCatalog
var cash := 12000
var experience := 60
var rent_collected := 0
var contracts_signed := 0
var milestone := 0
var unlocked_columns := 4
var lots: Array[Dictionary] = []
var active_project := ""
var completed_projects: Array[String] = []
var street_edges: Array[String] = []
var commerce_peak_customers := 0
var opening_stage := -1
var growth_economy := false
var commerce := CityCommerce.new()

func _init(book: CityCatalog = null) -> void:
	catalog = book if book != null else CityCatalog.new()

func seed(now: int) -> void:
	lots.clear()
	commerce_peak_customers = 0
	opening_stage = -1
	growth_economy = false
	street_edges = CityStreets.seed_edges()
	for i in range(COLUMNS * ROWS):
		lots.append({"kind":"", "level":0, "owned":false, "build_end":0, "lease":{}, "business_last":now, "business_pending":0, "business_fraction":0.0, "specialization":"neutral", "appearance":"veranda", "visual_seed":i})
	_install(7, "hq", now)
	_install(8, "cottage", now)
	_install(13, "cottage", now)
	lots[13].appearance = "bay"
	_install(14, "park", now)
	lots[8].lease = {"type":"short", "end":now - 1, "start":now - 21, "amount":350}

func seed_live(now: int) -> void:
	# A small inherited, working street. Its existing tenant is not a player
	# transaction: cash, signed-contract count and XP receive no opening reward.
	self.seed(now)
	growth_economy = true
	cash = int(catalog.get_building("cottage").price) + CityCatalog.LAND_PRICE
	experience = 60
	rent_collected = 0
	contracts_signed = 0
	milestone = 5
	unlocked_columns = 4
	active_project = ""
	completed_projects.clear()
	_install(6, "cafe", now)
	lots[8].lease = {}
	lots[13].lease = {"type":"long", "start":now, "end":now + int(CityCatalog.LEASES.long.seconds), "amount":rent_quote(13, "long", now)}
	opening_stage = 0
	_record_commerce_peak(now)

func _install(index: int, kind: String, now: int) -> void:
	lots[index] = {"kind":kind, "level":1, "owned":true, "build_end":0, "lease":{}, "business_last":now, "business_pending":0, "business_fraction":0.0, "specialization":"neutral", "appearance":"veranda", "visual_seed":index}

func level() -> int:
	return 1 + int(experience / 150)

func coordinate(index: int) -> Vector2i:
	return Vector2i(index % COLUMNS, int(index / COLUMNS))

func valid_index(index: int) -> bool:
	return index >= 0 and index < lots.size()

func accessible(index: int) -> bool:
	return valid_index(index) and coordinate(index).x < unlocked_columns

func has_frontage(index: int) -> bool:
	return CityStreets.has_frontage(self, index)

func street_error(key: String, removing: bool = false) -> String:
	if not CityStreets.valid_key(key): return "Geçerli bir sokak parçası seç."
	if removing:
		if key not in street_edges: return "Burada kaldırılacak sokak yok."
		var remaining: Array[String] = street_edges.duplicate()
		remaining.erase(key)
		# Unused disconnected stubs cannot survive removing a bridge either.
		if not CityStreets.valid_network(remaining): return "Bu bağlantı başka sokaklara erişim sağlıyor."
		var clone := CityState.new(catalog)
		clone.restore(snapshot())
		clone.street_edges = remaining
		for index in range(lots.size()):
			if lots[index].kind != "" and has_frontage(index) and not clone.has_frontage(index):
				return "Bu sokak bir binanın girişi. Kaldırmak için önce binayı taşı."
		return ""
	if key in street_edges: return "Bu sokak zaten yapılmış."
	if not CityStreets.key_within_columns(key, unlocked_columns): return "Bu bölge için genişleme izni gerekli."
	var ends := CityStreets.endpoints(key)
	var connected := CityStreets.reachable(self)
	if ends[0] not in connected and ends[1] not in connected: return "Yeni sokağı mevcut yol ağına bağla."
	if cash < CityStreets.PRICE: return "Bu sokak için nakit yetersiz."
	return ""

func build_street(key: String, now: int) -> bool:
	var error := street_error(key)
	if not error.is_empty():
		transaction.emit(error, false)
		return false
	advance(now)
	cash -= CityStreets.PRICE
	street_edges.append(key)
	_record_commerce_peak(now)
	_finish_opening(now)
	transaction.emit("Yeni sokak açıldı. Mahalle bağlantıları güncellendi.", true)
	changed.emit()
	return true

func remove_street(key: String, now: int) -> bool:
	var error := street_error(key, true)
	if not error.is_empty():
		transaction.emit(error, false)
		return false
	advance(now)
	street_edges.erase(key)
	cash += CityStreets.REFUND
	_record_commerce_peak(now)
	transaction.emit("Sokak kaldırıldı. Bedelin yarısı iade edildi.", true)
	changed.emit()
	return true

func street_quote(key: String, now: int) -> Dictionary:
	var removing := key in street_edges
	var result := {"price":CityStreets.PRICE, "refund":CityStreets.REFUND, "new_frontages":0, "customer_change":0.0, "income_change":0, "removable":street_error(key, true).is_empty() if removing else false}
	if not CityStreets.valid_key(key): return result
	var clone := CityState.new(catalog)
	if not clone.restore(snapshot()): return result
	if removing: clone.street_edges.erase(key)
	else: clone.street_edges.append(key)
	for index in range(lots.size()):
		if accessible(index) and lots[index].kind == "":
			result.new_frontages += int(clone.has_frontage(index)) - int(has_frontage(index))
		if lots[index].kind == "cafe" and is_complete(index, now):
			result.customer_change += clone.customers(index, now) - customers(index, now)
			result.income_change += clone.business_income(index, now) - business_income(index, now)
	return result

func distance(a: int, b: int) -> int:
	var difference := coordinate(a) - coordinate(b)
	return absi(difference.x) + absi(difference.y)

func is_complete(index: int, now: int) -> bool:
	return valid_index(index) and lots[index].kind != "" and int(lots[index].build_end) <= now

func park_bonus(index: int, now: int) -> float:
	var result := 0.0
	for other in range(lots.size()):
		if lots[other].kind == "park" and is_complete(other, now) and distance(index, other) <= 1:
			result += 0.12 * int(lots[other].level)
	return minf(result, 0.36)

func rent_quote(index: int, lease_type: String, now: int) -> int:
	if not valid_index(index) or not CityCatalog.LEASES.has(lease_type):
		return 0
	var lot: Dictionary = lots[index]
	var definition := catalog.get_building(lot.kind)
	var base: float = float(definition.get("base_rent", 0))
	match str(lot.get("specialization", "neutral")):
		"boutique": base *= 1.2
		"community": base *= 0.9
	return roundi(base * (1.0 + (int(lot.level) - 1) * 0.4) * (1.0 + park_bonus(index, now)) * float(CityCatalog.LEASES[lease_type].factor))

func resident_count(index: int) -> int:
	if not valid_index(index):
		return 0
	var base: int = int(catalog.get_building(lots[index].kind).get("residents", 0))
	var specialization: String = str(lots[index].get("specialization", "neutral"))
	if specialization == "boutique":
		return maxi(1, roundi(base * 0.75)) if base > 0 else 0
	if specialization == "community":
		return roundi(base * 1.5)
	return base

func customers(index: int, now: int) -> float:
	if not valid_index(index) or lots[index].kind != "cafe" or not is_complete(index, now):
		return 0.0
	if growth_economy: return float(commerce.allocate(self, now).counts.get(index, 0))
	return _customer_share(index, now, false)

func cafe_capacity(index: int) -> int:
	return CityCommerce.SEATS_PER_LEVEL * int(lots[index].level)

func projected_customers(index: int, now: int) -> float:
	if not accessible(index) or lots[index].kind != "":
		return 0.0
	var complete := now + int(catalog.get_building("cafe").build_seconds)
	if growth_economy: return float(commerce.allocate(self, complete, index).counts.get(index, 0))
	return _customer_share(index, complete, true)

func _customer_share(index: int, now: int, hypothetical: bool) -> float:
	var total := 0.0
	for home in range(lots.size()):
		var definition := catalog.get_building(lots[home].kind)
		if int(definition.get("residents", 0)) <= 0 or not is_occupied(home, now) or not is_complete(home, now) or not CityStreets.can_reach(self, home, index):
			continue
		var competing_cafes := 1 if hypothetical else 0
		for other in range(lots.size()):
			if lots[other].kind == "cafe" and is_complete(other, now) and CityStreets.can_reach(self, home, other):
				competing_cafes += 1
		total += float(resident_count(home)) / float(maxi(competing_cafes, 1))
	return total

func is_occupied(index: int, now: int) -> bool:
	if not valid_index(index) or lots[index].lease.is_empty(): return false
	return int(lots[index].lease.start) <= now and now < int(lots[index].lease.end)

func business_income(index: int, now: int) -> int:
	return _business_income_for(customers(index, now), int(lots[index].level)) if valid_index(index) else 0

func _business_income_for(count: float, cafe_level: int) -> int:
	var rate: float = float(catalog.get_building("cafe").get("customer_income", 62))
	return roundi(minf(count, 40.0) * rate * (1.0 + (cafe_level - 1) * 0.35))

func cafe_projection(index: int, now: int) -> Dictionary:
	var result := {"customers":0.0, "income":0, "district_change":0}
	if not accessible(index) or lots[index].kind != "":
		return result
	var forecast_time := now + int(catalog.get_building("cafe").build_seconds)
	if growth_economy:
		var base: Dictionary = commerce.allocate(self, forecast_time).counts
		var future: Dictionary = commerce.allocate(self, forecast_time, index).counts
		result.customers = float(future.get(index, 0))
		result.income = _business_income_for(result.customers, 1)
		result.district_change = result.income
		for cafe: int in base:
			var cafe_level := int(lots[cafe].level)
			result.district_change += _business_income_for(float(future.get(cafe, 0)), cafe_level) - _business_income_for(float(base[cafe]), cafe_level)
		return result
	result.customers = projected_customers(index, now)
	var rate: float = float(catalog.get_building("cafe").get("customer_income", 62))
	result.income = roundi(minf(float(result.customers), 40.0) * rate)
	var before := 0
	var after: int = result.income
	for cafe in range(lots.size()):
		if lots[cafe].kind != "cafe" or not is_complete(cafe, forecast_time):
			continue
		before += business_income(cafe, forecast_time)
		var future_customers := 0.0
		for home in range(lots.size()):
			if resident_count(home) <= 0 or not is_occupied(home, forecast_time) or not is_complete(home, forecast_time) or not CityStreets.can_reach(self, home, cafe):
				continue
			var competitors := 1 if CityStreets.can_reach(self, home, index) else 0
			for other in range(lots.size()):
				if lots[other].kind == "cafe" and is_complete(other, forecast_time) and CityStreets.can_reach(self, home, other):
					competitors += 1
			future_customers += float(resident_count(home)) / maxi(competitors, 1)
		after += roundi(minf(future_customers, 40.0) * rate * (1.0 + (int(lots[cafe].level) - 1) * 0.35))
	result.district_change = after - before
	return result

func park_projection(index: int, now: int) -> int:
	if not accessible(index) or lots[index].kind != "":
		return 0
	var affected := 0
	for home in range(lots.size()):
		if catalog.is_residential(lots[home].kind) and is_complete(home, now) and distance(index, home) <= 1 and park_bonus(home, now) < 0.359:
			affected += 1
	return affected

func net_worth() -> int:
	var result := cash
	for lot: Dictionary in lots:
		if lot.kind != "":
			result += roundi(float(catalog.get_building(lot.kind).value) * (1.0 + (int(lot.level) - 1) * 0.5))
	return result

func build_price(index: int, kind: String) -> int:
	if not valid_index(index) or not catalog.definitions.has(kind):
		return 0
	return int(catalog.get_building(kind).price) + (0 if bool(lots[index].owned) else CityCatalog.LAND_PRICE)

func build_error(index: int, kind: String) -> String:
	if not accessible(index):
		return "Bu bölge için genişleme izni gerekli."
	if kind in ["hq", "construction"] or not catalog.definitions.has(kind):
		return "Bu yapı inşa edilemiyor."
	if lots[index].kind != "":
		return "Bu parsel dolu. Boş bir arsa seç."
	if level() < int(catalog.get_building(kind).unlock_level):
		return "Önce şirket seviyeni yükselt."
	if not has_frontage(index):
		return "Önce bu parsele bağlı bir sokak kur."
	if cash < build_price(index, kind):
		return "Bu yatırım için yeterli nakit yok."
	return ""

func build(index: int, kind: String, now: int, appearance: String = "veranda") -> bool:
	if appearance not in HOME_DESIGNS:
		return false
	var error := build_error(index, kind)
	if not error.is_empty():
		transaction.emit(error, false)
		return false
	advance(now)
	var price := build_price(index, kind)
	cash -= price
	_install(index, kind, now)
	lots[index].appearance = appearance if kind == "cottage" else "veranda"
	lots[index].build_end = now + int(catalog.get_building(kind).build_seconds)
	lots[index].business_last = lots[index].build_end
	experience += 25
	transaction.emit(CityLocale.f("{0} inşaatı başladı.", [CityLocale.t(catalog.get_building(kind).name)]), true)
	changed.emit()
	return true

func start_lease(index: int, lease_type: String, now: int) -> bool:
	if not is_complete(index, now) or not CityCatalog.LEASES.has(lease_type):
		return false
	if not has_frontage(index):
		transaction.emit("Önce bu parsele bağlı bir sokak kur.", false)
		return false
	var lot: Dictionary = lots[index]
	if not catalog.is_residential(lot.kind) or not lot.lease.is_empty():
		return false
	var terms: Dictionary = CityCatalog.LEASES[lease_type]
	if cash < int(terms.fee):
		transaction.emit("Kontrat gideri için nakit yetersiz. Kısa kontrat ücretsiz.", false)
		return false
	advance(now)
	cash -= int(terms.fee)
	lot.lease = {"type":lease_type, "start":now, "end":now + int(terms.seconds), "amount":rent_quote(index, lease_type, now)}
	contracts_signed += 1
	if opening_stage == 0: opening_stage = 1
	_record_commerce_peak(now)
	transaction.emit("Kontrat imzalandı. Kiran hazır olduğunda bekler.", true)
	changed.emit()
	return true

func collectible(index: int, now: int) -> int:
	if not is_complete(index, now):
		return 0
	var lot: Dictionary = lots[index]
	if lot.kind == "cafe":
		return int(lot.business_pending)
	if not lot.lease.is_empty() and int(lot.lease.end) <= now:
		return int(lot.lease.amount)
	return 0

func collect(index: int, now: int) -> int:
	advance(now)
	var amount := collectible(index, now)
	if amount <= 0:
		return 0
	var lot: Dictionary = lots[index]
	if lot.kind == "cafe":
		lot.business_pending = 0
		if opening_stage == 1:
			opening_stage = 2
			_finish_opening(now)
	else:
		# Rank follows completed occupancy time, not how often rent is clicked.
		experience += int(CityCatalog.LEASES[str(lot.lease.type)].seconds) / 5
		lot.lease = {}
		rent_collected += amount
	cash += amount
	transaction.emit(CityLocale.f("+{0} tahsil edildi.", [CityLocale.money(amount)]), true)
	changed.emit()
	return amount

func upgrade_price(index: int) -> int:
	if not valid_index(index) or lots[index].kind == "":
		return 0
	return roundi(float(catalog.get_building(lots[index].kind).price) * 0.65 * int(lots[index].level))

func upgrade(index: int, now: int, specialization: String = "boutique") -> bool:
	if not is_complete(index, now):
		return false
	var lot: Dictionary = lots[index]
	if lot.kind in ["hq", "construction"] or int(lot.level) >= 3:
		return false
	if not lot.lease.is_empty():
		transaction.emit("Yenileme için mevcut kontratın tahsil edilmesini bekle.", false)
		return false
	if specialization not in ["boutique", "community"]:
		return false
	var price := upgrade_price(index)
	if cash < price:
		transaction.emit("Yenileme için nakit yetersiz.", false)
		return false
	advance(now)
	cash -= price
	if int(lot.level) == 1 and catalog.is_residential(lot.kind):
		lot.specialization = specialization
	lot.level = int(lot.level) + 1
	lot.build_end = now + 6
	lot.business_last = now + 6
	_record_commerce_peak(now)
	experience += 35
	transaction.emit("Yenileme başladı. Binanın geliri artacak.", true)
	changed.emit()
	return true

func move_building(source: int, target: int, now: int) -> bool:
	if not accessible(source) or not accessible(target) or not is_complete(source, now):
		return false
	if lots[target].kind != "" or lots[source].kind == "hq":
		transaction.emit("Bina için boş bir parsel seç.", false)
		return false
	if not has_frontage(target):
		transaction.emit("Önce bu parsele bağlı bir sokak kur.", false)
		return false
	var land_price := 0 if bool(lots[target].owned) else CityCatalog.LAND_PRICE
	if cash < land_price:
		transaction.emit("Yeni parsel için 600 $ arsa bedeli gerekli.", false)
		return false
	advance(now)
	cash -= land_price
	var previous: Dictionary = lots[target].duplicate(true)
	lots[target] = lots[source].duplicate(true)
	lots[source] = previous
	lots[source].owned = true
	lots[target].owned = true
	_record_commerce_peak(now)
	transaction.emit("Bina taşındı. Mahalle etkileri yeniden hesaplandı.", true)
	changed.emit()
	return true

func advance(now: int) -> void:
	for index in range(lots.size()):
		var lot: Dictionary = lots[index]
		if lot.kind != "cafe" or not is_complete(index, now):
			continue
		var start := maxi(int(lot.business_last), int(lot.build_end))
		if start >= now: continue
		var paid_start := maxi(start, now - OFFLINE_LIMIT)
		# Integrate only occupied intervals. Expiry and competitors completing a build
		# are change points; a late/offline update earns the same as frequent updates.
		var points: Array[int] = [start, now]
		if paid_start > start: points.append(paid_start)
		for home: Dictionary in lots:
			if not home.lease.is_empty():
				for event in [int(home.lease.start), int(home.lease.end)]:
					if event > start and event < now and event not in points: points.append(event)
			if home.kind == "cafe":
				var complete := int(home.build_end)
				if complete > start and complete < now and complete not in points: points.append(complete)
		points.sort()
		var earned: float = float(lot.get("business_fraction", 0.0))
		for segment in range(points.size() - 1):
			# A demonstrated opening remains earned even if its leases later expire.
			# Historical proof uses the same intervals; only money has the offline cap.
			_observe_commerce_count(customers(index, points[segment]))
			var paid_seconds := maxi(0, points[segment + 1] - maxi(points[segment], paid_start))
			earned += float(business_income(index, points[segment])) * float(paid_seconds) / BUSINESS_CYCLE
		var whole := floori(earned + 0.0000001)
		lot.business_pending = int(lot.business_pending) + whole
		lot.business_fraction = maxf(0, earned - whole)
		lot.business_last = now
	_record_commerce_peak(now)
	# Automatic accrual is read by the clock UI and the periodic save. It does not
	# rebuild every open panel or write a save on every earned unit of currency.
	_finish_opening(now)

func _finish_opening(now: int) -> void:
	if opening_stage != 2: return
	if not growth_economy and street_edges.size() <= CityStreets.seed_edges().size(): return
	var homes := 0
	var parks := 0
	var cafes := 0
	for index in range(lots.size()):
		if not is_complete(index, now): continue
		var lot := lots[index]
		if catalog.is_residential(lot.kind): homes += 1
		if lot.kind == "park": parks += 1
		if lot.kind == "cafe": cafes += 1
		if growth_economy and int(lot.level) >= 2:
			opening_stage = -1
			return
	if homes >= 3 or (growth_economy and (parks >= 2 or cafes >= 2)): opening_stage = -1

func _observe_commerce_count(value: float) -> void:
	commerce_peak_customers = maxi(commerce_peak_customers, mini(8, floori(value)))

func _record_commerce_peak(now: int) -> void:
	for index in range(lots.size()):
		if lots[index].kind == "cafe" and is_complete(index, now):
			_observe_commerce_count(customers(index, now))

func count_kind(category: String) -> int:
	var result := 0
	for lot: Dictionary in lots:
		if lot.kind != "" and catalog.get_building(lot.kind).category == category:
			result += 1
	return result

func objective(now: int) -> Dictionary:
	match milestone:
		0:
			return {"name":"İlk kiranı topla", "detail":"Hazır kiranın olduğu eve dokun.", "progress":mini(rent_collected, 1), "target":1, "reward":700}
		1:
			var street_step := mini(maxi(street_edges.size() - CityStreets.seed_edges().size(), 0), 1)
			return {"name":"İlk sokağını büyüt", "detail":"Yeni bir sokak bağla ve üç konutluk bir mahalle kur.", "progress":mini(count_kind("Konut"), 3) + street_step, "target":4, "reward":1600}
		2:
			return {"name":"İlk işletmeni canlandır", "detail":"Kiracılara yakın bir kafede 8 müşteri sağla.", "progress":commerce_peak_customers, "target":8, "reward":2500}
		3:
			return {"name":"Mahallene değer kat", "detail":"Bir binayı ikinci seviyeye yenile.", "progress":lots.filter(func(lot: Dictionary) -> bool: return int(lot.level) >= 2).size(), "target":1, "reward":3000}
		4:
			return {"name":"Yeni bölgeye büyü", "detail":"Şirket seviyesi 3 · 10.000 $ genişleme bütçesi", "progress":1 if unlocked_columns == COLUMNS else 0, "target":1, "reward":4000}
		_:
			return CityProjects.objective(self, now)

func claim_objective(now: int) -> bool:
	advance(now)
	if opening_stage >= 0: return false
	if milestone >= 5:
		return _claim_project(now)
	var target := objective(now)
	if int(target.progress) < int(target.target) or milestone > 4:
		return false
	cash += int(target.reward)
	experience += 80
	milestone += 1
	transaction.emit(CityLocale.f("Mahalle projesi tamamlandı. +{0}", [CityLocale.money(int(target.reward))]), true)
	changed.emit()
	return true

func choose_project(id: String) -> bool:
	if milestone < 5 or not CityProjects.DEFINITIONS.has(id) or id in completed_projects:
		return false
	active_project = id
	changed.emit()
	return true

func _claim_project(now: int) -> bool:
	if active_project.is_empty() or active_project in completed_projects:
		return false
	var goal := CityProjects.objective(self, now)
	if int(goal.progress) < int(goal.target): return false
	completed_projects.append(active_project)
	active_project = ""
	cash += int(goal.reward)
	experience += 120
	transaction.emit(CityLocale.f("Mahalle projesi tamamlandı. +{0}", [CityLocale.money(int(goal.reward))]), true)
	changed.emit()
	return true

func can_claim_objective(now: int) -> bool:
	if opening_stage >= 0: return false
	var goal := objective(now)
	return int(goal.reward) > 0 and int(goal.progress) >= int(goal.target)

func needs_project() -> bool:
	return milestone >= 5 and active_project.is_empty() and completed_projects.size() < CityProjects.DEFINITIONS.size()

func expand() -> bool:
	if unlocked_columns == COLUMNS or level() < EXPANSION_LEVEL or cash < EXPANSION_PRICE:
		transaction.emit("Genişleme: şirket seviyesi 3 ve 10.000 $ gerekli.", false)
		return false
	cash -= EXPANSION_PRICE
	unlocked_columns = COLUMNS
	experience += 80
	transaction.emit("Yeni bölge açıldı. Sekiz yeni parsel senin!", true)
	changed.emit()
	return true

func snapshot() -> Dictionary:
	return {"version":SAVE_VERSION, "cash":cash, "experience":experience, "rent_collected":rent_collected, "contracts_signed":contracts_signed, "milestone":milestone, "unlocked_columns":unlocked_columns, "lots":lots.duplicate(true), "active_project":active_project, "completed_projects":completed_projects.duplicate(), "street_edges":street_edges.duplicate(), "commerce_peak_customers":commerce_peak_customers, "opening_stage":opening_stage, "growth_economy":growth_economy}

func restore(data: Dictionary) -> bool:
	# Validate the whole snapshot before replacing any live state.
	if int(data.get("version", -1)) not in [1, 2, 3, 4, 5, SAVE_VERSION] or not data.get("lots") is Array:
		return false
	if data.lots.size() != COLUMNS * ROWS:
		return false
	var streets: Variant = data.get("street_edges", CityStreets.all_edges() if int(data.version) < 5 else null)
	if not streets is Array or not CityStreets.valid_network(streets): return false
	var peak: Variant = data.get("commerce_peak_customers", 0 if int(data.version) < 6 else null)
	if typeof(peak) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(peak)) or float(peak) != floorf(float(peak)) or float(peak) < 0 or float(peak) > 8: return false
	var opening: Variant = data.get("opening_stage", -1)
	if typeof(opening) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(opening)) or float(opening) != floorf(float(opening)) or int(opening) not in [-1, 0, 1, 2]: return false
	var growth: Variant = data.get("growth_economy", false)
	if not growth is bool: return false
	var completed: Variant = data.get("completed_projects", [])
	var active: String = str(data.get("active_project", ""))
	if not completed is Array or (not active.is_empty() and not CityProjects.DEFINITIONS.has(active)):
		return false
	var seen: Array = []
	for id: Variant in completed:
		if not id is String or not CityProjects.DEFINITIONS.has(id) or id in seen or id == active:
			return false
		seen.append(id)
	for field: String in ["cash", "experience", "rent_collected", "contracts_signed", "milestone"]:
		if not data.get(field) is float and not data.get(field) is int:
			return false
		if float(data[field]) < 0 or float(data[field]) > 1000000000000.0:
			return false
	if int(data.get("unlocked_columns", 0)) not in [4, 6]:
		return false
	for item: Variant in data.lots:
		if not item is Dictionary or not item.get("kind") is String:
			return false
		if item.kind != "" and not catalog.definitions.has(item.kind):
			return false
		if not item.get("level") is float and not item.get("level") is int:
			return false
		if int(item.level) < 0 or int(item.level) > 3 or not item.get("lease") is Dictionary:
			return false
		if str(item.get("specialization", "neutral")) not in ["neutral", "boutique", "community"]:
			return false
		if str(item.get("appearance", "veranda")) not in HOME_DESIGNS:
			return false
		var visual: Variant = item.get("visual_seed", 0)
		if typeof(visual) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(visual)) or float(visual) != floorf(float(visual)) or float(visual) < 0 or float(visual) >= COLUMNS * ROWS: return false
		for field: String in ["build_end", "business_last", "business_pending"]:
			if not item.get(field) is float and not item.get(field) is int:
				return false
		if int(item.business_pending) < 0:
			return false
		var fraction: float = float(item.get("business_fraction", 0.0))
		if not is_finite(fraction) or fraction < 0 or fraction >= 1: return false
		if not item.lease.is_empty():
			if not CityCatalog.LEASES.has(item.lease.get("type", "")):
				return false
			for field: String in ["start", "end", "amount"]:
				if not item.lease.get(field) is float and not item.lease.get(field) is int:
					return false
			if int(item.lease.amount) <= 0:
				return false
	cash = int(data.cash)
	experience = int(data.experience)
	rent_collected = int(data.rent_collected)
	contracts_signed = int(data.contracts_signed)
	milestone = int(data.milestone)
	unlocked_columns = int(data.unlocked_columns)
	active_project = active
	completed_projects.assign(completed)
	street_edges.assign(streets)
	commerce_peak_customers = int(peak)
	opening_stage = int(opening)
	growth_economy = growth
	lots.clear()
	for lot: Dictionary in data.lots:
		var restored_lot := lot.duplicate(true)
		restored_lot.specialization = str(lot.get("specialization", "neutral"))
		restored_lot.appearance = str(lot.get("appearance", HOME_DESIGNS[lots.size() % 3] if lot.kind == "cottage" else "veranda"))
		restored_lot.business_fraction = float(lot.get("business_fraction", 0.0))
		restored_lot.visual_seed = int(lot.get("visual_seed", lots.size()))
		lots.append(restored_lot)
	return true
