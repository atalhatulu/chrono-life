extends RefCounted

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path := str(state.get("meta", {}).get("personality_path", ""))
	if path.is_empty():
		return {"axes": [], "action_deltas": {}, "thresholds": []}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"axes": [], "action_deltas": {}, "thresholds": []}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"axes": [], "action_deltas": {}, "thresholds": []}
	return _cache[path]

static func initialize_actor(state: Dictionary, actor: Dictionary) -> void:
	if not actor.has("personality"):
		actor.personality = {"axes": {}, "history": []}
	for axis: Dictionary in _catalog(state).get("axes", []):
		if not actor.personality.axes.has(axis.id):
			actor.personality.axes[axis.id] = int(axis.get("default", 50))
	_update_traits(state, actor)

static func _update_traits(state: Dictionary, actor: Dictionary) -> void:
	var preserved: Array = []
	for trait: Variant in actor.get("traits", []):
		if str(trait) in ["education_first", "pragmatic"]:
			preserved.append(trait)
	for threshold: Dictionary in _catalog(state).get("thresholds", []):
		var value := int(actor.personality.axes.get(threshold.axis, 50))
		var pass := true
		if threshold.has("min") and value < int(threshold.min):
			pass = false
		if threshold.has("max") and value > int(threshold.max):
			pass = false
		if pass and threshold.trait not in preserved:
			preserved.append(threshold.trait)
	actor.traits = preserved

static func apply_action(state: Dictionary, actor_id: String, action_id: String) -> void:
	if not state.actors.has(actor_id):
		return
	var actor: Dictionary = state.actors[actor_id]
	initialize_actor(state, actor)
	var deltas: Dictionary = _catalog(state).get("action_deltas", {}).get(action_id, {})
	if deltas.is_empty():
		return
	for axis: String in deltas:
		if actor.personality.axes.has(axis):
			actor.personality.axes[axis] = clampi(int(actor.personality.axes[axis]) + int(deltas[axis]), 0, 100)
	actor.personality.history.append({"year": int(state.world.year), "source": "action:" + action_id,
		"deltas": deltas.duplicate(true)})
	_update_traits(state, actor)

static func annual_drift(state: Dictionary, actor: Dictionary) -> void:
	initialize_actor(state, actor)
	for axis: String in actor.personality.axes:
		var v := int(actor.personality.axes[axis])
		if v > 50:
			actor.personality.axes[axis] = v - 1
		elif v < 50:
			actor.personality.axes[axis] = v + 1
	_update_traits(state, actor)
