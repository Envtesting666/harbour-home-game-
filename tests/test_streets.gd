extends SceneTree
## Consequences of authored topology, transaction integrity and old-save migration.

var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var now := 1000000
	var starter := CityState.new()
	starter.seed(now)
	starter.experience = 600
	check(starter.street_edges.size() == 6 and CityStreets.all_edges().size() == 58, "A new town has a small starter lane rather than a prebuilt street grid")
	check(starter.has_frontage(7) and starter.has_frontage(8) and starter.has_frontage(13) and starter.has_frontage(14), "Every starting property has a source-connected south entrance")
	var initial := starter.snapshot()
	check(not starter.build(9, "cafe", now) and starter.snapshot() == initial, "A building cannot buy disconnected meadow or charge its land cost")
	check(not starter.build_street("h:0:0", now) and starter.snapshot() == initial, "A disconnected street cannot be purchased")
	var quote := starter.street_quote("h:3:2", now)
	check(quote.price == 180 and quote.new_frontages == 1 and starter.snapshot() == initial, "Street preview reports newly usable frontage without changing the town")
	check(starter.build_street("h:3:2", now) and starter.cash == int(initial.cash) - 180 and starter.has_frontage(9), "An attached street opens its actual building frontage for the quoted cost")
	check(not starter.build_street("h:3:2", now), "The same segment cannot be bought twice")
	check(not starter.build_street("h:4:2", now), "Growth beyond the owned district still needs district expansion")
	check(starter.build(9, "cafe", now), "A connected frontage permits normal building construction")
	var before_remove := starter.snapshot()
	check(not starter.remove_street("h:3:2", now) and starter.snapshot() == before_remove, "Removing a building's only frontage never strands it or issues a refund")
	check(not starter.remove_street("h:0:2", now), "The source connection cannot disconnect the occupied neighbourhood")
	check(not starter.move_building(9, 0, now + 13), "Moving cannot bypass the destination frontage requirement")

	var planning := CityState.new()
	planning.seed(now)
	planning.milestone = 1
	check(planning.objective(now).progress == 2 and not planning.can_claim_objective(now), "The second milestone starts from two homes and no player-authored street")
	planning.build_street("h:3:2", now)
	check(planning.objective(now).progress == 3 and not planning.can_claim_objective(now), "A new lane alone does not finish the street-and-homes milestone")
	planning.build(9, "cottage", now)
	check(planning.objective(now).progress == 4 and planning.can_claim_objective(now), "A third home on the new lane completes the introductory spatial decision")
	var reward_cash := planning.cash
	check(planning.claim_objective(now) and planning.cash == reward_cash + 1600, "The revised milestone preserves its established reward")

	var cycling := CityState.new()
	cycling.seed(now)
	var original_xp := cycling.experience
	var original_cash := cycling.cash
	check(cycling.build_street("h:3:2", now) and cycling.remove_street("h:3:2", now), "An unused street extension can be reconsidered")
	check(cycling.cash == original_cash - 90 and cycling.experience == original_xp, "Build/remove cycles cost money and cannot farm rank experience")

	var routed := CityState.new()
	routed.seed(now)
	routed.experience = 600
	routed.cash = 100000
	routed.collect(8, now)
	routed.start_lease(8, "long", now)
	var promised_rent: int = routed.lots[8].lease.amount
	check(routed.build_street("h:3:3", now) and routed.build(15, "cafe", now), "A cafe can be built at the end of the longer starter loop")
	check(routed.has_frontage(15) and not CityStreets.can_reach(routed, 8, 15) and routed.customers(15, now + 20) == 0, "Connected buildings can still be too far apart along their actual streets")
	var before_shortcut := routed.snapshot()
	var shortcut := routed.street_quote("v:3:2", now + 42)
	check(shortcut.customer_change == 4 and shortcut.income_change == 248 and routed.snapshot() == before_shortcut, "A shortcut preview measures the actual four newly served residents and commerce rate")
	check(routed.build_street("v:3:2", now + 42), "The connecting shortcut is a valid street purchase")
	check(routed.lots[15].business_pending == 0, "Buying a shortcut cannot retroactively monetize the previous disconnected interval")
	check(CityStreets.can_reach(routed, 8, 15) and routed.customers(15, now + 43) == 4 and CityStreets.path(routed, 8, 15).size() == 2, "The same graph route enables the advertised cafe customers and pedestrian route")
	routed.advance(now + 72)
	check(routed.lots[15].business_pending == 248, "The cafe earns only the thirty seconds after its new customer connection")
	check(routed.remove_street("v:3:2", now + 87), "A redundant shortcut can be removed when all building frontages remain connected")
	check(routed.lots[15].business_pending == 372 and routed.customers(15, now + 88) == 0, "Removing a shortcut settles the prior connected interval before changing customer access")
	routed.advance(now + 117)
	check(routed.lots[15].business_pending == 372, "A disconnected local customer cannot continue producing cafe earnings")
	check(routed.collect(8, now + 241) == promised_rent, "Street redesign never changes the amount promised by an existing signed lease")

	var forecast := CityState.new()
	forecast.seed(now)
	forecast.cash = 100000
	forecast.collect(8, now)
	forecast.build_street("h:3:3", now)
	forecast._install(15, "cafe", now)
	check(CityLeaseForecast.quote(forecast, 8, "long", now).local_trade == 0, "Lease offers do not advertise unreachable cafe trade")
	forecast.build_street("v:3:2", now)
	check(CityLeaseForecast.quote(forecast, 8, "long", now).local_trade == 1984, "Lease forecasts use the same new route as the live cafe economy")
	forecast.start_lease(8, "long", now)
	forecast.milestone = 5
	forecast.active_project = "commerce"
	check(CityProjects.progress(forecast, "commerce", now) == 4, "Long-term commerce goals count the residents actually connected by streets")
	forecast.build_street("h:3:2", now)
	forecast._install(9, "cafe", now)
	check(forecast.customers(9, now) == 2 and forecast.customers(15, now) == 2 and CityProjects.progress(forecast, "commerce", now) == 4, "Two route-accessible cafes split one household without doubling project population")

	var snapshot := forecast.snapshot()
	var loaded := CityState.new()
	check(loaded.restore(snapshot) and loaded.snapshot() == snapshot and int(snapshot.version) == CityState.SAVE_VERSION, "Current schema persists the authored network and economy exactly")
	var bad := snapshot.duplicate(true)
	bad.street_edges.append("h:3:2")
	check(not loaded.restore(bad) and loaded.snapshot() == snapshot, "Duplicate street records are rejected atomically")
	bad = snapshot.duplicate(true)
	bad.street_edges.append("h:5:0")
	check(not loaded.restore(bad), "A disconnected saved street component is rejected")
	bad = snapshot.duplicate(true)
	bad.street_edges.append("v:7:0")
	check(not loaded.restore(bad), "Out-of-map saved segments are rejected")
	bad = snapshot.duplicate(true)
	bad.street_edges.append("h:01:2")
	check(not loaded.restore(bad), "Noncanonical duplicate-equivalent keys cannot bypass street validation")
	bad = snapshot.duplicate(true)
	bad.erase("street_edges")
	check(not loaded.restore(bad), "A new-schema save cannot silently lose its authored network")
	for version in [1, 2, 3, 4]:
		var old := snapshot.duplicate(true)
		old.version = version
		old.erase("street_edges")
		check(loaded.restore(old) and loaded.street_edges.size() == 58 and loaded.cash == forecast.cash and loaded.lots[8].lease.amount == forecast.lots[8].lease.amount, "Legacy version %d receives its old full road grid without changing cash or signed rent" % version)
	print("STREET_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
