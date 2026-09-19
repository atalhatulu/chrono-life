extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")

static var _careers_cache: Dictionary = {}

static func _catalog_path(state: Dictionary) -> String:
	return str(state.get("meta", {}).get("careers_path", ""))

static func catalog_jobs(state: Dictionary) -> Dictionary:
	var path: String = _catalog_path(state)
	if path.is_empty():
		return {}
	if _careers_cache.has(path):
		return _careers_cache[path]
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var out: Dictionary = {}
	if parsed is Dictionary and parsed.has("jobs"):
		for j: Dictionary in parsed.jobs:
			out[str(j.id)] = j
	_careers_cache[path] = out
	return out

static func missing_requirements(actor: Dictionary, job: Dictionary, target_age: int) -> Array[String]:
	var reasons: Array[String] = []
	if not actor.alive:
		reasons.append("Karakter hayatta değil")
		return reasons
	if target_age < int(job.get("minimum_age", 0)):
		reasons.append("Yaş en az %d olmalı (Şu an %d)" % [int(job.minimum_age), target_age])
	if target_age > int(job.get("maximum_age", 200)):
		reasons.append("Azami yaş sınırı (%d) aşıldı" % int(job.maximum_age))
	if int(actor.literacy) < int(job.get("minimum_literacy", 0)):
		reasons.append("Okuma en az %d olmalı (Şu an %d)" % [int(job.minimum_literacy), int(actor.literacy)])
	if int(actor.get("work_capacity", 1000)) <= 0 and int(job.get("annual_income", 0)) > 0:
		reasons.append("Çalışma kapasitesi yetersiz")
	var required_skills: Dictionary = job.get("required_skills", {})
	for skill_id: String in required_skills:
		var cur_skill: int = int(actor.get("skills", {}).get("values", {}).get(skill_id, 0))
		if cur_skill < int(required_skills[skill_id]):
			reasons.append("%s becerisi en az %d olmalı (Şu an %d)" % [skill_id.capitalize(), int(required_skills[skill_id]), cur_skill])
	var required_stages: Array = job.get("required_education_stages", [])
	var completed: Array = _completed_education(actor)
	for stage: Variant in required_stages:
		if stage not in completed:
			reasons.append("Gereken eğitim: %s" % str(stage).capitalize())
	var track: String = str(job.get("career_track", ""))
	var required_exp: int = int(job.get("minimum_experience_years", 0))
	initialize_actor(actor)
	var cur_exp: int = int(actor.career.track_experience.get(track, 0))
	if required_exp > 0 and cur_exp < required_exp:
		reasons.append("%s alanında %d yıl deneyim gerekli (Şu an %d yıl)" % [track.capitalize(), required_exp, cur_exp])
	return reasons

static func apply_for_job(state: Dictionary, job_id: String) -> Dictionary:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	if not player.alive:
		return {"ok": false, "error": "Karakter hayatta değil."}
	var jobs: Dictionary = catalog_jobs(state)
	if not jobs.has(job_id):
		return {"ok": false, "error": "Bilinmeyen meslek: " + job_id}
	var target_job: Dictionary = jobs[job_id]
	if not eligible(player, target_job, int(player.age)):
		var missing: Array[String] = missing_requirements(player, target_job, int(player.age))
		var err_msg: String = "Gereksinimler karşılanmıyor: " + ", ".join(missing)
		return {"ok": false, "error": err_msg}
	if str(player.occupation_id) == job_id:
		return {"ok": false, "error": "Zaten bu meslektesin."}

	var old_job: String = str(player.occupation_id)
	initialize_actor(player)
	player.occupation_id = job_id
	player.career.current_job = job_id
	player.career.job_changes = int(player.career.job_changes) + 1
	player.career.highest_level = maxi(int(player.career.highest_level), int(target_job.get("level", 0)))
	var cur_year: int = int(state.world.year)
	player.career.history.append({"year": cur_year, "kind": "started", "occupation_id": job_id})
	state.history.append({
		"id": "%d:occupation_started:%s:%d" % [cur_year, job_id, state.history.size()],
		"year": cur_year,
		"kind": "occupation_started",
		"cause_id": "",
		"details": {"actor_id": player_id, "occupation_id": job_id, "previous_occupation_id": old_job}
	})
	var econ_index: int = int(state.world.economy_index)
	var capacity: int = int(player.get("work_capacity", 1000))
	player.income = int(int(target_job.annual_income) * econ_index * capacity / 1000000.0)
	SocialStatus.recompute(state)
	return {"ok": true, "occupation_id": job_id}

