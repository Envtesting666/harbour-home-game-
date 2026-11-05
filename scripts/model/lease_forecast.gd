class_name CityLeaseForecast
extends RefCounted
## Compare the same neighbourhood with and without this lease. No live mutations,
## no duplicated cafe customers, and no assumed occupancy after the term expires.

static func quote(city: CityState, index: int, type: String, now: int) -> Dictionary:
	if not city.valid_index(index) or not CityCatalog.LEASES.has(type): return {}
	var terms: Dictionary = CityCatalog.LEASES[type]
	var result := {"rent":city.rent_quote(index, type, now), "fee":int(terms.fee), "seconds":int(terms.seconds), "residents":city.resident_count(index), "local_trade":0, "cafes":0}
	result.net_rent = int(result.rent) - int(result.fee)
	if not city.is_complete(index, now) or not city.lots[index].lease.is_empty(): return result
	var before := CityState.new(city.catalog)
	var after := CityState.new(city.catalog)
	var snapshot := city.snapshot()
	if not before.restore(snapshot) or not after.restore(snapshot): return result
	if not after.start_lease(index, type, now): return result
	var finish := now + int(terms.seconds)
	before.advance(finish)
	after.advance(finish)
	var extra := 0.0
	for cafe in range(city.lots.size()):
		if city.lots[cafe].kind != "cafe": continue
		if CityStreets.can_reach(city, index, cafe) and city.is_complete(cafe, finish): result.cafes += 1
		extra += float(after.lots[cafe].business_pending) + float(after.lots[cafe].business_fraction) - float(before.lots[cafe].business_pending) - float(before.lots[cafe].business_fraction)
	result.local_trade = maxi(0, floori(extra + .00001))
	return result
