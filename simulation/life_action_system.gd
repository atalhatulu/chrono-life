extends RefCounted

const Needs = preload("res://simulation/needs_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Skills = preload("res://simulation/skill_system.gd")
const Hobbies = preload("res://simulation/hobby_system.gd")
const Personality = preload("res://simulation/personality_system.gd")

static var _catalog_cache: Dictionary = {}

static func _catalog_path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("life_actions_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = _catalog_path(state)
	if path.is_empty():
		return {"actions": []}
	if _catalog_cache.has(path):
		return _catalog_cache[path]
	if not FileAccess.file_exists(path):
		return {"actions": []}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_catalog_cache[path] = parsed
	else:
		_catalog_cache[path] = {"actions": []}
	return _catalog_cache[path]

static func actions_by_id(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for action: Dictionary in _catalog(state).get("actions", []):
		out[action.id] = action
	return out

static func available_actions(state: Dictionary) -> Array[String]:
	var player: Dictionary = state.actors[state.meta.player_id]
	PersonalEconomy.normalize(state)
	var result: Array[String] = []
	if not player.alive:
		return result
	for action: Dictionary in _catalog(state).get("actions", []):
		var id: String = str(action.id)
		if int(player.age) < int(action.get("min_age", 0)) or int(player.age) > int(action.get("max_age", 200)):
			continue
		var req: Dictionary = action.get("requirements", {})
		if bool(req.get("employed", false)) and player.occupation_id == "dependent":
			continue
		if int(action.get("cash_cost", 0)) > int(state.personal_economy.cash):
			continue
		result.append(id)
	result.sort()
	return result

static func apply(state: Dictionary, action_id: String) -> Dictionary:
	if action_id not in available_actions(state):
		return {"ok": false, "error": "Action is not currently available: " + action_id}
	var by_id: Dictionary = actions_by_id(state)
	var action: Dictionary = by_id[action_id]
	var player: Dictionary = state.actors[state.meta.player_id]
	Needs.normalize_actor(player)
	var cash_cost: int = int(action.get("cash_cost", 0))
	if cash_cost > 0:
		var spend_result: Dictionary = PersonalEconomy.spend(state, cash_cost, "life_action", action_id)
		if not spend_result.ok:
			return spend_result
	var effects: Dictionary = action.get("effects", {})
	for key: String in ["health", "literacy", "willpower"]:
		if effects.has(key):
			player[key] = clampi(int(player[key]) + int(effects[key]), 0, 100)
	for key: String in ["happiness", "stress", "social", "energy"]:
		if effects.has(key):
			player.needs[key] = clampi(int(player.needs[key]) + int(effects[key]), 0, 100)
	Skills.apply_action(state, str(player.id), action_id)
	Hobbies.apply_action_link(state, str(player.id), action_id)
	Personality.apply_action(state, str(player.id), action_id)
	for hook: String in action.get("hooks", []):
		if hook == "family_time":
			Relationships.spend_time_with_family(state)
		elif hook == "socialize":
			Relationships.socialize(state)
	state.history.append({"id": "%d:life_action:%s:%d" % [int(state.world.year), action_id, state.history.size()],
		"year": int(state.world.year), "kind": "life_action", "cause_id": "",
		"details": {"actor_id": player.id, "action_id": action_id}})
	return {"ok": true, "action_id": action_id}
