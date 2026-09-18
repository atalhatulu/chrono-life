extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Health = preload("res://simulation/health_system.gd")

static var _cache: Dictionary = {}

static func _path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("health_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path := _path(state)
	if path.is_empty():
		return {"conditions": [], "treatments": [], "medical_context": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"conditions": [], "treatments": [], "medical_context": {}}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"conditions": [], "treatments": [], "medical_context": {}}
	return _cache[path]

static func _definitions(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d: Dictionary in _catalog(state).get("conditions", []):
		out[d.id] = d
	return out

static func available_treatments(state: Dictionary, actor_id: String = "") -> Array[Dictionary]:
	if actor_id == "":
		actor_id = str(state.meta.player_id)
	if not state.actors.has(actor_id):
		return []
	var actor: Dictionary = state.actors[actor_id]
	if not actor.alive or actor.conditions.is_empty():
		return []
	PersonalEconomy.normalize(state)
	var defs := _definitions(state)
	var medical: Dictionary = _catalog(state).get("medical_context", {})
	var base_access := int(medical.get("public_access", 0))
	var wealth_access := mini(40, int(state.personal_economy.cash) / 10)
	var access := base_access + wealth_access
	var out: Array[Dictionary] = []
	for treatment: Dictionary in _catalog(state).get("treatments", []):
		if int(actor.age) < int(treatment.get("min_age", 0)):
			continue
		if int(treatment.get("cost", 0)) > int(state.personal_economy.cash):
			continue
		if int(treatment.get("access_requirement", 0)) > access:
			continue
		var tags: Array = treatment.get("tags", [])
		var matches := false
		for condition_id: String in actor.conditions:
			if not defs.has(condition_id):
				continue
			for tag: Variant in defs[condition_id].get("treatment_tags", []):
				if tag in tags:
					matches = true
					break
			if matches:
				break
		if matches:
			out.append(treatment)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.cost) < int(b.cost))
	return out

static func apply(state: Dictionary, treatment_id: String, actor_id: String = "") -> Dictionary:
	if actor_id == "":
		actor_id = str(state.meta.player_id)
	var selected: Dictionary = {}
	for t: Dictionary in available_treatments(state, actor_id):
		if str(t.id) == treatment_id:
			selected = t
			break
	if selected.is_empty():
		return {"ok": false, "error": "Treatment is not available"}

	var spend := PersonalEconomy.spend(state, int(selected.cost), "health", treatment_id)
	if not spend.ok:
		return spend

	var actor: Dictionary = state.actors[actor_id]
	Health.initialize_actor(actor)
	var defs := _definitions(state)
	var seed := str(state.meta.master_seed).to_int()
	var year := int(state.world.year)
	var affected: Array[String] = []
	var cured: Array[String] = []
	var success_count := 0
	for condition_id: String in actor.conditions.keys():
		if not defs.has(condition_id):
			continue
		var definition: Dictionary = defs[condition_id]
		var compatible := false
		for tag: Variant in definition.get("treatment_tags", []):
			if tag in selected.get("tags", []):
				compatible = true
				break
		if not compatible:
			continue
		affected.append(condition_id)
		var success := Rng.integer(seed, "treatment", year, actor_id,
			treatment_id + ":" + condition_id, 0, 9999) < int(selected.get("success_bp", 0))
		if not success:
			continue
		success_count += 1
		var condition: Dictionary = actor.conditions[condition_id]
		condition.severity = maxi(0, int(condition.get("severity", 50)) - int(selected.get("severity_reduction", 0)))
		condition.treated_this_year = true
		if int(condition.severity) <= 10 and str(definition.get("kind", "")) != "chronic":
			actor.conditions.erase(condition_id)
			cured.append(condition_id)

	actor.health = clampi(int(actor.health) + int(selected.get("health_restore", 0)) * success_count, 1, 100)
	actor.health_profile.last_treatment_year = year
	var record := {
		"year": year, "treatment_id": treatment_id, "affected": affected,
		"cured": cured, "success_count": success_count, "cost": int(selected.cost)
	}
	actor.health_profile.treatment_history.append(record)
	state.history.append({
		"id": "%d:treatment:%s:%d" % [year, treatment_id, state.history.size()],
		"year": year, "kind": "treatment", "cause_id": "", "details": record
	})
	return {"ok": true, "treatment": selected, "affected": affected, "cured": cured,
		"success_count": success_count}
