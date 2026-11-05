class_name CityJourney
extends RefCounted
## Read-only first-session guidance. Describes real city conditions and a useful
## next action; completing a hint never awards money or bypasses construction.

static func describe(city: CityState, now: int) -> Dictionary:
	var goal := city.objective(now)
	var result := {"title":goal.name, "detail":goal.detail, "checks":[], "action":"objective", "value":"", "label":"See your goal", "target":7}
	if city.opening_stage == 0:
		result.title = "Welcome your first family"
		result.detail = "Fill an empty home. Its neighbours will bring local trade to your cafe."
		var vacant := _vacant_home(city, now)
		result.action = "guide_home" if vacant >= 0 else "guide_build"
		result.target = vacant if vacant >= 0 else 7
		result.value = "cottage"
		result.label = "Welcome your first family" if vacant >= 0 else "Make room for a family"
		return result
	if city.opening_stage == 1:
		var cafe := _cafe(city)
		result.title = "Collect local trade"
		result.detail = "Your neighbours shop at the cafe. Collect its real earnings to reinvest in your street."
		result.action = "guide_home" if cafe >= 0 else "catalog"
		result.target = cafe if cafe >= 0 else 7
		result.label = "Collect local trade" if cafe >= 0 and city.collectible(cafe, now) > 0 else "Visit your cafe"
		return result
	if city.growth_economy and city.opening_stage == 2:
		result.title = "Choose your first investment"
		result.detail = "Build a home, expand your cafe or invest in better rents."
		result.action = "investments"
		result.label = "Compare investments"
		return result
	match city.milestone:
		0:
			result.detail = "This street is yours. Collect the rent waiting at a home to fund your first change."
			result.checks = [_check(city.rent_collected > 0, "Collect rent from a home")]
			result.action = "guide_home"
			result.target = _home(city, now, true)
			result.label = "Show the rent-ready home"
		1:
			var street_done := city.street_edges.size() > CityStreets.seed_edges().size()
			var homes := city.count_kind("Konut")
			if city.opening_stage == 2:
				homes = 0
				for index in range(city.lots.size()):
					if city.catalog.is_residential(city.lots[index].kind) and city.is_complete(index, now): homes += 1
			result.detail = "Give your street room to grow. New homes bring neighbours for future shops."
			result.checks = [_check(street_done, "Connect a new street"), ("✓ " if homes >= 3 else "○ ") + CityLocale.f("Homes {0}/3", [mini(homes, 3)])]
			result.action = "guide_build" if street_done else "streets"
			result.value = "cottage"
			result.label = "Choose your third home" if street_done else "Extend your street"
		2:
			var site := cafe_site(city, now)
			var cafe := _cafe(city)
			result.detail = "Open a cafe, then welcome its neighbours. Long leases give you time to shape the street."
			var ready := 0
			var route := cafe if cafe >= 0 else site
			for index in range(city.lots.size()):
				if city.is_occupied(index, now) and route >= 0 and CityStreets.can_reach(city, index, route): ready += city.resident_count(index)
			var neighbours := CityLocale.f("Neighbours served {0}/8", [city.commerce_peak_customers]) if city.commerce_peak_customers >= 8 else CityLocale.f("Neighbours ready {0}/8", [mini(ready, 8)])
			result.checks = [_check(cafe >= 0 and city.is_complete(cafe, now), "Open a connected cafe"), ("✓ " if city.commerce_peak_customers >= 8 else "○ ") + neighbours]
			var home := _home(city, now, false, cafe if cafe >= 0 else site)
			if cafe < 0 and site >= 0:
				result.action = "guide_cafe"
				result.target = site
				result.label = "Preview a cafe site"
			elif home >= 0:
				result.action = "guide_home"
				result.target = home
				result.label = "Welcome more neighbours" if city.collectible(home, now) == 0 else "Collect and renew a home"
			elif cafe >= 0:
				result.action = "guide_home"
				result.target = cafe
				result.label = "Visit your cafe"
			else:
				result.action = "streets"
				result.label = "Connect homes with a shorter route"
		3:
			result.detail = "Give a home a role: boutique rent or a lively street with more neighbours."
			result.action = "guide_renovate"
			result.target = _renovation(city, now)
			result.label = "Choose a renovation"
		4:
			result.detail = "Save for the next district. Opening it gives you eight more plots to shape."
			result.checks = [_check(city.level() >= 3, "Reach company level 3"), _check(city.cash >= 10000, "Save $10,000 for expansion")]
			result.action = "guide_home"
			result.target = 7 if city.cash >= 10000 else _home(city, now, true)
			result.label = "Open the next district" if city.cash >= 10000 else "Manage your next income"
		_:
			if city.needs_project():
				result.detail = "Choose what this neighbourhood should become. Each direction asks for a different layout."
				result.action = "projects"
				result.label = "Choose a neighbourhood direction"
				var vacant := _vacant_home(city, now)
				if city.growth_economy and city.contracts_signed == 1 and city.count_kind("Konut") >= 3 and vacant >= 0:
					result.action = "guide_lease"
					result.target = vacant
					result.label = "Welcome another family"
			elif city.active_project == "garden":
				result.action = "guide_build"
				result.value = "park"
				result.label = "Plan a neighbourhood garden"
			elif city.active_project == "commerce":
				result.action = "guide_home"
				result.target = _home(city, now, false)
				result.label = "Welcome more neighbours"
				if city.growth_economy:
					var trade := city.commerce.allocate(city, now)
					if int(trade.reachable) > int(trade.served):
						for cafe: int in trade.counts:
							if int(trade.counts[cafe]) == city.cafe_capacity(cafe) and int(city.lots[cafe].level) < 3:
								result.target = cafe
								result.label = "Make room for more customers"
								break
					if int(result.target) < 0:
						result.action = "guide_build"
						result.value = "cottage"
						result.label = "Make room for another home"
			elif city.active_project == "prestige":
				result.action = "guide_renovate"
				result.target = _renovation(city, now)
				result.label = "Plan a boutique renovation"
			else:
				result.detail = "The first district's projects are complete. You can keep shaping this neighbourhood."
				result.action = "catalog"
				result.label = "Shape your neighbourhood"
	if city.can_claim_objective(now):
		result.action = "claim"
		result.label = CityLocale.f("Claim {0} · next chapter", [CityLocale.money(int(goal.reward))])
	elif city.growth_economy and city.unlocked_columns < CityState.COLUMNS and city.level() >= CityState.EXPANSION_LEVEL and city.cash >= CityState.EXPANSION_PRICE:
		result.title = "A new district is within reach"
		result.action = "guide_home"
		result.target = 7
		result.label = "See the next district"
	return result

