extends RefCounted

const Skills = preload("res://simulation/skill_system.gd")

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = str(state.get("meta", {}).get("hobbies_path", ""))
	if path.is_empty():
		return {"hobbies": [], "action_hobby_links": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"hobbies": [], "action_hobby_links": {}}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"hobbies": [], "action_hobby_links": {}}
	return _cache[path]

static func initialize_actor(actor: Dictionary) -> void:
	if not actor.has("hobbies"):
		actor.hobbies = {"active": {}, "history": []}

static func _by_id(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for h: Dictionary in _catalog(state).get("hobbies", []):
		out[h.id] = h
	return out

static func practice(state: Dictionary, actor_id: String, hobby_id: String, source: String = "manual") -> Dictionary:
	if not state.actors.has(actor_id):
		return {"ok": false, "error": "Unknown actor"}
	var actor: Dictionary = state.actors[actor_id]
	initialize_actor(actor)
	var defs: Dictionary = _by_id(state)
	if not defs.has(hobby_id) or int(actor.age) < int(defs[hobby_id].get("min_age", 0)):
		return {"ok": false, "error": "Hobby unavailable"}
	var progress: Dictionary = actor.hobbies.active.get(hobby_id, {
		"years": 0, "sessions": 0, "mastery": 0, "last_year": -1
	})
	if int(progress.last_year) == int(state.world.year):
		return {"ok": false, "error": "This hobby was already practiced this year"}
	progress.sessions = int(progress.sessions) + 1
	progress.years = int(progress.years) + 1
	progress.last_year = int(state.world.year)
	progress.mastery = clampi(int(progress.mastery) + 2 + int(progress.years) / 3, 0, 100)
	actor.hobbies.active[hobby_id] = progress
	var def: Dictionary = defs[hobby_id]
	for skill_id: String in def.get("skill_xp", {}):
		Skills.add_xp(state, actor_id, skill_id, int(def.skill_xp[skill_id]), "hobby:" + hobby_id)
	for key: String in def.get("need_effects", {}):
		if actor.has("needs") and actor.needs.has(key):
			actor.needs[key] = clampi(int(actor.needs[key]) + int(def.need_effects[key]), 0, 100)
	actor.hobbies.history.append({"year": int(state.world.year), "hobby_id": hobby_id, "source": source})
	return {"ok": true, "hobby_id": hobby_id}

static func apply_action_link(state: Dictionary, actor_id: String, action_id: String) -> void:
	var hobby_id: String = str(_catalog(state).get("action_hobby_links", {}).get(action_id, ""))
	if hobby_id != "":
		practice(state, actor_id, hobby_id, "action:" + action_id)


static func available_hobbies(state: Dictionary, actor_id: String = "") -> Array[Dictionary]:
	if actor_id == "":
		actor_id = str(state.meta.player_id)
	if not state.actors.has(actor_id):
		return []
	var actor: Dictionary = state.actors[actor_id]
	var result: Array[Dictionary] = []
	for hobby: Dictionary in _catalog(state).get("hobbies", []):
		if int(actor.age) >= int(hobby.get("min_age", 0)):
			result.append(hobby)
	return result
