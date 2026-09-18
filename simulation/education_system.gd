extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static var _cache: Dictionary = {}

static func _path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("education_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path := _path(state)
	if path.is_empty():
		return {"stages": []}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"stages": []}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"stages": []}
	return _cache[path]

static func initialize_actor(actor: Dictionary) -> void:
	if not actor.has("education"):
		actor.education = {
			"current_stage": "",
			"completed_stages": [],
			"attendance": 0,
			"performance": 50,
			"progress": 0,
			"dropout_count": 0,
			"history": []
		}

static func _stage_by_id(state: Dictionary, stage_id: String) -> Dictionary:
	for stage: Dictionary in _catalog(state).get("stages", []):
		if str(stage.id) == stage_id:
			return stage
	return {}

static func _eligible_for_stage(actor: Dictionary, stage: Dictionary) -> bool:
	return actor.alive and int(actor.age) >= int(stage.get("min_age", 0)) and int(actor.age) <= int(stage.get("max_age", 200))

static func _sync_legacy(actor: Dictionary) -> void:
	var current := str(actor.education.get("current_stage", ""))
	if current == "":
		if actor.education.completed_stages.has("elementary"):
			actor.education_state = "completed"
		elif int(actor.education.dropout_count) > 0:
			actor.education_state = "interrupted"
		else:
			actor.education_state = "none"
	elif current == "elementary":
		actor.education_state = "basic_schooling"

static func advance(delta: RefCounted, pack: Dictionary, cause: String) -> void:
	if not pack.systems.get("education", false):
		return
	var state: Dictionary = delta.candidate
	var seed := str(state.meta.master_seed).to_int()
	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)
		var current_id := str(actor.education.current_stage)
		if current_id == "":
			for stage: Dictionary in _catalog(state).get("stages", []):
				if str(stage.get("enrollment", "")) != "automatic_if_dependent":
					continue
				if not _eligible_for_stage(actor, stage):
					continue
				if actor.occupation_id != "dependent":
					continue
				var ev := delta.record("education_started", cause, {"actor_id": id, "stage_id": stage.id})
				actor.education.current_stage = str(stage.id)
				actor.education.progress = 0
				actor.education.history.append({"year": delta.year, "kind": "started", "stage_id": stage.id})
				delta.set_field("actors", "education_state", "basic_schooling" if stage.id == "elementary" else "none", ev, id)
				current_id = str(stage.id)
				break
		if current_id == "":
			_sync_legacy(actor)
			continue
		var stage := _stage_by_id(state, current_id)
		if stage.is_empty():
			_sync_legacy(actor)
			continue
		if not _eligible_for_stage(actor, stage) or actor.occupation_id != "dependent":
			var ev := delta.record("education_interrupted", cause, {"actor_id": id, "stage_id": current_id})
			actor.education.current_stage = ""
			actor.education.dropout_count = int(actor.education.dropout_count) + 1
			actor.education.history.append({"year": delta.year, "kind": "interrupted", "stage_id": current_id})
			delta.set_field("actors", "education_state", "interrupted", ev, id)
			continue
		if int(actor.health) < int(stage.get("minimum_health", 0)):
			actor.education.attendance = maxi(0, int(actor.education.attendance) - 15)
			_sync_legacy(actor)
			continue
		var attendance := int(stage.get("attendance_base", 60))
		if int(state.household.food_security) < 800:
			attendance -= 12
		if int(state.household.debt) > 0:
			attendance -= 6
		attendance += Rng.integer(seed, "education", delta.year, id, current_id + ":attendance", -10, 10)
		attendance = clampi(attendance, 0, 100)
		actor.education.attendance = attendance
		var performance := clampi(int(actor.willpower) / 2 + int(actor.literacy) / 3 + attendance / 3, 0, 100)
		actor.education.performance = performance
		var gained := int(stage.get("progress_per_year", 10)) * attendance / 100
		actor.education.progress = mini(100, int(actor.education.progress) + gained)
		var literacy_gain := int(stage.get("literacy_per_year", 0)) * attendance / 100
		if literacy_gain > 0:
			delta.set_field("actors", "literacy", mini(100, int(actor.literacy) + literacy_gain), cause, id)
		var completion_age := int(stage.get("completion_age", int(stage.get("max_age", 200)) + 1))
		if int(actor.education.progress) >= 100 or int(actor.age) >= completion_age:
			var ev := delta.record("education_completed", cause, {"actor_id": id, "stage_id": current_id})
			if not actor.education.completed_stages.has(current_id):
				actor.education.completed_stages.append(current_id)
			actor.education.current_stage = ""
			actor.education.progress = 100
			actor.education.history.append({"year": delta.year, "kind": "completed", "stage_id": current_id})
			delta.set_field("actors", "education_state", "completed" if current_id == "elementary" else actor.education_state, ev, id)
		_sync_legacy(actor)
