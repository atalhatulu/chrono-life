extends RefCounted

const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path := str(state.get("meta", {}).get("migration_path", ""))
	if path.is_empty():
		return {"destinations": [], "rules": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"destinations": [], "rules": {}}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"destinations": [], "rules": {}}
	return _cache[path]

static func initialize(state: Dictionary) -> void:
	if not state.has("migration"):
		state.migration = {
			"current_location_id": str(state.world.location_id),
			"last_move_year": int(state.world.year) - 100,
			"move_count": 0,
			"history": []
		}

static func available_destinations(state: Dictionary) -> Array[Dictionary]:
	initialize(state)
	PersonalEconomy.normalize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	var rules: Dictionary = _catalog(state).get("rules", {})
	var cooldown := int(rules.get("migration_cooldown_years", 0))
	var buffer := int(rules.get("minimum_cash_buffer", 0))
	var out: Array[Dictionary] = []
	for d: Dictionary in _catalog(state).get("destinations", []):
		if str(d.id) == str(state.world.location_id):
			continue
		if int(p.age) < int(d.get("min_age", 0)):
			continue
		if int(state.world.year) - int(state.migration.last_move_year) < cooldown:
			continue
		if int(state.personal_economy.cash) < int(d.get("move_cost", 0)) + buffer:
			continue
		out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("move_cost", 0)) < int(b.get("move_cost", 0)))
	return out

static func move_to(state: Dictionary, destination_id: String) -> Dictionary:
	initialize(state)
	var target: Dictionary = {}
	for d: Dictionary in available_destinations(state):
		if str(d.id) == destination_id:
			target = d
			break
	if target.is_empty():
		return {"ok": false, "error": "Destination unavailable"}
	var cost := int(target.get("move_cost", 0))
	if cost > 0:
		var spend := PersonalEconomy.spend(state, cost, "migration", destination_id)
		if not spend.ok:
			return spend
	var previous := str(state.world.location_id)
	state.world.location_id = destination_id
	state.household.location_id = destination_id
	state.migration.current_location_id = destination_id
	state.migration.last_move_year = int(state.world.year)
	state.migration.move_count = int(state.migration.move_count) + 1
	state.migration.history.append({"year":int(state.world.year),"from":previous,"to":destination_id,"cost":cost})
	if state.has("households") and state.households.has(str(state.household.id)):
		state.households[str(state.household.id)].location_id = destination_id
	var employment_shift := int(target.get("employment_modifier", 0))
	state.world.employment_pressure = clampi(int(state.world.employment_pressure) + employment_shift, 0, 1000)
	state.history.append({"id":"%d:migration:%d" % [int(state.world.year), state.history.size()],
		"year":int(state.world.year),"kind":"migration","cause_id":"",
		"details":{"from":previous,"to":destination_id,"cost":cost}})
	return {"ok": true, "destination": target}
