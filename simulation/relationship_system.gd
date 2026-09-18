extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static var _cache: Dictionary = {}

static func _path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("relationships_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = _path(state)
	if path.is_empty():
		return {"encounter_pools": [], "first_names": [], "surnames": [], "rules": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"encounter_pools": [], "first_names": [], "surnames": [], "rules": {}}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"encounter_pools": [], "first_names": [], "surnames": [], "rules": {}}
	return _cache[path]

static func initialize(state: Dictionary) -> void:
	if not state.has("relationships"):
		state.relationships = {"people": {}, "history": []}
	if not state.relationships.has("history"):
		state.relationships.history = []
	var player_id: String = str(state.meta.player_id)
	for id: String in state.actors:
		if id == player_id:
			continue
		var actor: Dictionary = state.actors[id]
		var role: String = "family"
		if id.begins_with("parent"):
			role = "parent"
		elif id.begins_with("child"):
			role = "child"
		elif id == "spouse":
			role = "spouse"
		register_person(state, id, str(actor.name), role, actor.alive, "household", actor.get("sex", ""))

static func register_person(state: Dictionary, id: String, name: String, role: String,
		alive: bool = true, met_via: String = "unknown", sex: String = "") -> void:
	if not state.has("relationships"):
		state.relationships = {"people": {}, "history": []}
	if state.relationships.people.has(id):
		var current: Dictionary = state.relationships.people[id]
		current.role = role
		current.alive = alive
		if sex != "":
			current.sex = sex
		return
	var year: int = int(state.world.year)
	var seed: int = str(state.meta.master_seed).to_int()
	var attraction: int = Rng.integer(seed, "relationships", year, id, "attraction", 20, 80)
	var compatibility: int = Rng.integer(seed, "relationships", year, id, "compatibility", 25, 85)
	var base_close: int = 65 if role in ["parent", "child", "spouse", "family"] else 35
	var base_trust: int = 60 if role in ["parent", "child", "spouse", "family"] else 30
	state.relationships.people[id] = {
		"id": id, "name": name, "sex": sex, "role": role, "stage": role,
		"closeness": base_close, "trust": base_trust, "conflict": 8,
		"attraction": attraction, "compatibility": compatibility,
		"contact": 50 if role in ["parent", "child", "spouse", "family"] else 25,
		"alive": alive, "met_year": year, "met_via": met_via,
		"last_contact_year": year, "years_known": 0
	}
	state.relationships.history.append({"year": year, "kind": "met", "person_id": id, "role": role, "via": met_via})

static func normalize(state: Dictionary) -> void:
	initialize(state)
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		for key: String in ["closeness", "trust", "conflict", "attraction", "compatibility", "contact"]:
			rel[key] = clampi(int(rel.get(key, 0)), 0, 100)
		if state.actors.has(id):
			rel.alive = bool(state.actors[id].alive)
		rel.years_known = maxi(0, int(state.world.year) - int(rel.get("met_year", state.world.year)))

static func _rules(state: Dictionary) -> Dictionary:
	return _catalog(state).get("rules", {})

static func annual_drift(state: Dictionary) -> void:
	normalize(state)
	var rules: Dictionary = _rules(state)
	var close_decay: int = int(rules.get("annual_closeness_decay", 2))
	var contact_decay: int = int(rules.get("annual_contact_decay", 1))
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if not rel.alive:
			continue
		if int(rel.last_contact_year) < int(state.world.year):
			rel.closeness = clampi(int(rel.closeness) - close_decay, 0, 100)
			rel.contact = clampi(int(rel.contact) - contact_decay, 0, 100)
		rel.conflict = clampi(int(rel.conflict) - 1, 0, 100)
		_update_stage(state, id)

