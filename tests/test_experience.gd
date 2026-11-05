extends SceneTree

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var now := 1000000
	CityLocale.set_language("en")
	check(CityLocale.t("Konut") == "Homes" and CityLocale.money(18500) == "$18,500", "Default English labels and currency")
	check(CityLocale.f("Toplam {0}", [CityLocale.money(2400)]) == "Total $2,400", "Dynamic costs use a complete localized template")
	CityLocale.set_language("tr")
	check(CityLocale.t("Homes") == "Konut" and CityLocale.money(18500) == "18.500 $", "Language switches in both directions")
	var preferences := CityPreferences.new("res://.dev/preferences-test.cfg")
	preferences.language = "tr"
	preferences.effects = .35
	check(preferences.save() == OK, "Preferences save outside game state")
	var loaded := CityPreferences.new("res://.dev/preferences-test.cfg")
	check(loaded.language == "tr" and is_equal_approx(loaded.effects, .35), "Language and volume survive restart")
	CityLocale.set_language("en")
	var city := CityState.new()
	city.seed(now)
	city.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	city.cash = 100000
	city.experience = 600
	check(not city.choose_project("garden"), "Advanced projects do not bypass the introductory progression")
	city.milestone = 5
	check(city.needs_project() and city.choose_project("garden"), "Player chooses a post-intro direction")
	var snapshot := city.snapshot()
	var restored := CityState.new()
	check(restored.restore(snapshot) and restored.active_project == "garden", "Chosen direction survives save/load")
	for index in [0, 2, 6, 8]: city._install(index, "cottage", now)
	for index in [1, 7]: city._install(index, "park", now)
	check(CityProjects.progress(city, "garden", now) >= 4 and city.can_claim_objective(now), "Garden project rewards an actual connected layout")
	var cash := city.cash
	check(city.claim_objective(now) and city.cash == cash + 6500 and "garden" in city.completed_projects, "Project reward commits once")
	check(not city.claim_objective(now) and not city.choose_project("garden") and city.cash == cash + 6500, "Completed projects cannot be replayed for rewards")
	check(city.choose_project("commerce") and city.choose_project("prestige"), "Changing direction preserves freedom without issuing rewards")
	var bad := city.snapshot()
	bad.completed_projects = ["garden", "garden"]
	check(not restored.restore(bad), "Duplicate project completions are rejected")

	var offline := CityState.new()
	offline.seed(now)
	offline.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	offline.cash = 100000
	offline.experience = 600
	offline.collect(8, now)
	offline.start_lease(8, "short", now)
	offline.build(9, "cafe", now)
	check(offline.customers(9, now + 15) == 4 and offline.customers(9, now + 21) == 0, "Expired leases never provide permanent cafe customers")
	var online := CityState.new()
	check(online.restore(offline.snapshot()), "Online/offline comparison starts from the same state")
	for tick in range(1, 101): online.advance(now + tick)
	offline.advance(now + 100)
	check(offline.lots[9].business_pending == online.lots[9].business_pending and is_equal_approx(float(offline.lots[9].business_fraction), float(online.lots[9].business_fraction)), "Offline accrual equals frequent updates across lease expiry")
	check(offline.lots[9].business_pending == 66, "Only the eight occupied seconds after cafe construction are earned")
	var earned: int = offline.lots[9].business_pending
	offline.advance(now + 10000)
	check(offline.lots[9].business_pending == earned, "Leaving an expired rent uncollected cannot generate more commerce")
	check(offline.collect(8, now + 10001) == 358, "Expired rent is still safely collectible at its signed amount")
	var shared := CityState.new()
	shared.seed(now)
	shared.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	shared.cash = 100000
	shared.experience = 600
	shared.collect(8, now)
	shared.start_lease(8, "long", now)
	shared.build(9, "cafe", now)
	shared.build(15, "cafe", now)
	check(CityProjects.progress(shared, "commerce", now + 15) == 4, "Two cafes do not double-count one household for a project")
	shared.advance(now + 30)
	check(shared.lots[9].business_pending + shared.lots[15].business_pending == 148, "Shared cafe revenue respects the actual occupied construction window")
	var roundtrip := CityState.new()
	check(roundtrip.restore(shared.snapshot()) and roundtrip.snapshot() == shared.snapshot(), "Accrual fractions and new project fields round-trip exactly")
	var forecast := CityState.new()
	forecast.seed(now)
	forecast.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	forecast.collect(8, now)
	forecast.start_lease(8, "short", now)
	var before_forecast := forecast.snapshot()
	check(forecast.cafe_projection(9, now + 19).customers == 0 and forecast.snapshot() == before_forecast, "A cafe forecast accounts for leases expiring before construction finishes without changing state")
	var offers := CityState.new()
	offers.seed(now)
	offers.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	offers.cash = 100000
	offers.collect(8, now)
	var no_cafe := CityLeaseForecast.quote(offers, 8, "short", now)
	check(no_cafe.local_trade == 0 and no_cafe.net_rent == 358, "Lease offer separates fixed rent from absent local commerce")
	offers._install(9, "cafe", now)
	offers._install(15, "cafe", now)
	var original := offers.snapshot()
	var quick := CityLeaseForecast.quote(offers, 8, "short", now)
	var stable := CityLeaseForecast.quote(offers, 8, "long", now)
	check(offers.snapshot() == original, "Comparing terms never mutates cash, leases, projects or business clocks")
	check(quick.local_trade == 165 and stable.local_trade == 1984, "Two cafes share customers: lease forecast never doubles neighbourhood earnings")
	check(stable.net_rent == stable.rent - 120 and float(quick.net_rent) / quick.seconds > float(stable.net_rent) / stable.seconds, "Term choice exposes high active rent versus longer uninterrupted commerce")
	check(offers.start_lease(8, "long", now), "Forecasted lease can be committed normally")
	offers.advance(now + 240)
	check(offers.lots[9].business_pending + offers.lots[15].business_pending == stable.local_trade, "Forecast agrees with actual integrated cafe earnings over the full lease")
	var building_cafe := CityState.new()
	building_cafe.seed(now)
	building_cafe.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	building_cafe.cash = 100000
	building_cafe.experience = 600
	building_cafe.collect(8, now)
	check(building_cafe.build(9, "cafe", now), "Construction forecast fixture creates an unlocked cafe")
	check(CityLeaseForecast.quote(building_cafe, 8, "short", now).local_trade == 66, "Lease offer includes cafe construction time, not fictional full-term income")
	var frequent := CityState.new()
	frequent.seed(now)
	frequent.street_edges = CityStreets.all_edges()
	frequent._install(9, "cafe", now)
	frequent.collect(8, now)
	frequent.start_lease(8, "long", now)
	var batch := CityState.new()
	batch.restore(frequent.snapshot())
	var initial_xp := frequent.experience
	for second in range(1, 31): frequent.collect(9, now + second)
	batch.collect(9, now + 30)
	check(frequent.cash == batch.cash and frequent.experience == batch.experience and frequent.experience == initial_xp, "Collecting cafe income every second cannot farm rank or create extra money")
	print("EXPERIENCE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
