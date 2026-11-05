extends SceneTree
## Transaction, persistence and spatial-economy regression tests.
## Run headlessly; no UI fixtures or external test framework.

var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var now := 1000000
	var catalog := CityCatalog.new()
	check(catalog.definitions.size() == 8, "All catalog entries load")
	var city := CityState.new(catalog)
	city.seed(now)
	city.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	var initial := city.cash
	check(city.collect(8, now) == 350, "Ready starting rent can be collected")
	check(city.collect(8, now) == 0 and city.cash == initial + 350, "Rent cannot be replayed or double-collected")
	check(not city.build(4, "cottage", now) and city.cash == initial + 350, "Locked plots cannot spend currency")
	check(not city.build(0, "apartments", now), "Rank-gated buildings cannot be built early")
	check(city.start_lease(13, "short", now), "Vacant home accepts a lease")
	var locked_quote: int = city.lots[13].lease.amount
	check(locked_quote == 358, "Adjacent park applies the defined 12 percent rent bonus")
	check(not city.start_lease(13, "long", now), "Existing contracts cannot be overwritten")
	check(city.collect(13, now + 19) == 0, "Rent cannot be collected before its due time")
	check(city.build(12, "park", now), "Construction buys a valid empty plot")
	check(city.park_bonus(13, now + 1) == 0.12, "Unfinished parks do not grant a bonus")
	check(is_equal_approx(city.park_bonus(13, now + 5), 0.24), "Completed neighboring parks combine")
	check(int(city.lots[13].lease.amount) == locked_quote, "New parks cannot retroactively alter a signed contract")
	check(city.collect(13, now + 20) == locked_quote, "Collection pays the signed value")
	check(city.collect(13, now + 20) == 0, "Repeat collection remains safe")
	city.cash = 0
	check(city.start_lease(13, "short", now + 21), "A zero-cash player can always restart free short contracts")
	check(not city.build(0, "cottage", now + 21) and city.cash == 0, "Insufficient funds never create negative cash")
	check(not city.upgrade(13, now + 21), "An occupied home cannot be upgraded under an active lease")
	var before_failed_restore := city.snapshot()
	var invalid := before_failed_restore.duplicate(true)
	invalid.lots[2].kind = "unregistered_building"
	check(not city.restore(invalid) and city.snapshot() == before_failed_restore, "Invalid snapshots are rejected without partially replacing live state")

	var commercial := CityState.new(catalog)
	commercial.seed(now)
	commercial.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	commercial.cash = 100000
	commercial.experience = 300
	commercial.collect(8, now)
	commercial.start_lease(8, "long", now)
	commercial.start_lease(13, "long", now)
	commercial.build(9, "cafe", now)
	check(is_equal_approx(commercial.customers(9, now + 15), 4.0), "A nearby occupied home supplies cafe customers")
	commercial.build(15, "cafe", now)
	check(is_equal_approx(commercial.customers(9, now + 15), 2.0), "Competing cafes share overlapping customers")
	check(is_equal_approx(commercial.customers(15, now + 15), 6.0), "Customer shares also include uniquely served homes")
	commercial.advance(now + 72)
	var accrued: int = commercial.lots[9].business_pending
	commercial.advance(now + 72)
	check(accrued > 0 and int(commercial.lots[9].business_pending) == accrued, "Business clock does not award the same cycle twice")
	check(commercial.collect(9, now + 72) == accrued, "Business proceeds can be collected")
	check(commercial.collect(9, now + 72) == 0, "Business proceeds cannot be double-collected")
	var roundtrip := CityState.new(catalog)
	check(roundtrip.restore(commercial.snapshot()), "A valid state restores")
	check(roundtrip.snapshot() == commercial.snapshot(), "Restoring preserves all domain state exactly")
	check(not commercial.move_building(7, 0, now + 72), "Company HQ cannot be moved")
	check(not commercial.move_building(9, 13, now + 72), "Moving cannot overwrite another building")
	var move_cash := commercial.cash
	check(commercial.move_building(9, 0, now + 72) and commercial.cash == move_cash - 600, "Moving onto an unowned parcel charges its land cost")
	check(commercial.lots[9].kind == "" and commercial.lots[0].kind == "cafe", "Moving preserves one building without duplication")
	var renovation := CityState.new(catalog)
	renovation.seed(now)
	renovation.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	var renovation_price := renovation.upgrade_price(13)
	var before_rent := renovation.rent_quote(13, "short", now)
	check(renovation.upgrade(13, now) and renovation.cash == 12000 - renovation_price, "Renovation charges the catalog price once")
	check(not renovation.is_complete(13, now + 5) and renovation.is_complete(13, now + 6), "Renovation has a persisted construction period")
	check(renovation.rent_quote(13, "short", now + 6) > before_rent, "Completed renovation increases future lease income")
	var prediction := CityState.new(catalog)
	prediction.seed(now)
	prediction.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	prediction.experience = 300
	prediction.start_lease(13, "long", now)
	prediction.collect(8, now)
	prediction.start_lease(8, "long", now)
	var forecast := prediction.projected_customers(15, now)
	prediction.build(15, "cafe", now)
	check(is_equal_approx(forecast, prediction.customers(15, now + 12)), "Placement forecast matches the completed cafe's customer calculation")
	var single_business_income := prediction.business_income(15, now + 20)
	prediction.build(9, "cafe", now + 20)
	check(prediction.business_income(15, now + 32) + prediction.business_income(9, now + 32) == single_business_income, "Splitting the same customers across cafes does not create free revenue")
	var boutique := CityState.new(catalog)
	var community := CityState.new(catalog)
	boutique.seed(now)
	boutique.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	community.seed(now)
	community.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	check(boutique.upgrade(13, now, "boutique") and community.upgrade(13, now, "community"), "Both residential renovation plans are valid")
	check(boutique.rent_quote(13, "short", now + 6) > community.rent_quote(13, "short", now + 6), "Boutique plan wins on rent at the same level")
	check(community.resident_count(13) > boutique.resident_count(13), "Community plan wins on resident capacity")
	boutique.start_lease(13, "short", now + 6)
	community.start_lease(13, "short", now + 6)
	check(community.projected_customers(15, now + 6) > boutique.projected_customers(15, now + 6), "Renovation choice changes nearby commerce, not only a display value")
	var commerce_rate: float = float(catalog.get_building("cafe").customer_income) / CityState.BUSINESS_CYCLE
	var boutique_business := boutique.projected_customers(15, now + 6) * commerce_rate
	var community_business := community.projected_customers(15, now + 6) * commerce_rate
	check(float(boutique.rent_quote(13, "short", now + 6)) / 20 + boutique_business > float(community.rent_quote(13, "short", now + 6)) / 20 + community_business, "Boutique cottage wins when the owner actively renews short leases")
	check(float(community.rent_quote(13, "long", now + 6)) / 240 + community_business > float(boutique.rent_quote(13, "long", now + 6)) / 240 + boutique_business, "Community cottage wins with long leases and nearby commerce")
	var migrated := CityState.new(catalog)
	var legacy := city.snapshot()
	legacy.version = 1
	for lot: Dictionary in legacy.lots:
		lot.erase("specialization")
	var old_cash: int = city.cash
	check(migrated.restore(legacy) and migrated.cash == old_cash and migrated.lots[13].specialization == "neutral", "Version one saves migrate without changing balances")
	check(migrated.snapshot().version == CityState.SAVE_VERSION, "Migrated saves are written with the new schema version")
	var specialized_save := CityState.new(catalog)
	check(specialized_save.restore(community.snapshot()) and specialized_save.lots[13].specialization == "community", "Renovation branch survives a save round trip")
	var designs := CityState.new(catalog)
	designs.seed(now)
	designs.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	check(designs.build(0, "cottage", now, "courtyard") and designs.lots[0].appearance == "courtyard", "The chosen house design is part of the built property")
	var design_save := CityState.new(catalog)
	check(design_save.restore(designs.snapshot()) and design_save.lots[0].appearance == "courtyard", "House design survives a save round trip")
	check(designs.move_building(0, 1, now + 9) and designs.lots[1].appearance == "courtyard", "Moving preserves the selected architecture")
	var design_before := designs.snapshot()
	check(not designs.build(0, "cottage", now, "unknown") and designs.snapshot() == design_before, "Invalid designs cannot spend currency or mutate the city")
	var version_two := design_save.snapshot()
	version_two.version = 2
	for lot: Dictionary in version_two.lots:
		lot.erase("appearance")
	check(designs.restore(version_two) and designs.cash == int(version_two.cash) and designs.lots[13].appearance in CityState.HOME_DESIGNS, "Version two migration assigns valid architecture without changing money")
	var planning := CityState.new(catalog)
	planning.seed(now)
	planning.street_edges = CityStreets.all_edges() # Existing tests isolate economy from new street planning.
	planning.experience = 300
	planning.cash = 100000
	planning.collect(8, now)
	planning.start_lease(8, "long", now)
	planning.start_lease(13, "long", now)
	check(planning.park_projection(12, now) == 1, "A prospective park reports the residential neighbor it can improve")
	planning.build(15, "cafe", now)
	var cafe_plan := planning.cafe_projection(9, now + 13)
	var before_cafe_income := planning.business_income(15, now + 13)
	planning.build(9, "cafe", now + 13)
	check(cafe_plan.income == planning.business_income(9, now + 26), "Cafe placement quotes the income its completed building earns")
	check(cafe_plan.district_change == 0 and planning.business_income(9, now + 26) + planning.business_income(15, now + 26) == before_cafe_income, "Planning distinguishes the new cafe's income from zero net neighborhood gain")

	var path := "res://.dev/test-save.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-save="):
			path = argument.trim_prefix("--test-save=")
	var store := CitySaveStore.new(path)
	check(store.write(commercial), "First atomic save succeeds")
	var saved_cash := commercial.cash
	commercial.cash += 123
	check(store.write(commercial), "Replacing an existing save succeeds")
	var restored := CityState.new(catalog)
	check(store.load_into(restored) and restored.cash == commercial.cash, "Latest save loads")
	var corrupt := FileAccess.open(store.path, FileAccess.WRITE)
	corrupt.store_string("broken json")
	corrupt.close()
	check(store.load_into(restored) and restored.cash == saved_cash, "Corrupt primary save recovers the last-known-good backup")
	print("CITY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
