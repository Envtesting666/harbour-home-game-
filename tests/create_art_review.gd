extends SceneTree
## A separate populated save for evaluating scale, material cohesion and coverage.
## Never reads or writes the player's profile.

func _initialize() -> void:
	var path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-save="):
			path = argument.trim_prefix("--review-save=")
	if path.is_empty():
		push_error("Art review requires an explicit --review-save file.")
		quit(1)
		return
	var state := CityState.new()
	var now := int(Time.get_unix_time_from_system())
	state.seed(now)
	state.street_edges.clear()
	for y in range(1, 5):
		for x in range(4): state.street_edges.append("h:%d:%d" % [x, y])
	for y in range(4): state.street_edges.append("v:0:%d" % y)
	state.street_edges.append("v:3:2")
	state.street_edges.append("v:3:3")
	state.cash = 18500
	state.experience = 600
	state.milestone = 2
	var layout := {0:"villa",1:"cottage",2:"apartments",3:"park",6:"apartments",7:"hq",8:"cottage",9:"cafe",12:"cottage",13:"villa",14:"park",15:"apartments",18:"park",19:"cottage",20:"cafe",21:"villa"}
	for index: int in layout:
		state._install(index, layout[index], now)
		if layout[index] == "cottage":
			state.lots[index].appearance = CityState.HOME_DESIGNS[int(index / 6) % 3]
		if state.catalog.is_residential(layout[index]):
			state.lots[index].lease = {"type":"regular", "start":now - 10, "end":now + 60, "amount":state.rent_quote(index, "regular", now)}
	var store := CitySaveStore.new(path)
	quit(0 if store.write(state) else 1)
