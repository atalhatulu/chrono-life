extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")


static func eligible(actor: Dictionary, job: Dictionary, target_age: int) -> bool:
	return actor.alive and target_age >= job.minimum_age and target_age <= job.maximum_age \
		and actor.literacy >= job.minimum_literacy


static func available_jobs(actor: Dictionary, jobs: Dictionary, target_age: int) -> Array:
	var ids: Array = jobs.keys()
	ids.sort()
	var result: Array = []
	for id: String in ids:
		if jobs[id].annual_income > 0 and eligible(actor, jobs[id], target_age):
			result.append(id)
	return result


static func start_job(delta: RefCounted, id: String, job_id: String, cause: String) -> void:
	var actor: Dictionary = delta.candidate.actors[id]
	var event: String = delta.record("occupation_started", cause, {"actor_id": id, "occupation_id": job_id})
	delta.set_field("actors", "occupation_id", job_id, event, id)
	if actor.education_state == "basic_schooling":
		var school_event: String = delta.record("school_interrupted", event, {"actor_id": id})
		delta.set_field("actors", "education_state", "interrupted", school_event, id)


static func prepare(delta: RefCounted, pack: Dictionary, jobs: Dictionary, cause: String) -> int:
	var state: Dictionary = delta.candidate
	var seed_value: int = str(state.meta.master_seed).to_int()
	var aid: int = 0
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
			if eligible(actor, jobs[effect.occupation_id], int(actor.age)) and \
					actor.occupation_id == "dependent" and actor.work_capacity >= pack.response_rules.minimum_work_capacity:
				start_job(delta, effect.actor_id, effect.occupation_id, effect.cause_id)
			else:
				delta.record("deferred_effect_cancelled", effect.cause_id,
					{"actor_id": effect.actor_id, "reason": "no_longer_eligible"})
	delta.set_field("household", "pending_effects", later, cause)
	if not pack.systems.adaptation:
		return aid
	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		if not eligible(actor, jobs[actor.occupation_id], int(actor.age)):
			var event: String = delta.record("occupation_ended", cause,
				{"actor_id": id, "reason": "age_or_qualification"})
			delta.set_field("actors", "occupation_id", "dependent", event, id)
		if actor.occupation_id != "dependent" or actor.age < pack.economy.adult_age or \
				actor.work_capacity < pack.response_rules.minimum_work_capacity:
			continue
		if Rng.integer(seed_value, "career", delta.year, id, "vacancy", 0, 999) < state.world.employment_pressure:
			continue
		var options: Array = available_jobs(actor, jobs, int(actor.age))
		if not options.is_empty():
			var selected: int = Rng.integer(seed_value, "career", delta.year, id, "job", 0, options.size() - 1)
			start_job(delta, id, options[selected], cause)
	return aid


static func education(delta: RefCounted, pack: Dictionary, cause: String) -> void:
	if not pack.systems.education:
		return
	var rules: Dictionary = pack.education_rules
	var ids: Array = delta.candidate.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = delta.candidate.actors[id]
		if not actor.alive:
			continue
		if actor.age >= rules.completion_age and actor.education_state == "basic_schooling":
			var event: String = delta.record("school_completed", cause, {"actor_id": id})
			delta.set_field("actors", "education_state", "completed", event, id)
		elif actor.age >= rules.start_age and actor.age < rules.completion_age and \
				actor.occupation_id == "dependent" and actor.education_state == "none":
			var event: String = delta.record("school_started", cause, {"actor_id": id})
			delta.set_field("actors", "education_state", "basic_schooling", event, id)
		if actor.education_state == "basic_schooling" and actor.health >= rules.minimum_health:
			delta.set_field("actors", "literacy", mini(100, int(actor.literacy) + int(rules.literacy_per_year)), cause, id)
