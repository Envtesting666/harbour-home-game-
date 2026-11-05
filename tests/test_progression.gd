extends SceneTree
## Evidence-driven progression regressions: demonstrated milestones must remain
## earned, and repeating clicks must not outperform equivalent occupancy time.
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func fresh(now: int) -> CityState:
	var city := CityState.new()
	city.seed(now)
	return city

func eight_customer_cafe(now: int, duration: String = "regular") -> CityState:
	var city := fresh(now)
	city.milestone = 2
	city.collect(8, now)
	city._install(6, "cafe", now)
	city.start_lease(8, duration, now)
	city.start_lease(13, duration, now)
	return city

func _initialize() -> void:
	const NOW := 1000000
	var opening := fresh(NOW)
	check(opening.collect(8, NOW) == 350 and opening.experience == 64, "The completed starter lease gives four occupancy XP without changing its locked rent")
	check(opening.claim_objective(NOW) and opening.experience == 144 and opening.level() == 1, "The first reward does not unlock cafe before the street-and-third-home lesson")
	opening.build_street("h:3:2", NOW)
	check(opening.build(9, "cottage", NOW) and opening.experience == 169 and opening.level() == 2, "Investing in the third home naturally unlocks the first cafe")

	var short := fresh(NOW)
	var long := fresh(NOW)
	short.collect(8, NOW)
	long.collect(8, NOW)
	var base_xp := short.experience
	var start_xp := long.experience
	check(long.start_lease(8, "long", NOW) and long.experience == start_xp, "Signing itself cannot farm company rank")
	check(long.collect(8, NOW + 239) == 0 and long.experience == start_xp, "Unfinished occupancy grants no early collection XP")
	for cycle in range(12):
		short.start_lease(8, "short", NOW + cycle * 20)
		short.collect(8, NOW + (cycle + 1) * 20)
	long.collect(8, NOW + 240)
	check(short.experience - base_xp == 48 and long.experience - start_xp == 48, "Twelve short leases and one long lease earn the same XP for 240 occupied seconds")
	var paid_xp := long.experience
	check(long.collect(8, NOW + 240) == 0 and long.experience == paid_xp, "A completed lease cannot replay its XP")
	var regular := fresh(NOW)
	regular.collect(8, NOW)
	var regular_xp := regular.experience
	regular.start_lease(8, "regular", NOW)
	regular.collect(8, NOW + 70)
	check(regular.experience - regular_xp == 14, "Regular occupancy follows the same one-XP-per-five-seconds rule")

	var achieved := eight_customer_cafe(NOW)
	check(achieved.customers(6, NOW) == 8 and achieved.commerce_peak_customers == 8 and achieved.can_claim_objective(NOW), "The eighth real customer immediately demonstrates the first cafe opening")
	achieved.advance(NOW + 71)
	check(achieved.customers(6, NOW + 71) == 0 and achieved.objective(NOW + 71).progress == 8, "Live demand can expire while demonstrated opening progress remains earned")
	var restored := fresh(NOW)
	check(restored.restore(achieved.snapshot()) and restored.commerce_peak_customers == 8, "The demonstrated milestone survives an exact save and load")
	var reward_cash := restored.cash
	check(restored.claim_objective(NOW + 72) and restored.cash == reward_cash + 2500 and restored.milestone == 3, "The earned cafe reward remains claimable after lease expiry and restart")
	check(not restored.claim_objective(NOW + 72) and restored.cash == reward_cash + 2500, "The same cafe proof cannot replay its reward")

	var construction := fresh(NOW)
	construction.experience = 300
	construction.milestone = 2
	construction.collect(8, NOW)
	construction.start_lease(8, "regular", NOW)
	construction.start_lease(13, "regular", NOW)
	check(construction.build(6, "cafe", NOW), "The opening scenario starts a cafe through normal construction")
	check(construction.commerce_peak_customers == 0, "An unfinished cafe does not demonstrate its future demand")
	check(construction.claim_objective(NOW + 12) and construction.milestone == 3, "A direct claim at actual cafe completion observes the opening before evaluating the goal")

	var offline := fresh(NOW)
	offline.experience = 300
	offline.milestone = 2
	offline.collect(8, NOW)
	offline.start_lease(8, "regular", NOW)
	offline.start_lease(13, "regular", NOW)
	offline.build(6, "cafe", NOW)
	offline.advance(NOW + CityState.OFFLINE_LIMIT + 1000)
	check(offline.commerce_peak_customers == 8 and offline.can_claim_objective(NOW + CityState.OFFLINE_LIMIT + 1000), "Offline completion records actual historical opening even beyond the money accrual cap")
	check(offline.lots[6].business_pending == 0, "Remembering historical progress does not invent money outside the offline accrual cap")

	var disconnected := fresh(NOW)
	disconnected.experience = 300
	disconnected.milestone = 2
	disconnected.collect(8, NOW)
	disconnected.start_lease(8, "short", NOW)
	disconnected.start_lease(13, "short", NOW)
	disconnected.build_street("h:3:3", NOW)
	disconnected._install(15, "cafe", NOW)
	disconnected.advance(NOW + 100)
	check(disconnected.commerce_peak_customers < 8, "Disconnected historical residents cannot count as demonstrated cafe demand")
	disconnected.build_street("v:3:2", NOW + 101)
	disconnected.advance(NOW + 200)
	check(disconnected.commerce_peak_customers < 8, "A late shortcut never applies today's reach to expired historical leases")

	var snapshot := achieved.snapshot()
	for bad_peak: Variant in [-1, 9, 2.5, "8", true, null]:
		var bad := snapshot.duplicate(true)
		bad.commerce_peak_customers = bad_peak
		var before := restored.snapshot()
		check(not restored.restore(bad) and restored.snapshot() == before, "Invalid peak %s is rejected atomically" % str(bad_peak))
	var missing := snapshot.duplicate(true)
	missing.erase("commerce_peak_customers")
	check(not restored.restore(missing), "A current save cannot silently discard earned opening progress")
	for version in [1, 2, 3, 4, 5]:
		var old := snapshot.duplicate(true)
		old.version = version
		old.erase("commerce_peak_customers")
		if version < 5: old.erase("street_edges")
		check(restored.restore(old) and restored.commerce_peak_customers == 0 and restored.experience == achieved.experience and restored.cash == achieved.cash, "Legacy version %d migrates without rewriting past cash or rank" % version)
	var peak_reset := eight_customer_cafe(NOW)
	peak_reset.seed(NOW + 100)
	check(peak_reset.commerce_peak_customers == 0, "Seeding a new neighbourhood clears only its old demonstration history")
	print("PROGRESSION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
