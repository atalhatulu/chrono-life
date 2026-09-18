extends RefCounted

static var _cache: Dictionary = {}

static func _path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("housing_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = _path(state)
	if path.is_empty():
		return {"dwellings": [], "rules": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"dwellings": [], "rules": {}}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"dwellings": [], "rules": {}}
	return _cache[path]

static func dwellings_by_id(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d: Dictionary in _catalog(state).get("dwellings", []):
		out[d.id] = d
	return out

static func initialize(state: Dictionary, initial_dwelling_id: String) -> void:
	if state.has("housing"):
		return
	state.housing = {
		"dwelling_id": initial_dwelling_id,
		"since_year": int(state.world.year),
		"tenure": "household_use",
		"unpaid_years": 0,
		"move_count": 0,
		"history": []
	}
	var defs: Dictionary = dwellings_by_id(state)
	if defs.has(initial_dwelling_id):
		state.housing.tenure = str(defs[initial_dwelling_id].get("tenure", "household_use"))
	state.housing.history.append({"year": int(state.world.year), "kind": "moved_in", "dwelling_id": initial_dwelling_id})

static func current_dwelling(state: Dictionary) -> Dictionary:
	var defs: Dictionary = dwellings_by_id(state)
	return defs.get(str(state.get("housing", {}).get("dwelling_id", "")), {})

static func annual_cost(state: Dictionary) -> int:
	var d: Dictionary = current_dwelling(state)
	return int(d.get("annual_cost", 0))

static func living_count(state: Dictionary) -> int:
	var n: int = 0
	for id: String in state.household.member_ids:
		if state.actors[id].alive:
			n += 1
	return n

static func overcrowding(state: Dictionary) -> int:
	var d: Dictionary = current_dwelling(state)
	if d.is_empty():
		return 0
	return maxi(0, living_count(state) - int(d.get("capacity", 1)))

static func available_dwellings(state: Dictionary) -> Array[Dictionary]:
	var p: Dictionary = state.actors[state.meta.player_id]
	var out: Array[Dictionary] = []
	for d: Dictionary in _catalog(state).get("dwellings", []):
		if int(p.age) < int(d.get("min_age", 0)):
			continue
		out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.annual_cost) < int(b.annual_cost))
	return out

static func move_to(state: Dictionary, dwelling_id: String) -> Dictionary:
	var defs: Dictionary = dwellings_by_id(state)
	if not defs.has(dwelling_id):
		return {"ok": false, "error": "Unknown dwelling"}
	var target: Dictionary = defs[dwelling_id]
	var p: Dictionary = state.actors[state.meta.player_id]
	if int(p.age) < int(target.get("min_age", 0)):
		return {"ok": false, "error": "Dwelling unavailable at this age"}
	if str(state.housing.dwelling_id) == dwelling_id:
		return {"ok": false, "error": "Already living there"}
	var previous: String = str(state.housing.dwelling_id)
	state.housing.dwelling_id = dwelling_id
	state.housing.tenure = str(target.get("tenure", "rent"))
	state.housing.since_year = int(state.world.year)
	state.housing.unpaid_years = 0
	state.housing.move_count = int(state.housing.move_count) + 1
	state.housing.history.append({"year": int(state.world.year), "kind": "moved",
		"from": previous, "to": dwelling_id})
	state.history.append({"id":"%d:housing_move:%d" % [int(state.world.year), state.history.size()],
		"year":int(state.world.year),"kind":"housing_move","cause_id":"",
		"details":{"from":previous,"to":dwelling_id}})
	return {"ok": true, "dwelling": target}

static func apply_wellbeing(state: Dictionary) -> void:
	var d: Dictionary = current_dwelling(state)
	if d.is_empty():
		return
	var rules: Dictionary = _catalog(state).get("rules", {})
	var crowd: int = overcrowding(state)
	for id: String in state.household.member_ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		if crowd > 0:
			actor.health = clampi(int(actor.health) - crowd * int(rules.get("overcrowding_health_penalty_per_person", 0)), 1, 100)
			if actor.has("needs"):
				actor.needs.stress = clampi(int(actor.needs.stress) + crowd * int(rules.get("overcrowding_stress_per_person", 0)), 0, 100)
		if int(d.get("quality", 50)) < int(rules.get("low_quality_health_threshold", 0)):
			actor.health = clampi(int(actor.health) - int(rules.get("low_quality_health_penalty", 0)), 1, 100)
		if actor.has("needs") and int(d.get("quality", 0)) >= int(rules.get("good_quality_happiness_threshold", 101)):
			actor.needs.happiness = clampi(int(actor.needs.happiness) + int(rules.get("good_quality_happiness_bonus", 0)), 0, 100)

static func record_payment(state: Dictionary, rent_due: int, rent_paid: int) -> void:
	if rent_due <= 0:
		state.housing.unpaid_years = 0
		return
	if rent_paid < rent_due:
		state.housing.unpaid_years = int(state.housing.unpaid_years) + 1
	else:
		state.housing.unpaid_years = 0
