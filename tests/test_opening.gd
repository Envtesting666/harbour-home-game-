extends SceneTree

var failures := 0
var checks := 0
const NOW := 1000000

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func live() -> CityState:
	var city := CityState.new()
	city.seed_live(NOW)
	return city

func _initialize() -> void:
	CityLocale.set_language("en")
	var city := live()
	check(city.cash == 2400 and city.experience == 60 and city.contracts_signed == 0 and city.rent_collected == 0, "Opening cash buys one cottage and its land, with no invented player transactions")
	check(city.milestone == 5 and city.growth_economy and city.opening_stage == 0, "New economy bypasses linear cash rewards")
	check(city.lots[6].kind == "cafe" and city.lots[6].owned and city.is_complete(6, NOW), "Inherited cafe is real, owned and complete")
	check(city.lots[8].lease.is_empty() and city.is_occupied(13, NOW) and city.lots[13].lease.type == "long", "One vacant home and one actual long-lease household exist")
	check(int(city.lots[13].lease.amount) == city.rent_quote(13, "long", NOW) and int(city.lots[13].lease.end) == NOW + 240, "Inherited lease uses the real rent quote and finite occupancy duration")
	check(city.customers(6, NOW) == 4 and city.collectible(6, NOW) == 0 and city.collectible(13, NOW) == 0, "Initial four customers create no fictional ready trade or early rent")
	var before := city.snapshot()
	var guide := CityJourney.describe(city, NOW)
	check(guide.action == "guide_home" and guide.target == 8 and guide.label == "Welcome your first family" and city.snapshot() == before, "First action points directly to the real vacant home without mutating state")
	check(not city.can_claim_objective(NOW) and not city.claim_objective(NOW) and city.cash == 2400 and city.experience == 60, "Opening cannot claim an unearned legacy milestone")
	var initial := CityNeighbourhood.describe(city, NOW)
	var expected_rent := (float(city.lots[13].lease.amount) - float(CityCatalog.LEASES.long.fee)) / 4.0
	check(initial.residents == 4 and initial.served == 4 and initial.rent == expected_rent and initial.income == roundi(expected_rent) + city.business_income(6, NOW) * 2, "Initial economic summary uses actual net rent and live four-customer trade")
	check(city.start_lease(8, "long", NOW) and city.opening_stage == 1, "A successful real lease advances the first opening action")
	check(city.cash == 2280 and city.experience == 60 and city.contracts_signed == 1, "First family charges its real fee and gives no click XP")
	check(city.customers(6, NOW) == 8 and city.commerce_peak_customers == 8, "A signed household changes the existing cafe from four to eight actual customers")
	var full := CityNeighbourhood.describe(city, NOW)
	check(full.residents == 8 and full.served == 8 and full.income > initial.income and full.trade == city.business_income(6, NOW) * 2, "Live income and neighbours reflect both actual households")
	guide = CityJourney.describe(city, NOW)
	check(guide.action == "guide_home" and guide.target == 6 and guide.label == "Visit your cafe", "Cafe can be visited while no whole trade currency has accrued")
	check(city.collect(6, NOW) == 0 and city.opening_stage == 1 and city.cash == 2280, "An immediate empty collection gives no fake money or tutorial success")
	var expected_trade := floori(float(city.business_income(6, NOW)) * 5.0 / CityState.BUSINESS_CYCLE)
	city.advance(NOW + 5)
	check(city.collectible(6, NOW + 5) == expected_trade and expected_trade > 0, "Cafe earnings accrue only for actual elapsed occupied time")
	guide = CityJourney.describe(city, NOW + 5)
	check(guide.label == "Collect local trade" and guide.target == 6, "Accrued trade is the direct next action")
	var paid := city.collect(6, NOW + 5)
	check(paid == expected_trade and city.cash == 2280 + expected_trade and city.opening_stage == 2 and city.experience == 60, "Only real cafe earnings advance the opening; no extra cash or XP is granted")
	check(city.collect(6, NOW + 5) == 0, "A repeated collection cannot repeat trade or opening rewards")
	check(CityJourney.describe(city, NOW + 5).action == "investments", "The first collection opens a choice of investments")
	var site := CityJourney.investment_site(city, "cottage", NOW + 5)
	check(int(site.road) == 180 and int(site.price) == 2580 and city.cash < int(site.price), "A real house plan includes the new street and exceeds early cash")
	city.collect(6, NOW + 20)
	check(city.build_street("h:3:2", NOW + 20) and city.build(9, "cottage", NOW + 20), "Earned trade funds the third home through normal transactions")
	check(city.opening_stage == 2 and not city.can_claim_objective(NOW + 20) and not city.claim_objective(NOW + 20), "A third home under construction does not count")
	city.advance(NOW + 27)
	check(city.opening_stage == 2, "One second before completion the opening remains active")
	var pre_finish_cash := city.cash
	city.advance(NOW + 28)
	check(city.opening_stage == -1 and not city.can_claim_objective(NOW + 28) and city.experience == 85 and city.cash == pre_finish_cash, "Completed home ends guidance without handing out cash")
	check(city.needs_project() and city.choose_project("garden") and city.choose_project("commerce"), "District directions are optional and can be changed")

	var cafe_plan := live()
	cafe_plan.start_lease(8, "long", NOW)
	cafe_plan.collect(6, NOW + 5)
	check(cafe_plan.upgrade(6, NOW + 5) and cafe_plan.opening_stage == 2, "Cafe expansion is a viable first investment before home construction")
	cafe_plan.advance(NOW + 11)
	check(cafe_plan.opening_stage == -1 and cafe_plan.cafe_capacity(6) == 16 and cafe_plan.count_kind("Konut") == 2, "Completed cafe expansion independently exits the opening")
	var garden_plan := live()
	garden_plan.start_lease(8, "long", NOW)
	garden_plan.collect(6, NOW + 5)
	var garden := CityJourney.investment_site(garden_plan, "park", NOW + 5)
	var old_quote := garden_plan.rent_quote(8, "long", NOW + 5)
	check(garden_plan.build_street(CityStreets.frontage(int(garden.index)), NOW + 5) and garden_plan.build(int(garden.index), "park", NOW + 5), "A park is an affordable first investment")
	garden_plan.advance(NOW + 9)
	check(garden_plan.opening_stage == -1 and garden_plan.rent_quote(8, "long", NOW + 9) > old_quote and int(garden_plan.lots[8].lease.amount) == old_quote, "A completed park raises future rents and preserves signed contracts")

	# No project grants or cash injection. Two cycles finance both a home and
	# district expansion when the player starts by expanding the cafe.
	for index in [6, 8, 13]: cafe_plan.collect(index, NOW + 240)
	check(cafe_plan.level() == 2 and not cafe_plan.expand(), "Budget alone cannot bypass company progression")
	check(cafe_plan.build_street("h:0:3", NOW + 240) and cafe_plan.build(12, "cottage", NOW + 240), "First operating cycle pays for the next home")
	for index in [8, 12, 13]: cafe_plan.start_lease(index, "long", NOW + 248)
	check(cafe_plan.customers(6, NOW + 248) == 12, "Cafe expansion monetises the new home's additional four neighbours")
	for index in [6, 8, 12, 13]: cafe_plan.collect(index, NOW + 488)
	check(cafe_plan.level() >= 3 and cafe_plan.cash >= CityState.EXPANSION_PRICE and cafe_plan.expand() and cafe_plan.unlocked_columns == CityState.COLUMNS, "Eight new plots can be funded entirely by ordinary rent and trade")

	var matching := live()
	matching.street_edges = CityStreets.all_edges()
	matching._install(0, "cafe", NOW)
	matching._install(1, "apartments", NOW)
	matching._install(6, "cottage", NOW)
	matching.start_lease(1, "long", NOW)
	matching.start_lease(6, "long", NOW)
	var before_cafe := CityNeighbourhood.describe(matching, NOW)
	var quote := matching.cafe_projection(2, NOW)
	check(before_cafe.reachable == 16 and before_cafe.served == 8 and before_cafe.residents == 20, "Reachable demand, served customers and isolated neighbours are separate counts")
	check(quote.customers == 8 and quote.district_change == 496, "New cafe forecast adds only served demand without double counting")
	matching._install(2, "cafe", NOW + 12)
	var served := matching.commerce.allocate(matching, NOW + 12)
	check(served.counts[0] == 8 and served.counts[2] == 8 and served.destinations[6] == [0, 0, 0, 0], "Flexible customers change cafes to make room for households with one route")
	check(CityProjects.progress(matching, "commerce", NOW + 12) == 16, "Commerce objective counts actual customers")

	var renewed := live()
	renewed.advance(NOW + 241)
	check(not renewed.is_occupied(13, NOW + 241) and renewed.customers(6, NOW + 241) == 0 and int(renewed.lots[13].lease.end) == NOW + 240, "Waiting at the menu does not freeze or refill the inherited tenant")
	check(renewed.start_lease(8, "long", NOW + 241) and renewed.customers(6, NOW + 241) == 4, "After long idle, first new family teaches real four-customer trade rather than pretending eight")
	check(renewed.collect(13, NOW + 241) > 0 and renewed.opening_stage == 1, "Collecting legitimate expired rent is not mistaken for the cafe lesson")
	check(renewed.collect(6, NOW + 242) > 0 and renewed.opening_stage == 2, "Expired initial tenant does not block progress through genuine cafe earnings")
	var changed := live()
	changed.lots[8].lease = changed.lots[13].lease.duplicate(true)
	changed.lots[13].lease = {}
	guide = CityJourney.describe(changed, NOW)
	check(guide.target == 13 and guide.action == "guide_home", "Reloaded stage zero finds another real vacant home instead of forcing occupied slot eight")
	changed.lots[13].lease = changed.lots[8].lease.duplicate(true)
	check(CityJourney.describe(changed, NOW).action == "guide_build", "No vacant home yields a building choice rather than an occupied target")

	for stage in [-1, 0, 1, 2]:
		var source := live()
		source.opening_stage = stage
		var loaded := CityState.new()
		var json_data: Variant = JSON.parse_string(JSON.stringify(source.snapshot()))
		check(loaded.restore(json_data) and loaded.growth_economy and loaded.opening_stage == stage and loaded.cash == source.cash and loaded.experience == source.experience and loaded.contracts_signed == 0 and int(loaded.lots[13].lease.amount) == int(source.lots[13].lease.amount) and loaded.customers(6, NOW) == 4, "Opening stage %d survives JSON save/load with all real balances" % stage)
	var legacy := live().snapshot()
	legacy.erase("opening_stage")
	legacy.erase("growth_economy")
	legacy.cash = 12000
	legacy.milestone = 1
	var loaded := CityState.new()
	check(loaded.restore(legacy) and not loaded.growth_economy and loaded.opening_stage == -1, "Existing version-six save retains the original economy")
	for version in [1, 2, 3, 4, 5]:
		legacy.version = version
		check(loaded.restore(legacy) and loaded.opening_stage == -1 and loaded.cash == 12000, "Version %d retains balances and does not acquire new-opening state" % version)
	var stable := loaded.snapshot()
	for bad: Variant in [-2, 3, 0.5, true, "1", null, INF, NAN]:
		var invalid := stable.duplicate(true)
		invalid.opening_stage = bad
		invalid.cash = 999
		check(not loaded.restore(invalid) and loaded.snapshot() == stable, "Invalid opening stage %s rejects atomically" % str(bad))
	var old := CityState.new()
	old.seed(NOW)
	check(old.opening_stage == -1 and old.milestone == 0 and old.collectible(8, NOW) == 350 and old.lots[6].kind == "", "Existing seed fixture remains the original ready-rent world")
	city.seed_live(NOW)
	check(city.opening_stage == 0 and city.cash == 2400 and city.experience == 60 and city.contracts_signed == 0 and city.milestone == 5, "Starting a new live town resets progression rather than retaining old opening success")
	print("OPENING_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