static func resign_job(state: Dictionary) -> Dictionary:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	if not player.alive:
		return {"ok": false, "error": "Karakter hayatta değil."}
	if str(player.occupation_id) == "dependent":
		return {"ok": false, "error": "Zaten çalışmıyorsun."}
	var old_job: String = str(player.occupation_id)
	initialize_actor(player)
	player.occupation_id = "dependent"
	player.career.current_job = "dependent"
	var cur_year: int = int(state.world.year)
	player.career.history.append({"year": cur_year, "kind": "ended", "occupation_id": old_job, "reason": "resignation"})
	state.history.append({
		"id": "%d:occupation_ended:%d" % [cur_year, state.history.size()],
		"year": cur_year,
		"kind": "occupation_ended",
		"cause_id": "",
		"details": {"actor_id": player_id, "occupation_id": old_job, "reason": "resignation"}
	})
	player.income = 0
	SocialStatus.recompute(state)
	return {"ok": true}


static func initialize_actor(actor: Dictionary) -> void:
	if not actor.has("career"):
		actor.career = {
			"current_job": str(actor.get("occupation_id", "dependent")),
			"experience_years": 0,
			"track_experience": {},
			"highest_level": 0,
			"job_changes": 0,
			"history": []
		}

static func _completed_education(actor: Dictionary) -> Array:
	if actor.has("education"):
		return actor.education.get("completed_stages", [])
	return []

static func eligible(actor: Dictionary, job: Dictionary, target_age: int, require_work_capacity: bool = true) -> bool:
	if not actor.alive:
		return false
	if target_age < int(job.get("minimum_age", 0)) or target_age > int(job.get("maximum_age", 200)):
		return false
	if int(actor.literacy) < int(job.get("minimum_literacy", 0)):
		return false
	if int(job.get("annual_income", 0)) == 0:
		return true
	if require_work_capacity and int(actor.work_capacity) <= 0:
		return false
	var required_skills: Dictionary = job.get("required_skills", {})
	for skill_id: String in required_skills:
		if int(actor.get("skills", {}).get("values", {}).get(skill_id, 0)) < int(required_skills[skill_id]):
			return false
	var required: Array = job.get("required_education_stages", [])
	var completed: Array = _completed_education(actor)
	for stage: Variant in required:
		if stage not in completed:
			return false
	initialize_actor(actor)
	var track: String = str(job.get("career_track", ""))
	var required_exp: int = int(job.get("minimum_experience_years", 0))
	if required_exp > 0 and int(actor.career.track_experience.get(track, 0)) < required_exp:
		return false
	return true

static func available_jobs(actor: Dictionary, jobs: Dictionary, target_age: int) -> Array:
	var ids: Array = jobs.keys()
	ids.sort()
	var result: Array = []
	for id: String in ids:
		var job: Dictionary = jobs[id]
		if int(job.get("annual_income", 0)) > 0 and eligible(actor, job, target_age):
			result.append(id)
	return result

static func _record_job_end(delta: RefCounted, id: String, reason: String, cause: String) -> void:
	var actor: Dictionary = delta.candidate.actors[id]
	if actor.occupation_id == "dependent":
		return
	initialize_actor(actor)
	var event: String = delta.record("occupation_ended", cause, {"actor_id": id, "occupation_id": actor.occupation_id, "reason": reason})
	actor.career.history.append({"year": delta.year, "kind": "ended", "occupation_id": actor.occupation_id, "reason": reason})
	actor.career.current_job = "dependent"
	delta.set_field("actors", "occupation_id", "dependent", event, id)

static func start_job(delta: RefCounted, id: String, job_id: String, cause: String, jobs: Dictionary = {}) -> void:
	var actor: Dictionary = delta.candidate.actors[id]
	initialize_actor(actor)
	var old_job: String = str(actor.occupation_id)
	var event: String = delta.record("occupation_started", cause, {"actor_id": id, "occupation_id": job_id, "previous_occupation_id": old_job})
	delta.set_field("actors", "occupation_id", job_id, event, id)
	actor.career.current_job = job_id
	actor.career.job_changes = int(actor.career.job_changes) + 1
	if jobs.has(job_id):
		actor.career.highest_level = maxi(int(actor.career.highest_level), int(jobs[job_id].get("level", 0)))
	actor.career.history.append({"year": delta.year, "kind": "started", "occupation_id": job_id})
	if actor.education_state == "basic_schooling":
		var school_event: String = delta.record("school_interrupted", event, {"actor_id": id})
		delta.set_field("actors", "education_state", "interrupted", school_event, id)
		if actor.has("education"):
			var stage_id: String = str(actor.education.get("current_stage", ""))
			actor.education.current_stage = ""
			actor.education.dropout_count = int(actor.education.get("dropout_count", 0)) + 1
			actor.education.history.append({"year": delta.year, "kind": "interrupted", "stage_id": stage_id})

