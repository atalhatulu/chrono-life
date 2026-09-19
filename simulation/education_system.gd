extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")

static var _cache: Dictionary = {}

static func _path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("education_path", ""))

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = _path(state)
	if path.is_empty():
		return {"stages": []}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"stages": []}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
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

static func _household_context(state: Dictionary, actor: Dictionary) -> Dictionary:
	var household_id: String = str(actor.get("household_id", ""))
	if household_id == str(state.household.id):
		return state.household
	return state.get("households", {}).get(household_id, {"food_security": 1000, "debt": 0, "savings": 0})

static func _sync_legacy(actor: Dictionary) -> void:
	var current: String = str(actor.education.get("current_stage", ""))
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
	var seed: int = str(state.meta.master_seed).to_int()
	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)
		var current_id: String = str(actor.education.current_stage)
		if current_id == "":
			for stage: Dictionary in _catalog(state).get("stages", []):
				if str(stage.id) in actor.education.completed_stages:
					continue
				if str(stage.get("enrollment", "")) != "automatic_if_dependent":
					continue
				if not _eligible_for_stage(actor, stage):
					continue
				if actor.occupation_id != "dependent":
					continue
				var ev: String = delta.record("education_started", cause, {"actor_id": id, "stage_id": stage.id})
				actor.education.current_stage = str(stage.id)
				actor.education.progress = 0
				actor.education.history.append({"year": delta.year, "kind": "started", "stage_id": stage.id})
				delta.set_field("actors", "education_state", "basic_schooling" if stage.id == "elementary" else "none", ev, id)
				current_id = str(stage.id)
				break
		if current_id == "":
			_sync_legacy(actor)
			continue
		var stage: Dictionary = _stage_by_id(state, current_id)
		if stage.is_empty():
			_sync_legacy(actor)
			continue
		# Enrollment ends at max_age, but graduation can be the next birthday.
		var completion_age: int = int(stage.get("completion_age", int(stage.get("max_age", 200)) + 1))
		if int(actor.age) >= completion_age and actor.occupation_id == "dependent":
			_complete(delta, actor, id, current_id, cause)
			continue
		if not _eligible_for_stage(actor, stage) or actor.occupation_id != "dependent":
			var ev: String = delta.record("education_interrupted", cause, {"actor_id": id, "stage_id": current_id})
			actor.education.current_stage = ""
			actor.education.dropout_count = int(actor.education.dropout_count) + 1
			actor.education.history.append({"year": delta.year, "kind": "interrupted", "stage_id": current_id})
			delta.set_field("actors", "education_state", "interrupted", ev, id)
			continue
		if int(actor.health) < int(stage.get("minimum_health", 0)):
			actor.education.attendance = maxi(0, int(actor.education.attendance) - 15)
			_sync_legacy(actor)
			continue
		var attendance: int = int(stage.get("attendance_base", 60))
		var household_context: Dictionary = _household_context(state, actor)
		if int(household_context.get("food_security", 1000)) < 800:
			attendance -= 12
		if int(household_context.get("debt", 0)) > 0:
			attendance -= 6
		attendance += Rng.integer(seed, "education", delta.year, id, current_id + ":attendance", -10, 10)
		attendance = clampi(attendance, 0, 100)
		actor.education.attendance = attendance
		var performance: int = clampi(int(actor.willpower) / 2 + int(actor.literacy) / 3 + attendance / 3, 0, 100)
		actor.education.performance = performance
		var gained: int = int(stage.get("progress_per_year", 10)) * attendance / 100
		actor.education.progress = mini(100, int(actor.education.progress) + gained)
		var literacy_gain: int = int(stage.get("literacy_per_year", 0))
		if literacy_gain > 0:
			delta.set_field("actors", "literacy", mini(100, int(actor.literacy) + literacy_gain), cause, id)
		if int(actor.education.progress) >= 100 or int(actor.age) >= completion_age:
			_complete(delta, actor, id, current_id, cause)
		_sync_legacy(actor)


static func _complete(delta: RefCounted, actor: Dictionary, id: String, stage_id: String, cause: String) -> void:
	var ev: String = delta.record("education_completed", cause, {"actor_id": id, "stage_id": stage_id})
	if stage_id not in actor.education.completed_stages:
		actor.education.completed_stages.append(stage_id)
	actor.education.current_stage = ""
	actor.education.progress = 100
	actor.education.history.append({"year": delta.year, "kind": "completed", "stage_id": stage_id})
	delta.set_field("actors", "education_state", "completed" if stage_id == "elementary" else actor.education_state, ev, id)


static func available_stages(state: Dictionary) -> Array[Dictionary]:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	initialize_actor(player)
	var current: String = str(player.education.get("current_stage", ""))
	var completed: Array = player.education.get("completed_stages", [])
	var out: Array[Dictionary] = []
	for stage: Dictionary in _catalog(state).get("stages", []):
		var sid: String = str(stage.id)
		if sid == current or sid in completed:
			continue
		if not _eligible_for_stage(player, stage):
			continue
		out.append(stage)
	return out


static func enroll_stage(state: Dictionary, stage_id: String) -> Dictionary:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	if not player.alive:
		return {"ok": false, "error": "Karakter hayatta değil."}
	initialize_actor(player)
	if str(player.education.current_stage) == stage_id:
		return {"ok": false, "error": "Zaten bu eğitime devam ediyorsun."}
	if stage_id in player.education.completed_stages:
		return {"ok": false, "error": "Bu eğitimi zaten tamamladın."}
	var stage: Dictionary = _stage_by_id(state, stage_id)
	if stage.is_empty():
		return {"ok": false, "error": "Bilinmeyen eğitim aşaması."}
	if not _eligible_for_stage(player, stage):
		return {"ok": false, "error": "Yaşın veya durumun bu eğitim aşamasına uygun değil."}
	var cur_year: int = int(state.world.year)
	player.education.current_stage = stage_id
	player.education.progress = 0
	player.education.attendance = int(stage.get("attendance_base", 50))
	player.education.history.append({"year": cur_year, "kind": "started", "stage_id": stage_id})
	state.history.append({
		"id": "%d:education_started:%s:%d" % [cur_year, stage_id, state.history.size()],
		"year": cur_year,
		"kind": "education_started",
		"cause_id": "",
		"details": {"actor_id": player_id, "stage_id": stage_id}
	})
	_sync_legacy(player)
	SocialStatus.recompute(state)
	return {"ok": true, "stage_id": stage_id}


static func leave_education(state: Dictionary) -> Dictionary:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	if not player.alive:
		return {"ok": false, "error": "Karakter hayatta değil."}
	initialize_actor(player)
	var current: String = str(player.education.get("current_stage", ""))
	if current == "":
		return {"ok": false, "error": "Zaten aktif bir eğitim almıyorsun."}
	var cur_year: int = int(state.world.year)
	player.education.current_stage = ""
	player.education.dropout_count = int(player.education.get("dropout_count", 0)) + 1
	player.education.history.append({"year": cur_year, "kind": "interrupted", "stage_id": current})
	state.history.append({
		"id": "%d:education_interrupted:%s:%d" % [cur_year, current, state.history.size()],
		"year": cur_year,
		"kind": "education_interrupted",
		"cause_id": "",
		"details": {"actor_id": player_id, "stage_id": current}
	})
	_sync_legacy(player)
	SocialStatus.recompute(state)
	return {"ok": true}