static func _update_stage(state: Dictionary, id: String) -> void:
	var rel: Dictionary = state.relationships.people[id]
	var rules: Dictionary = _rules(state)
	if rel.role in ["parent", "child", "spouse", "family"]:
		rel.stage = rel.role
		return
	if int(rel.conflict) >= int(rules.get("breakup_conflict_threshold", 72)) and rel.stage in ["dating", "romantic_interest"]:
		rel.stage = "ex_partner"
		rel.role = "ex_partner"
		state.relationships.history.append({"year": int(state.world.year), "kind": "breakup", "person_id": id})
		return
	if int(rel.closeness) <= int(rules.get("estranged_closeness_threshold", 15)):
		rel.stage = "estranged"
		return
	var player_age: int = int(state.actors[state.meta.player_id].age)
	if player_age >= int(rules.get("romance_min_age", 16)) and int(rel.attraction) >= int(rules.get("romance_attraction_threshold", 55)) and int(rel.closeness) >= int(rules.get("dating_threshold", 68)):
		if rel.stage not in ["dating", "ex_partner"]:
			rel.stage = "dating"
			rel.role = "partner"
			state.relationships.history.append({"year": int(state.world.year), "kind": "dating_started", "person_id": id})
		return
	if player_age >= int(rules.get("romance_min_age", 16)) and int(rel.attraction) >= int(rules.get("romance_attraction_threshold", 55)) and int(rel.closeness) >= int(rules.get("romance_closeness_threshold", 58)):
		if rel.stage not in ["dating", "ex_partner"]:
			rel.stage = "romantic_interest"
			rel.role = "romantic_interest"
			return
	if int(rel.closeness) >= int(rules.get("close_friend_threshold", 72)):
		rel.stage = "close_friend"
		rel.role = "friend"
	elif int(rel.closeness) >= int(rules.get("friendship_threshold", 50)):
		rel.stage = "friend"
		rel.role = "friend"
	elif rel.stage not in ["coworker", "rival"]:
		rel.stage = "acquaintance"
		rel.role = "acquaintance"

static func interact(state: Dictionary, id: String, kind: String) -> Dictionary:
	normalize(state)
	if not state.relationships.people.has(id):
		return {"ok": false, "error": "Unknown relationship"}
	var rel: Dictionary = state.relationships.people[id]
	var player: Dictionary = state.actors[state.meta.player_id]
	var axes: Dictionary = player.get("personality", {}).get("axes", {})
	if not rel.alive:
		return {"ok": false, "error": "Person is not alive"}
	match kind:
		"spend_time":
			rel.closeness += 9 + int(axes.get("sociability", 50)) / 25
			rel.trust += 4 + int(axes.get("empathy", 50)) / 35
			rel.contact += 10
			rel.conflict -= 2
		"talk":
			rel.closeness += 5 + int(axes.get("sociability", 50)) / 30
			rel.trust += 5 + int(axes.get("empathy", 50)) / 30
			rel.contact += 7
		"gift":
			rel.closeness += 7 + int(axes.get("empathy", 50)) / 30
			rel.trust += 2
		"argue":
			rel.conflict += 16 + maxi(0, int(axes.get("risk_tolerance", 50)) - 50) / 10
			rel.trust -= 8
			rel.closeness -= 5
		"apologize":
			rel.conflict -= 10 + int(axes.get("empathy", 50)) / 25
			rel.trust += 4 + int(axes.get("empathy", 50)) / 35
		"flirt":
			rel.closeness += 5 + int(axes.get("sociability", 50)) / 35
			rel.attraction += 6 + int(axes.get("risk_tolerance", 50)) / 35
			rel.conflict += 1
		_:
			return {"ok": false, "error": "Unknown interaction"}
	rel.last_contact_year = int(state.world.year)
	normalize(state)
	_update_stage(state, id)
	state.relationships.history.append({"year": int(state.world.year), "kind": kind, "person_id": id})
	return {"ok": true, "person_id": id, "stage": rel.stage}

static func spend_time_with_family(state: Dictionary) -> Dictionary:
	normalize(state)
	var changed: int = 0
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if rel.alive and rel.role in ["parent", "family", "child", "spouse"]:
			interact(state, id, "spend_time")
			changed += 1
	return {"changed": changed}