static func _advance_experience(state: Dictionary, jobs: Dictionary) -> void:
	for id: String in state.actors:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)
		if actor.occupation_id == "dependent" or not jobs.has(actor.occupation_id):
			continue
		actor.career.experience_years = int(actor.career.experience_years) + 1
		var track = str(jobs[actor.occupation_id].get("career_track", ""))
		if track != "":
			actor.career.track_experience[track] = int(actor.career.track_experience.get(track, 0)) + 1

static func _promotion_candidates(actor: Dictionary, jobs: Dictionary) -> Array[String]:
	if actor.occupation_id == "dependent" or not jobs.has(actor.occupation_id):
		return []
	var current: Dictionary = jobs[actor.occupation_id]
	var current_track: String = str(current.get("career_track", ""))
	var current_level: int = int(current.get("level", 0))
	var result: Array[String] = []
	for id: String in jobs:
		var job: Dictionary = jobs[id]
		if str(job.get("career_track", "")) != current_track:
			continue
		if int(job.get("level", 0)) <= current_level:
			continue
		if eligible(actor, job, int(actor.age)):
			result.append(id)
	result.sort_custom(func(a: String, b: String): return int(jobs[a].get("level", 0)) < int(jobs[b].get("level", 0)))
	return result

static func prepare(delta: RefCounted, pack: Dictionary, jobs: Dictionary, cause: String) -> int:
	var state: Dictionary = delta.candidate
	var seed_value: int = str(state.meta.master_seed).to_int()
	var aid: int = 0
	_advance_experience(state, jobs)

	var pending: Array = state.household.pending_effects.duplicate(true)
	var later: Array = []
	for effect: Dictionary in pending:
		if effect.due_year > delta.year:
			later.append(effect)
			continue
		if effect.type == "aid":
			aid += int(pack.response_rules.aid_amount)
			delta.record("aid_received", effect.cause_id, {"amount": pack.response_rules.aid_amount})
		elif effect.type == "start_job":
			var actor: Dictionary = state.actors[effect.actor_id]
			if jobs.has(effect.occupation_id) and eligible(actor, jobs[effect.occupation_id], int(actor.age)) and actor.occupation_id == "dependent" and actor.work_capacity >= pack.response_rules.minimum_work_capacity:
				start_job(delta, effect.actor_id, effect.occupation_id, effect.cause_id, jobs)
			else:
				delta.record("deferred_effect_cancelled", effect.cause_id, {"actor_id": effect.actor_id, "reason": "no_longer_eligible"})
	delta.set_field("household", "pending_effects", later, cause)

	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)

		if not jobs.has(actor.occupation_id) or not eligible(actor, jobs[actor.occupation_id], int(actor.age)):
			_record_job_end(delta, id, "age_or_qualification", cause)

		if not pack.systems.adaptation:
			continue

		actor = state.actors[id]
		if actor.occupation_id != "dependent":
			var promotions: Array[String] = _promotion_candidates(actor, jobs)
			if not promotions.is_empty():
				var skill_bonus: int = 0
				var current_job: Dictionary = jobs[actor.occupation_id]
				for skill_id: String in current_job.get("required_skills", {}):
					skill_bonus += int(actor.get("skills", {}).get("values", {}).get(skill_id, 0)) * 4
				var chance: int = 120 + int(actor.willpower) * 2 + int(actor.literacy) + skill_bonus
				if Rng.integer(seed_value, "career", delta.year, id, "promotion", 0, 999) < mini(chance, 700):
					var promoted_to: String = promotions[0]
					_record_job_end(delta, id, "promotion", cause)
					start_job(delta, id, promoted_to, cause, jobs)
			continue

		if actor.age < pack.economy.adult_age or actor.work_capacity < pack.response_rules.minimum_work_capacity:
			continue
		if Rng.integer(seed_value, "career", delta.year, id, "vacancy", 0, 999) < state.world.employment_pressure:
			continue
		var options: Array = available_jobs(actor, jobs, int(actor.age))
		if not options.is_empty():
			var selected: int = Rng.integer(seed_value, "career", delta.year, id, "job", 0, options.size() - 1)
			start_job(delta, id, options[selected], cause, jobs)
	return aid
