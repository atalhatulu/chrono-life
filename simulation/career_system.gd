extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

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

static func eligible(actor: Dictionary, job: Dictionary, target_age: int) -> bool:
	if not actor.alive:
		return false
	if target_age < int(job.get("minimum_age", 0)) or target_age > int(job.get("maximum_age", 200)):
		return false
	if int(actor.literacy) < int(job.get("minimum_literacy", 0)):
		return false
	if int(job.get("annual_income", 0)) == 0:
		return true
	if int(actor.work_capacity) <= 0:
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
	var track := str(job.get("career_track", ""))
	var required_exp := int(job.get("minimum_experience_years", 0))
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
	var event := delta.record("occupation_ended", cause, {"actor_id": id, "occupation_id": actor.occupation_id, "reason": reason})
	actor.career.history.append({"year": delta.year, "kind": "ended", "occupation_id": actor.occupation_id, "reason": reason})
	actor.career.current_job = "dependent"
	delta.set_field("actors", "occupation_id", "dependent", event, id)

static func start_job(delta: RefCounted, id: String, job_id: String, cause: String, jobs: Dictionary = {}) -> void:
	var actor: Dictionary = delta.candidate.actors[id]
	initialize_actor(actor)
	var old_job := str(actor.occupation_id)
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
			var stage_id := str(actor.education.get("current_stage", ""))
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
		var track := str(jobs[actor.occupation_id].get("career_track", ""))
		if track != "":
			actor.career.track_experience[track] = int(actor.career.track_experience.get(track, 0)) + 1

static func _promotion_candidates(actor: Dictionary, jobs: Dictionary) -> Array[String]:
	if actor.occupation_id == "dependent" or not jobs.has(actor.occupation_id):
		return []
	var current: Dictionary = jobs[actor.occupation_id]
	var current_track := str(current.get("career_track", ""))
	var current_level := int(current.get("level", 0))
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

	if not pack.systems.adaptation:
		return aid

	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)

		if not jobs.has(actor.occupation_id) or not eligible(actor, jobs[actor.occupation_id], int(actor.age)):
			_record_job_end(delta, id, "age_or_qualification", cause)

		actor = state.actors[id]
		if actor.occupation_id != "dependent":
			var promotions := _promotion_candidates(actor, jobs)
			if not promotions.is_empty():
				var skill_bonus := 0
				var current_job: Dictionary = jobs[actor.occupation_id]
				for skill_id: String in current_job.get("required_skills", {}):
					skill_bonus += int(actor.get("skills", {}).get("values", {}).get(skill_id, 0)) * 4
				var chance := 120 + int(actor.willpower) * 2 + int(actor.literacy) + skill_bonus
				if Rng.integer(seed_value, "career", delta.year, id, "promotion", 0, 999) < mini(chance, 700):
					var promoted_to := promotions[0]
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
