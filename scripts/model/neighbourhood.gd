class_name CityNeighbourhood
extends RefCounted
## Live outcomes, not quest points. Each resident is counted once even when
## several cafes compete for that household's spending.
static func describe(city: CityState, now: int) -> Dictionary:
	var result := {"homes":0, "capacity":0, "residents":0, "served":0, "reachable":0, "trade":0, "vacant":0, "rent":0.0, "income":0}
	var cafes: Array[int] = []
	for index in range(city.lots.size()):
		if city.lots[index].kind == "cafe" and city.is_complete(index, now):
			cafes.append(index)
			result.trade += city.business_income(index, now) * 60 / CityState.BUSINESS_CYCLE
	for home in range(city.lots.size()):
		if not city.catalog.is_residential(city.lots[home].kind) or not city.is_complete(home, now): continue
		result.homes += 1
		result.capacity += city.resident_count(home)
		if not city.is_occupied(home, now):
			result.vacant += 1
			continue
		var people := city.resident_count(home)
		var lease: Dictionary = city.lots[home].lease
		var seconds := maxi(int(lease.end) - int(lease.start), 1)
		result.rent += maxf(float(lease.amount) - float(CityCatalog.LEASES[str(lease.type)].fee), 0.0) * 60.0 / seconds
		result.residents += people
		if city.growth_economy: continue
		for cafe in cafes:
			if CityStreets.can_reach(city, home, cafe):
				result.served += people
				break
	result.reachable = result.served
	if city.growth_economy:
		var trade := city.commerce.allocate(city, now)
		result.reachable = trade.reachable
		result.served = trade.served
	result.income = roundi(result.rent) + int(result.trade)
	return result