static func investment_site(city: CityState, kind: String, now: int) -> Dictionary:
	var best := {"index":-1, "price":0, "road":0, "score":-INF}
	var network := CityState.new(city.catalog)
	network.restore(city.snapshot())
	var cafe := _cafe(city)
	var reachable := CityStreets.reachable(city)
	for index in range(city.lots.size()):
		if not city.accessible(index) or not city.lots[index].kind.is_empty(): continue
		var road := 0
		var frontage := CityStreets.frontage(index)
		if not city.has_frontage(index):
			var ends := CityStreets.endpoints(frontage)
			if ends[0] not in reachable and ends[1] not in reachable: continue
			road = CityStreets.PRICE
		var price := city.build_price(index, kind) + road
		var benefit := city.park_projection(index, now) if kind == "park" else roundi(city.park_bonus(index, now) * 10)
		if kind == "cottage" and cafe >= 0:
			# The suggested home should participate in the local economy. Players
			# can still choose a higher-rent site or develop a different street.
			if road > 0: network.street_edges.append(frontage)
			if CityStreets.can_reach(network, index, cafe): benefit += 2
			if road > 0: network.street_edges.pop_back()
		var score := 1000 * benefit - price
		if score > float(best.score):
			best = {"index":index, "price":price, "road":road, "score":score}
	return best

static func _vacant_home(city: CityState, now: int) -> int:
	if city.valid_index(8) and city.catalog.is_residential(city.lots[8].kind) and city.is_complete(8, now) and city.lots[8].lease.is_empty() and city.has_frontage(8): return 8
	for index in range(city.lots.size()):
		if city.catalog.is_residential(city.lots[index].kind) and city.is_complete(index, now) and city.lots[index].lease.is_empty() and city.has_frontage(index): return index
	return -1

static func _check(done: bool, text: String) -> String:
	return ("✓ " if done else "○ ") + CityLocale.t(text)

static func _home(city: CityState, now: int, ready_first: bool, near: int = -1) -> int:
	var vacant := -1
	var any_home := -1
	var ready := -1
	for index in range(city.lots.size()):
		if not city.catalog.is_residential(city.lots[index].kind) or not city.is_complete(index, now): continue
		if near >= 0 and not CityStreets.can_reach(city, index, near): continue
		any_home = index
		if city.collectible(index, now) > 0 and ready_first: return index
		if city.collectible(index, now) > 0: ready = index
		if city.lots[index].lease.is_empty(): vacant = index
	if vacant >= 0: return vacant
	if ready >= 0: return ready
	return any_home if ready_first else -1

static func _cafe(city: CityState) -> int:
	for index in range(city.lots.size()):
		if city.lots[index].kind == "cafe": return index
	return -1

static func cafe_site(city: CityState, now: int) -> int:
	var best := -1
	var most := 0
	for plot in range(city.lots.size()):
		if not city.accessible(plot) or not city.lots[plot].kind.is_empty() or not city.has_frontage(plot): continue
		var count := 0
		for home in range(city.lots.size()):
			if city.catalog.is_residential(city.lots[home].kind) and city.is_complete(home, now) and CityStreets.can_reach(city, home, plot): count += city.resident_count(home)
		if count >= 8 and count > most:
			best = plot
			most = count
	return best

static func _renovation(city: CityState, now: int) -> int:
	for index in range(city.lots.size()):
		if city.catalog.is_residential(city.lots[index].kind) and city.is_complete(index, now) and int(city.lots[index].level) == 1 and city.lots[index].lease.is_empty(): return index
	return _home(city, now, true)