static func _nonfamily_count(state: Dictionary) -> int:
	var n: int = 0
	for id: String in state.relationships.people:
		if state.relationships.people[id].role not in ["parent", "family", "child", "spouse"]:
			n += 1
	return n

static func _eligible_pools(state: Dictionary) -> Array[Dictionary]:
	var player: Dictionary = state.actors[state.meta.player_id]
	var out: Array[Dictionary] = []
	for pool: Dictionary in _catalog(state).get("encounter_pools", []):
		if int(player.age) < int(pool.get("min_age", 0)) or int(player.age) > int(pool.get("max_age", 200)):
			continue
		if bool(pool.get("requires_employed", false)) and player.occupation_id == "dependent":
			continue
		out.append(pool)
	return out

static func meet_person(state: Dictionary, preferred_context: String = "") -> String:
	normalize(state)
	var rules: Dictionary = _rules(state)
	if _nonfamily_count(state) >= int(rules.get("max_active_nonfamily", 8)):
		return ""
	var pools: Array[Dictionary] = _eligible_pools(state)
	if pools.is_empty():
		return ""
	var seed: int = str(state.meta.master_seed).to_int()
	var year: int = int(state.world.year)
	var weights: Array[int] = []
	for pool: Dictionary in pools:
		weights.append(int(pool.get("weight", 1)) + (30 if preferred_context != "" and str(pool.id) == preferred_context else 0))
	var index: int = Rng.weighted(seed, "relationships", year, str(state.meta.player_id), "encounter_pool", weights)
	var pool: Dictionary = pools[index]
	var serial: int = state.relationships.people.size()
	var person_id: String = "social_%d_%d" % [year, serial]
	var names: Array = _catalog(state).get("first_names", [])
	var surnames: Array = _catalog(state).get("surnames", [])
	var first: String = "Person"
	var surname: String = ""
	if not names.is_empty():
		first = str(names[Rng.integer(seed, "relationships", year, person_id, "first_name", 0, names.size() - 1)])
	if not surnames.is_empty():
		surname = str(surnames[Rng.integer(seed, "relationships", year, person_id, "surname", 0, surnames.size() - 1)])
	var roles: Array = pool.get("roles", ["acquaintance"])
	var role: String = str(roles[Rng.integer(seed, "relationships", year, person_id, "role", 0, roles.size() - 1)])
	register_person(state, person_id, (first + " " + surname).strip_edges(), role, true, str(pool.id), "")
	var rel: Dictionary = state.relationships.people[person_id]
	rel.closeness = 38
	rel.trust = 30
	rel.contact = 35
	if role == "rival":
		rel.conflict = 35
	elif role == "coworker":
		rel.stage = "coworker"
	elif role == "romantic_interest":
		rel.attraction = maxi(60, int(rel.attraction))
		rel.stage = "romantic_interest"
	return person_id

static func socialize(state: Dictionary) -> Dictionary:
	normalize(state)
	var candidates: Array[String] = []
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if rel.alive and rel.role not in ["parent", "family", "child", "spouse", "ex_partner", "estranged"]:
			candidates.append(id)
	candidates.sort()
	if candidates.is_empty():
		var new_id: String = meet_person(state)
		return {"person_id": new_id, "new_person": new_id != ""}
	var seed: int = str(state.meta.master_seed).to_int()
	var pick: int = Rng.integer(seed, "relationships", int(state.world.year), str(state.meta.player_id), "social_target", 0, candidates.size() - 1)
	var id: String = candidates[pick]
	interact(state, id, "spend_time")
	return {"person_id": id, "new_person": false}

static func best_partner_candidate(state: Dictionary) -> String:
	normalize(state)
	var best: String = ""
	var best_score: int = -1
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if not rel.alive or rel.stage not in ["romantic_interest", "dating"]:
			continue
		var score: int = int(rel.closeness) + int(rel.trust) + int(rel.attraction) + int(rel.compatibility) - int(rel.conflict) * 2
		if score > best_score:
			best_score = score
			best = id
	return best
