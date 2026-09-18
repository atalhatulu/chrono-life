extends RefCounted

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = str(state.get("meta", {}).get("skills_path", ""))
	if path.is_empty():
		return {"skills": [], "action_skill_xp": {}}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"skills": [], "action_skill_xp": {}}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"skills": [], "action_skill_xp": {}}
	return _cache[path]

static func initialize_actor(state: Dictionary, actor: Dictionary) -> void:
	if not actor.has("skills"):
		actor.skills = {"values": {}, "xp": {}, "history": []}
	for definition: Dictionary in _catalog(state).get("skills", []):
		var id: String = str(definition.id)
		if not actor.skills["values"].has(id):
			actor.skills["values"][id] = 0
			actor.skills["xp"][id] = 0

static func definitions(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d: Dictionary in _catalog(state).get("skills", []):
		out[d.id] = d
	return out

static func add_xp(state: Dictionary, actor_id: String, skill_id: String, amount: int, source: String) -> void:
	if not state.actors.has(actor_id) or amount <= 0:
		return
	var actor: Dictionary = state.actors[actor_id]
	initialize_actor(state, actor)
	var defs: Dictionary = definitions(state)
	if not defs.has(skill_id):
		return
	var xp: int = int(actor.skills["xp"].get(skill_id, 0)) + amount
	var value: int = int(actor.skills["values"].get(skill_id, 0))
	while xp >= 10 + value * 2 and value < int(defs[skill_id].get("max_level", 100)):
		xp -= 10 + value * 2
		value += 1
	actor.skills["xp"][skill_id] = xp
	actor.skills["values"][skill_id] = value
	actor.skills["history"].append({"year": int(state.world.year), "skill_id": skill_id,
		"xp": amount, "source": source, "value": value})

static func apply_action(state: Dictionary, actor_id: String, action_id: String) -> void:
	for skill_id: String in _catalog(state).get("action_skill_xp", {}).get(action_id, {}):
		add_xp(state, actor_id, skill_id,
			int(_catalog(state).action_skill_xp[action_id][skill_id]), "action:" + action_id)
