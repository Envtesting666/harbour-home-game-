extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var city := CityState.new()
	city.seed(1000000)
	city.street_edges = CityStreets.all_edges()
	city.collect(8, 1000000)
	check(city.move_building(8, 3, 1000000) and city.lots[3].visual_seed == 8, "Moving a property preserves its individual visual identity")
	var copy := CityState.new()
	check(copy.restore(city.snapshot()) and copy.snapshot() == city.snapshot(), "Property identity round trips without changing economic state")
	var old := city.snapshot()
	old.version = 5
	for lot: Dictionary in old.lots: lot.erase("visual_seed")
	check(copy.restore(old) and copy.lots[3].visual_seed == 3 and copy.cash == city.cash, "Older saves receive stable parcel identities without money or rank changes")
	var invalid := city.snapshot()
	invalid.lots[3].visual_seed = 1.5
	var before := copy.snapshot()
	check(not copy.restore(invalid) and copy.snapshot() == before, "Invalid visual identity is rejected atomically")
	print("PROPERTY_IDENTITY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
