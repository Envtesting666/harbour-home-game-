extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	var city := CityState.new()
	var now := 1000000
	city.seed(now)
	var snapshot := city.snapshot()
	var pulse := CityNeighbourhood.describe(city, now)
	check(pulse.homes == 2 and pulse.residents == 0 and pulse.income == 0, "Ready rent is not a fictional ongoing income or occupied home")
	check(city.snapshot() == snapshot, "Dashboard cannot alter economy or progress")
	city.collect(8, now)
	city.start_lease(8, "long", now)
	pulse = CityNeighbourhood.describe(city, now)
	check(pulse.residents == city.resident_count(8) and pulse.served == 0 and pulse.income > 0, "Signed home adds actual neighbours and net lease rate, not customers without a cafe")
	city.lots[6].kind = "cafe"
	city.lots[6].build_end = now
	pulse = CityNeighbourhood.describe(city, now)
	check(pulse.served == pulse.residents and pulse.trade == city.business_income(6, now) * 2, "Reach and trade agree with actual commerce")
	city.build_street("h:3:2", now)
	city.lots[9].kind = "cafe"
	city.lots[9].build_end = now
	check(CityStreets.can_reach(city, 8, 9) and CityNeighbourhood.describe(city, now).served == pulse.served, "Competing reachable cafes cannot double count residents")
	check(CityNeighbourhood.describe(city, now + 241).residents == 0 and CityNeighbourhood.describe(city, now + 241).income == 0, "Expired leases cease current earning without deleting ready rent")
	print("NEIGHBOURHOOD_TESTS: 6 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
