extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Career = preload("res://simulation/career_education_system.gd")


static func update_care(delta: RefCounted, pack: Dictionary, cause: String) -> int:
	var adults: Array = []
	var children: int = 0
	for id: String in delta.candidate.household.member_ids:
		var actor: Dictionary = delta.candidate.actors[id]
		if actor.alive:
			if actor.age >= pack.economy.adult_age:
				adults.append(id)
			else:
				children += 1
	adults.sort()
	var guardian: String = "" if adults.is_empty() else str(adults[0])
	var mode: String = "institutional" if adults.is_empty() and children > 0 else "family"
	if mode != delta.candidate.household.care_mode or guardian != delta.candidate.household.guardian_id:
		var event: String = delta.record("household_care_changed", cause,
			{"care_mode": mode, "guardian_id": guardian})
		delta.set_field("household", "guardian_id", guardian, event)
		delta.set_field("household", "care_mode", mode, event)
	return children * int(pack.response_rules.orphan_support_per_child) if mode == "institutional" else 0


static func choose(delta: RefCounted, pack: Dictionary, jobs: Dictionary,
		ledger: Dictionary, cause: String) -> void:
	var state: Dictionary = delta.candidate
	if not pack.systems.adaptation or not state.actors[state.meta.player_id].alive:
		return
	var rules: Dictionary = pack.response_rules
	if ledger.budget_deficit <= 0 or ledger.closing_savings >= ledger.budget_deficit * rules.reserve_years:
		return
	var seed_value: int = str(state.meta.master_seed).to_int()
	var weights: Array[int] = [int(rules.weights.wait)]
	var options: Array = [{"id": "wait", "type": "wait"}]
	var guardian_id: String = state.household.guardian_id
	var education_first: bool = guardian_id != "" and "education_first" in state.actors[guardian_id].traits
	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive or actor.occupation_id != "dependent" or actor.work_capacity < rules.minimum_work_capacity:
			continue
		if Rng.integer(seed_value, "household", delta.year, id, "job_offer", 0, 999) < state.world.employment_pressure:
			continue
		var child: bool = int(actor.age) + 1 < pack.economy.adult_age
		# Children cannot independently decide the household's labor policy.
		if child and state.household.care_mode == "institutional":
			continue
		for job_id: String in Career.available_jobs(actor, jobs, int(actor.age) + 1):
			var weight: int = int(rules.weights.child_work if child else rules.weights.adult_work)
			if weight == 0:
				continue
			if child and education_first:
				weight = maxi(1, int(weight / 3.0))
			if child and ledger.food_security < 800:
				weight *= 2
			options.append({"id": id + ":" + job_id, "type": "start_job", "actor_id": id,
				"occupation_id": job_id, "child_work": child})
			weights.append(weight)
	if state.household.aid_uses < rules.aid_max_uses and rules.weights.seek_aid > 0:
		options.append({"id": "seek_aid", "type": "aid"})
		weights.append(int(rules.weights.seek_aid))
	var selected: int = Rng.weighted(seed_value, "household", delta.year,
		state.household.id, "response", weights)
	var choice: Dictionary = options[selected].duplicate(true)
	var event: String = delta.record("household_response", cause,
		{"selected": choice, "candidates": options, "weights": weights,
		"guardian_id": guardian_id, "care_mode": state.household.care_mode})
	if choice.type == "wait":
		return
	choice.due_year = delta.year + 1
	choice.cause_id = event
	var pending: Array = state.household.pending_effects.duplicate(true)
	pending.append(choice)
	delta.set_field("household", "pending_effects", pending, event)
	if choice.type == "aid":
		delta.set_field("household", "aid_uses", int(state.household.aid_uses) + 1, event)
