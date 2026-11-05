extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	CityLocale.set_language("en")
	var now := 1000000
	var city := CityState.new()
	city.seed(now)
	var snapshot := city.snapshot()
	check(CityJourney.describe(city, now).action == "guide_home" and city.snapshot() == snapshot, "Guidance points to actual ready rent without changing the city")
	city.collect(8, now)
	check(CityJourney.describe(city, now).action == "claim", "Earned first reward has a direct continuation")
	city.claim_objective(now)
	check(CityJourney.describe(city, now).action == "streets", "Next chapter explains the missing street, not a composite number")
	city.build_street("h:3:2", now)
	check(CityJourney.describe(city, now).action == "guide_build", "After connecting a street the next action becomes the third home")
	city.build(9, "cottage", now)
	city.claim_objective(now)
	var site := CityJourney.cafe_site(city, now + 10)
	check(site >= 0 and city.lots[site].kind.is_empty() and city.has_frontage(site), "Suggested cafe site is empty, accessible and connected")
	var welcome := CityJourney.describe(city, now + 10)
	check(welcome.action == "guide_cafe" and welcome.target == site, "A new cafe is offered before repeated lease renewals can distract from the goal")
	city.build(site, "cafe", now + 10)
	check(CityJourney.describe(city, now + 10).action == "guide_home", "Cafe construction immediately offers a useful neighbour action instead of a waiting button")
	city.start_lease(8, "regular", now + 10)
	city.start_lease(13, "regular", now + 10)
	var active_snapshot := city.snapshot()
	var cafe := CityJourney.describe(city, now + 10)
	check(cafe.action == "guide_home" and cafe.target == site and city.snapshot() == active_snapshot, "When neighbours are ready guidance visits the opening cafe without inventing a lease task")
	city.advance(now + 23)
	city.advance(now + 1000)
	check(CityJourney.describe(city, now + 1000).action == "claim", "An earned cafe achievement remains the next action after residents leave")
	print("JOURNEY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
