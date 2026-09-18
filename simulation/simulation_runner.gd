extends RefCounted

const Content = preload("res://simulation/content_registry.gd")
const Rng = preload("res://simulation/deterministic_rng.gd")
const Delta = preload("res://simulation/year_delta.gd")
const Household = preload("res://simulation/household_system.gd")
const Health = preload("res://simulation/health_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Responses = preload("res://simulation/household_response_system.gd")
const Consequences = preload("res://simulation/consequence_engine.gd")
const Storylets = preload("res://simulation/storylet_engine.gd")
const BotPolicy = preload("res://simulation/bot_policy.gd")
const Family = preload("res://simulation/family_system.gd")
const Needs = preload("res://simulation/needs_system.gd")
const LifeActions = preload("res://simulation/life_action_system.gd")
const AutoLife = preload("res://simulation/auto_life_controller.gd")
const LifeSummary = preload("res://simulation/life_summary.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Purchases = preload("res://simulation/purchase_system.gd")
const Education = preload("res://simulation/education_system.gd")
const SocialEvents = preload("res://simulation/social_event_system.gd")
const Treatments = preload("res://simulation/health_treatment_system.gd")
const Housing = preload("res://simulation/housing_system.gd")
const HouseholdNetwork = preload("res://simulation/household_network_system.gd")
const FamilyDynamics = preload("res://simulation/family_dynamics_system.gd")
const FamilyEvents = preload("res://simulation/family_event_system.gd")
const Skills = preload("res://simulation/skill_system.gd")
const Hobbies = preload("res://simulation/hobby_system.gd")
const Personality = preload("res://simulation/personality_system.gd")
const Assets = preload("res://simulation/asset_system.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")
const Migration = preload("res://simulation/migration_system.gd")
const VERSION: String = "0.5.0-phase-1a"

var pack: Dictionary
var occupations: Dictionary


func _init(content: Dictionary) -> void:
	pack = content.duplicate(true)
	occupations = Content.occupations_by_id(pack)


func initial_state(seed_value: int) -> Dictionary:
	var actors: Dictionary = {}
	var ids: Array[String] = []
	var active_income: int = 0
	for definition: Dictionary in pack.actors:
		var actor: Dictionary = definition.duplicate(true)
		actor.birth_year = int(actor.birth_year)
		actor.age = int(pack.start_year) - actor.birth_year
		actor.alive = true
		actor.death_year = 0
		actor.death_cause = ""
		actor.health = 100
		actor.work_capacity = 1000
		actor.constitution = Rng.integer(seed_value, "biology", int(pack.start_year), actor.id, "constitution", 40, 80)
		actor.willpower = Rng.integer(seed_value, "personality", int(pack.start_year), actor.id, "willpower", 30, 70)
		actor.genetic_seed = str(Rng.integer(seed_value, "biology", int(pack.start_year), actor.id, "genetics", 0, 2147483647))
		actor.traits = ["education_first"] if actor.willpower >= 50 else ["pragmatic"]
		actor.conditions = {}
		actor.education_state = "none"
		actor.literacy = 0
		Education.initialize_actor(actor)
		Career.initialize_actor(actor)
		Needs.initialize_actor(actor)
		Health.initialize_actor(actor)
		actor.household_id = "household_1"
		actor.income = _annual_income(actor.occupation_id, int(pack.economy.initial_index))
		active_income += actor.income
		actors[actor.id] = actor
		ids.append(actor.id)
	ids.sort()
	var result_state: Dictionary = {
		"meta": {"simulation_version": VERSION, "content_version": pack.version,
			"content_hash": JSON.stringify(pack, "", true).sha256_text(),
			"engine_version": Engine.get_version_info().string, "rng_version": Rng.VERSION,
			"master_seed": str(seed_value), "player_id": pack.player_id,
			"pack_id": str(pack.get("pack_id", pack.location_id)), "era_id": str(pack.get("era_id", "unknown")),
			"spending_catalog_path": str(pack.get("content_paths", {}).get("spending_catalog", "")),
			"life_actions_path": str(pack.get("content_paths", {}).get("life_actions", "")),
			"education_path": str(pack.get("content_paths", {}).get("education", "")),
			"relationships_path": str(pack.get("content_paths", {}).get("relationships", "")),
			"health_path": str(pack.get("content_paths", {}).get("health", "")),
			"housing_path": str(pack.get("content_paths", {}).get("housing", "")),
			"skills_path": str(pack.get("content_paths", {}).get("skills", "")),
			"hobbies_path": str(pack.get("content_paths", {}).get("hobbies", "")),
			"personality_path": str(pack.get("content_paths", {}).get("personality", "")),
			"assets_path": str(pack.get("content_paths", {}).get("assets", "")),
			"status_path": str(pack.get("content_paths", {}).get("status", "")),
			"migration_path": str(pack.get("content_paths", {}).get("migration", "")),
			"start_year": int(pack.start_year), "status": "running"},
		"world": {"year": int(pack.start_year), "location_id": pack.location_id,
			"economy_index": int(pack.economy.initial_index),
			"food_price_index": int(pack.economy.food_initial_index),
			"disease_pressure": int(pack.world_rules.disease_min),
			"employment_pressure": int(pack.world_rules.employment_min)},
		"actors": actors,
		"household": {"id": "household_1", "member_ids": ids,
			"location_id": pack.location_id, "income": active_income,
			"savings": int(pack.economy.initial_savings), "debt": 0,
			"expenses": 0, "food_security": 1000, "living_standard": "unassessed",
			"pending_effects": [], "aid_uses": 0, "care_mode": "family", "guardian_id": ""},
		"storylets": {"last_seen": {}, "flags": {}},
		"family": {
			"marital_status": "unmarried",
			"marriage_year": 0,
			"last_marriage_end_year": 0,
			"current_spouse_id": "",
			"marriages": [],
			"children_count": 0,
			"children_ids": [],
			"last_birth_year": 0,
			"kinship": {}
		},
		"ledgers": [], "history": [{"id": "%d:initial" % int(pack.start_year),
			"year": int(pack.start_year), "kind": "household_created", "cause_id": "",
			"details": {"location_id": pack.location_id, "member_ids": ids.duplicate()}}]
	}
	Family.ensure_state(result_state)
	FamilyDynamics.initialize(result_state)
	Relationships.initialize(result_state)
	PersonalEconomy.initialize(result_state)
	Housing.initialize(result_state, str(pack.get("initial_dwelling_id", "")))
	HouseholdNetwork.initialize(result_state)
	Assets.initialize(result_state)
	Migration.initialize(result_state)
	SocialStatus.initialize(result_state)
	SocialStatus.recompute(result_state)
	for actor_id: String in result_state.actors:
		Skills.initialize_actor(result_state, result_state.actors[actor_id])
		Hobbies.initialize_actor(result_state.actors[actor_id])
		Personality.initialize_actor(result_state, result_state.actors[actor_id])
	return result_state


func _annual_income(occupation_id: String, economy_index: int, capacity: int = 1000) -> int:
	return int(int(occupations[occupation_id].annual_income) * economy_index * capacity / 1000000.0)


func validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	# This is an internal state invariant check, not a public save-file parser.
	var year: int = int(state.world.year)
	if not Content.is_integer(state.world.year):
		errors.append("Year must be an integer")
	if year < int(pack.start_year):
		errors.append("Year predates initial state")
	if state.world.economy_index < pack.economy.minimum_index or \
			state.world.economy_index > pack.economy.maximum_index or \
			state.world.food_price_index < pack.economy.food_minimum_index or \
			state.world.food_price_index > pack.economy.food_maximum_index:
		errors.append("World indices outside content bounds")
	if state.meta.simulation_version != VERSION or state.meta.content_version != pack.version or \
			state.meta.content_hash != JSON.stringify(pack, "", true).sha256_text() or \
			state.meta.rng_version != Rng.VERSION or \
			state.meta.engine_version != Engine.get_version_info().string:
		errors.append("Replay version/content mismatch")
	var members: Dictionary = {}
	var income: int = 0
	for id: String in state.household.member_ids:
		if members.has(id):
			errors.append("Duplicate household member: " + id)
		members[id] = true
		if not state.actors.has(id):
			errors.append("Unknown household member: " + id)
			continue
		var actor: Dictionary = state.actors[id]
		if actor.household_id != state.household.id:
			errors.append("Inconsistent household membership: " + id)
		income += int(actor.income)
	if not members.has(state.meta.player_id):
		errors.append("Player must belong to the household")
	for id: String in state.actors:
		var actor: Dictionary = state.actors[id]
		if actor.id != id:
			errors.append("Actor identity mismatch: " + id)
		if actor.household_id == state.household.id and not members.has(id):
			errors.append("Resident actor missing from household membership: " + id)
		var age_year: int = year if actor.alive else int(actor.death_year)
		if actor.age < 0 or actor.age != age_year - actor.birth_year:
			errors.append("Invalid age: " + id)
		if not occupations.has(actor.occupation_id):
			errors.append("Unknown occupation: " + id)
		elif actor.alive and (not Career.eligible(actor, occupations[actor.occupation_id], int(actor.age)) or
				actor.income != _annual_income(actor.occupation_id, int(state.world.economy_index), int(actor.work_capacity))):
			errors.append("Invalid occupation/income: " + id)
		if not actor.alive and (actor.income != 0 or actor.occupation_id != "dependent" or actor.health != 0 or \
				actor.death_year < actor.birth_year or actor.death_year > year or actor.death_cause == ""):
			errors.append("Invalid dead actor: " + id)
		if actor.alive and (actor.death_year != 0 or actor.death_cause != ""):
			errors.append("Living actor has death metadata: " + id)
		Needs.normalize_actor(actor)
		for need_key: String in ["happiness", "stress", "social", "energy"]:
			if not Content.is_integer(actor.needs[need_key]) or actor.needs[need_key] < 0 or actor.needs[need_key] > 100:
				errors.append("Invalid actor need: " + need_key)
		for field: String in ["health", "constitution", "willpower", "literacy"]:
			if not Content.is_integer(actor[field]) or actor[field] < 0 or actor[field] > 100:
				errors.append("Invalid actor field: " + field)
		if actor.work_capacity < 0 or actor.work_capacity > 1000:
			errors.append("Invalid work capacity")
		if not actor.has("skills") or not actor.skills is Dictionary:
			errors.append("Invalid skills state")
		if not actor.has("personality") or not actor.personality is Dictionary:
			errors.append("Invalid personality state")
		else:
			for axis: String in actor.personality.get("axes", {}):
				var axis_value: int = int(actor.personality.axes[axis])
				if axis_value < 0 or axis_value > 100:
					errors.append("Invalid personality axis: " + axis)
		if not actor.has("hobbies") or not actor.hobbies is Dictionary:
			errors.append("Invalid hobbies state")
		if not actor.has("career") or not actor.career is Dictionary:
			errors.append("Invalid career state")
		elif int(actor.career.get("experience_years", -1)) < 0 or int(actor.career.get("job_changes", -1)) < 0:
			errors.append("Invalid career counters")
		if actor.education_state not in ["none", "basic_schooling", "interrupted", "completed"]:
			errors.append("Unknown education state")
		if actor.alive and actor.education_state == "basic_schooling" and actor.occupation_id != "dependent":
			errors.append("Full-time work cannot coexist with basic schooling")
		var condition_ids: Array = []
		for definition: Dictionary in pack.conditions:
			condition_ids.append(definition.id)
		for condition_id: String in actor.conditions:
			var cond: Variant = actor.conditions[condition_id]
			if condition_id not in condition_ids:
				errors.append("Unknown actor condition")
			elif not cond is Dictionary or not Content.is_integer(cond.get("remaining_years")) or \
					not Content.is_integer(cond.get("acquired_year")) or \
					int(cond.acquired_year) < int(pack.start_year) or int(cond.acquired_year) > year or \
					(int(cond.remaining_years) != -1 and int(cond.remaining_years) <= 0):
				errors.append("Invalid condition data: " + condition_id)
	if income != state.household.income:
		errors.append("Household income does not match active actor income")
	if state.household.savings < 0 or state.household.debt < 0:
		errors.append("Negative savings/debt")
	for key: String in ["savings", "debt", "income", "expenses"]:
		if not Content.is_integer(state.household[key]):
			errors.append("Household money must use integer units: " + key)
	if state.household.food_security < 0 or state.household.food_security > 1000:
		errors.append("Invalid food security")
	if state.household.get("care_mode") not in ["family", "institutional"]:
		errors.append("Invalid household care mode")
	var guardian_id: String = str(state.household.get("guardian_id", ""))
	if guardian_id != "":
		if not state.actors.has(guardian_id):
			errors.append("guardian_id does not reference an actor")
		elif not state.actors[guardian_id].alive:
			errors.append("guardian must be alive")
		elif int(state.actors[guardian_id].age) < int(pack.economy.adult_age):
			errors.append("guardian must be an adult")
	if not Content.is_integer(state.household.get("aid_uses")) or int(state.household.aid_uses) < 0:
		errors.append("aid_uses must be a nonnegative integer")
	if state.meta.status not in ["running", "player_dead"] or \
			(state.meta.status == "player_dead") == bool(state.actors[state.meta.player_id].alive):
		errors.append("Player life status mismatch")
	for effect: Dictionary in state.household.pending_effects:
		if effect.type not in ["start_job", "aid"] or effect.due_year <= year:
			errors.append("Invalid deferred effect")
		elif effect.type == "start_job" and (not state.actors.has(effect.actor_id) or not occupations.has(effect.occupation_id)):
			errors.append("Unknown deferred effect actor/occupation")
	if not state.ledgers.is_empty():
		errors.append_array(Household.validate_ledger(state.ledgers[state.ledgers.size() - 1]))
	if state.has("storylets"):
		if not state.storylets is Dictionary or not state.storylets.get("last_seen") is Dictionary or \
				not state.storylets.get("flags") is Dictionary:
			errors.append("Invalid storylet state structure")
	if state.has("family"):
		if not state.family is Dictionary or not state.family.has("marital_status") or \
				state.family.marital_status not in ["unmarried", "married", "widowed", "divorced"]:
			errors.append("Invalid family state structure")
	if not state.has("households") or not state.households is Dictionary:
		errors.append("Invalid household registry")
	else:
		var resident_seen: Dictionary = {}
		for household_id: String in state.households:
			var household_entry: Dictionary = state.households[household_id]
			for actor_id: String in household_entry.get("member_ids", []):
				if not state.actors.has(actor_id):
					errors.append("Household registry references unknown actor: " + actor_id)
					continue
				if resident_seen.has(actor_id):
					errors.append("Actor belongs to multiple households: " + actor_id)
				resident_seen[actor_id] = household_id
				if str(state.actors[actor_id].household_id) != household_id:
					errors.append("Actor household registry mismatch: " + actor_id)
	if not state.has("assets") or not state.assets is Dictionary:
		errors.append("Invalid assets state")
	if not state.has("social_status") or not state.social_status is Dictionary:
		errors.append("Invalid social status state")
	elif int(state.social_status.get("score", -1)) < 0 or int(state.social_status.get("score", -1)) > 100:
		errors.append("Invalid social status score")
	if not state.has("migration") or not state.migration is Dictionary:
		errors.append("Invalid migration state")
	elif str(state.migration.get("current_location_id", "")) != str(state.world.location_id):
		errors.append("Migration/world location mismatch")
	if not state.has("housing") or not state.housing is Dictionary:
		errors.append("Invalid housing state structure")
	else:
		var housing_defs: Dictionary = Housing.dwellings_by_id(state)
		if not housing_defs.has(str(state.housing.get("dwelling_id", ""))):
			errors.append("Unknown current dwelling")
		if int(state.housing.get("unpaid_years", -1)) < 0 or int(state.housing.get("move_count", -1)) < 0:
			errors.append("Invalid housing counters")
	return errors


func step_prepare(state: Dictionary, commands: Array = [], decision_override: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = validate_state(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	if state.meta.status != "running":
		return {"ok": false, "errors": ["The player's life has already ended"]}
	var year: int = int(state.world.year) + 1
	if year - int(pack.start_year) > int(pack.limits.max_years):
		return {"ok": false, "errors": ["Configured year limit reached; this is not a death"]}
	errors = _validate_commands(state, commands)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var delta = Delta.new(state, year)
	var year_event: String = delta.record("year_started", "", {"from_year": state.world.year})
	delta.set_field("world", "year", year, year_event)
	var seed_value: int = str(state.meta.master_seed).to_int()
	var economy: Dictionary = pack.economy
	var location_modifiers: Dictionary = state.get("migration", {}).get("world_modifiers", {})
	var economy_index: int = clampi(int(state.world.economy_index) + Rng.integer(seed_value,
		"world", year, str(state.world.location_id), "economy", -int(economy.annual_drift),
		int(economy.annual_drift)) + int(location_modifiers.get("economy_index", 0)), int(economy.minimum_index), int(economy.maximum_index))
	var food_index: int = clampi(int(state.world.food_price_index) + Rng.integer(seed_value,
		"world", year, str(state.world.location_id), "food", -int(economy.food_annual_drift),
		int(economy.food_annual_drift)) + int(location_modifiers.get("food_price_index", 0)), int(economy.food_minimum_index), int(economy.food_maximum_index))
	var world_event: String = delta.record("world_changed", year_event,
		{"economy_index": economy_index, "food_price_index": food_index})
	delta.set_field("world", "economy_index", economy_index, world_event)
	delta.set_field("world", "food_price_index", food_index, world_event)
	for entry: Array in [["disease_pressure", "disease"], ["employment_pressure", "employment"]]:
		var rolled_pressure: int = Rng.integer(seed_value, "world", year, str(state.world.location_id),
			entry[0], int(pack.world_rules[entry[1] + "_min"]), int(pack.world_rules[entry[1] + "_max"]))
		rolled_pressure = clampi(rolled_pressure + int(location_modifiers.get(entry[0], 0)), 0, 1000)
		delta.set_field("world", entry[0], rolled_pressure, world_event)
	var earned: Dictionary = {}
	var participation: Dictionary = {}
	var actor_ids: Array = state.actors.keys()
	actor_ids.sort()
	for id: String in actor_ids:
		var actor: Dictionary = state.actors[id]
		if actor.alive:
			delta.set_field("actors", "age", year - int(actor.birth_year), year_event, id)
			Personality.annual_drift(delta.candidate, delta.candidate.actors[id])
		participation[id] = 1000 if actor.alive else 0
	var support: int = Career.prepare(delta, pack, occupations, year_event)
	var deaths: Array = Health.advance(delta, pack, occupations, world_event)
	for id: String in actor_ids:
		var actor: Dictionary = delta.candidate.actors[id]
		var wage: int = _annual_income(actor.occupation_id, economy_index, int(actor.work_capacity)) if actor.alive else 0
		var income_cause: String = world_event
		if actor.occupation_id != state.actors[id].occupation_id:
			for idx: int in range(delta.events.size() - 1, -1, -1):
				var ev: Dictionary = delta.events[idx]
				if ev.kind in ["occupation_started", "occupation_ended"] and ev.details.get("actor_id") == id:
					income_cause = ev.id
					break
		elif actor.work_capacity != state.actors[id].work_capacity:
			for idx: int in range(delta.events.size() - 1, -1, -1):
				var ev: Dictionary = delta.events[idx]
				if ev.kind == "health_evaluated" and ev.details.get("actor_id") == id:
					income_cause = ev.id
					break
		delta.set_field("actors", "income", wage, income_cause, id)
		earned[id] = wage
	var consequences: Dictionary = Consequences.process(delta, commands + deaths, earned, participation,
		world_event, int(pack.limits.max_consequences))
	if not consequences.ok:
		return {"ok": false, "errors": consequences.errors, "diagnostic_events": delta.events}
	Education.advance(delta, pack, year_event)
	Family.advance(delta, pack, year_event, seed_value)
	FamilyDynamics.advance(delta.candidate, pack, seed_value)
	HouseholdNetwork.sync_primary(delta.candidate)
	var family_event_data: Dictionary = FamilyEvents.resolve_one(delta.candidate)
	if not family_event_data.is_empty():
		delta.record("family_event", year_event, family_event_data)
	var care_event: String = delta.record("household_care_evaluated", year_event,
		{"consequence_ids": consequences.event_ids})
	var orphan_support: int = Responses.update_care(delta, pack, care_event) if pack.systems.adaptation else 0
	if orphan_support > 0:
		delta.record("orphan_support_received", care_event, {"amount": orphan_support})
	support += orphan_support
	var active_income: int = 0
	for id: String in delta.candidate.household.member_ids:
		active_income += int(delta.candidate.actors[id].income)
	var income_event: String = delta.record("household_income_calculated", world_event,
		{"active_income": active_income, "earned_by_actor": earned,
		"consequence_ids": consequences.event_ids})
	delta.set_field("household", "income", active_income, income_event)
	var economy_for_year: Dictionary = economy.duplicate(true)
	economy_for_year.rent = Housing.annual_cost(delta.candidate)
	var ledger: Dictionary = Household.calculate(delta.candidate.household,
		delta.candidate.actors, economy_for_year, food_index, earned, participation, support)
	ledger.year = year
	var budget_event: String = delta.record("household_budget", income_event, ledger)
	for mapping: Array in [["savings", "closing_savings"], ["debt", "closing_debt"],
			["expenses", "planned_expenses"], ["food_security", "food_security"],
			["living_standard", "living_standard"]]:
		delta.set_field("household", mapping[0], ledger[mapping[1]], budget_event)
	for key: String in ["budget_deficit", "savings_used", "borrowed", "debt_repaid", "unmet_needs"]:
		if ledger[key] > 0:
			delta.record(key, budget_event, {"amount": ledger[key]})
	if ledger.food_security < 1000:
		delta.record("food_insecurity", budget_event, {"food_security": ledger.food_security})
	delta.candidate.ledgers.append(ledger)
	Housing.record_payment(delta.candidate, int(ledger.rent_due), int(ledger.rent_paid))
	Housing.apply_wellbeing(delta.candidate)
	Assets.annual_update(delta.candidate)
	SocialStatus.recompute(delta.candidate)

	var storylet: Dictionary = {}
	if not delta.candidate.actors[state.meta.player_id].alive:
		var end_event: String = delta.record("life_ended", budget_event, {"player_id": state.meta.player_id})
		delta.set_field("meta", "status", "player_dead", end_event)
		delta.set_field("household", "pending_effects", [], end_event)
	else:
		Responses.choose(delta, pack, occupations, ledger, budget_event)
		if pack.systems.get("storylets", false):
			for cand: Dictionary in pack.get("storylets", []):
				if decision_override.has(cand.id) and Storylets.is_eligible(cand, delta.candidate):
					storylet = cand
					break
			if storylet.is_empty():
				storylet = Storylets.select_storylet(pack, delta.candidate, ledger, seed_value)

	return {
		"ok": true,
		"delta": delta,
		"storylet": storylet,
		"budget_event": budget_event,
		"year_event": year_event,
		"consequences_count": consequences.count,
		"year": year,
		"seed_value": seed_value,
		"ledger": ledger
	}


func step_resolve(prep: Dictionary, choice_id: String = "") -> Dictionary:
	var delta = prep.delta
	var storylet: Dictionary = prep.storylet
	var budget_event: String = prep.budget_event
	var year_event: String = prep.year_event
	var year: int = prep.year
	var seed_value: int = prep.seed_value

	if not storylet.is_empty() and choice_id != "":
		var st_event: String = delta.record("storylet_triggered", budget_event,
			{"storylet_id": storylet.id, "title": storylet.title, "family": storylet.family})
		var outcome: Dictionary = Storylets.apply_choice(delta, storylet, choice_id, st_event, seed_value, pack)
		SocialStatus.recompute(delta.candidate)
		delta.record("storylet_choice_made", st_event, outcome)
	elif pack.systems.get("storylets", false) and delta.candidate.actors[delta.candidate.meta.player_id].alive:
		delta.record("quiet_year", budget_event, {"year": year})

	var errors: Array[String] = validate_state(delta.candidate)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "diagnostic_events": delta.events}
	delta.record("year_committed", year_event, {"consequences_processed": prep.consequences_count})
	return {"ok": true, "state": delta.finish(), "events": delta.events}


func step(state: Dictionary, commands: Array = [], decision_override: Dictionary = {}, policy_name: String = "heuristic_v1") -> Dictionary:
	var prep: Dictionary = step_prepare(state, commands, decision_override)
	if not prep.ok:
		return prep
	var choice_id: String = ""
	if not prep.storylet.is_empty():
		if decision_override.has(prep.storylet.id):
			choice_id = str(decision_override[prep.storylet.id])
		else:
			choice_id = BotPolicy.decide(prep.storylet, prep.delta.candidate, prep.ledger, prep.seed_value, prep.year, policy_name)
	return step_resolve(prep, choice_id)


func _validate_commands(state: Dictionary, commands: Array) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	var affected: Dictionary = {}
	for command: Variant in commands:
		if not command is Dictionary:
			errors.append("Command must be an object")
			continue
		if command.get("type") not in ["job_lost", "actor_died"]:
			errors.append("Unknown command type")
			continue
		if not command.get("id") is String or str(command.get("id", "")).is_empty():
			errors.append("Command requires nonempty id")
			continue
		if ids.has(command.id):
			if ids[command.id] != command:
				errors.append("Conflicting commands with the same id")
			continue
		ids[command.id] = command
		var id: String = str(command.get("actor_id", ""))
		if not state.actors.has(id):
			errors.append("Command actor must exist")
		elif not state.actors[id].alive and not command.get("skip_if_unavailable", false):
			errors.append("Command actor must exist and be alive")
		elif command.type == "job_lost" and state.actors[id].occupation_id == "dependent" and not command.get("skip_if_unavailable", false):
			errors.append("Cannot lose a job without an active income source")
		if command.has("skip_if_unavailable") and not command.skip_if_unavailable is bool:
			errors.append("skip_if_unavailable must be a boolean")
		var target: String = id + ":" + str(command.type)
		if affected.has(target):
			errors.append("Multiple %s commands for one actor in one year" % str(command.type))
		affected[target] = true
		var fraction: Variant = command.get("worked_permille")
		if not Content.is_integer(fraction) or float(fraction) < 0 or float(fraction) > 1000:
			errors.append("worked_permille must be an integer in [0, 1000]")
	return errors


func simulate_years(seed_value: int, years: int, schedule: Dictionary = {}, decisions: Dictionary = {}, policy_name: String = "heuristic_v1") -> Dictionary:
	if years < 1 or years > int(pack.limits.max_years):
		return {"ok": false, "errors": ["years must be in [1, %d]" % int(pack.limits.max_years)]}
	for scheduled_year: Variant in schedule:
		if not scheduled_year is int or int(scheduled_year) <= int(pack.start_year) or \
				int(scheduled_year) > int(pack.start_year) + years or not schedule[scheduled_year] is Array:
			return {"ok": false, "errors": ["Schedule contains an invalid/out-of-range year"]}
		for command: Variant in schedule[scheduled_year]:
			if not command is Dictionary:
				return {"ok": false, "errors": ["Schedule command must be an object"]}
			if command.get("type") not in ["job_lost", "actor_died"]:
				return {"ok": false, "errors": ["Schedule command contains unknown type: %s" % str(command.get("type"))]}
			if not command.get("id") is String or str(command.get("id", "")).is_empty():
				return {"ok": false, "errors": ["Schedule command requires nonempty id"]}
			var target_actor: String = str(command.get("actor_id", ""))
			var found_actor: bool = false
			for actor_def: Dictionary in pack.actors:
				if actor_def.id == target_actor:
					found_actor = true
					break
			if not found_actor:
				return {"ok": false, "errors": ["Schedule command references unknown actor: " + target_actor]}
			var fraction: Variant = command.get("worked_permille")
			if not Content.is_integer(fraction) or float(fraction) < 0 or float(fraction) > 1000:
				return {"ok": false, "errors": ["Schedule command worked_permille must be an integer in [0, 1000]"]}
			if command.has("skip_if_unavailable") and not command.skip_if_unavailable is bool:
				return {"ok": false, "errors": ["Schedule command skip_if_unavailable must be a boolean"]}
	var state: Dictionary = initial_state(seed_value)
	for offset: int in range(years):
		if state.meta.status == "player_dead":
			break
		var current_year: int = int(pack.start_year) + offset + 1
		var current_decisions: Dictionary = decisions.get(current_year, {})
		var result: Dictionary = step(state, schedule.get(current_year, []), current_decisions, policy_name)
		if not result.ok:
			return result
		state = result.state
	var player: Dictionary = state.actors[state.meta.player_id]
	return {"ok": true, "status": "completed" if not player.alive else "year_limit", "state": state,
		"life_result": {"name": player.name, "birth_year": player.birth_year,
			"death_year": player.death_year if not player.alive else null,
			"age": player.age, "cause_of_death": player.death_cause,
			"education": player.education_state, "literacy": player.literacy},
		"fingerprint": JSON.stringify(state, "", true).sha256_text()}


func simulate_life(seed_value: int, decisions: Dictionary = {}, policy_name: String = "heuristic_v1") -> Dictionary:
	return simulate_years(seed_value, int(pack.limits.max_years), {}, decisions, policy_name)


func auto_step(state: Dictionary, policy_name: String = "balanced") -> Dictionary:
	if state.meta.status != "running":
		return {"ok": false, "errors": ["The player's life has already ended"]}
	var working: Dictionary = state.duplicate(true)
	PersonalEconomy.begin_year(working)
	Relationships.annual_drift(working)
	var social_event: Dictionary = SocialEvents.resolve_one(working)
	var player: Dictionary = working.actors[working.meta.player_id]
	Needs.annual_drift(player)
	var parenting_decision: Dictionary = AutoLife.choose_parenting_action(working, policy_name)
	if not parenting_decision.is_empty():
		FamilyDynamics.interact_with_child(working, str(parenting_decision.child_id), str(parenting_decision.action))
	var elder_care_decision: Dictionary = AutoLife.choose_elder_care_action(working, policy_name)
	if not elder_care_decision.is_empty():
		FamilyDynamics.care_for_parent(working, str(elder_care_decision.parent_id), str(elder_care_decision.action))
	var social_decision: Dictionary = AutoLife.choose_relationship_action(working, policy_name)
	if not social_decision.is_empty():
		if social_decision.action == "meet":
			Relationships.meet_person(working)
		elif str(social_decision.get("person_id", "")) != "":
			Relationships.interact(working, str(social_decision.person_id), str(social_decision.action))
	var asset_id: String = AutoLife.choose_asset(working, policy_name)
	if asset_id != "":
		var asset_result: Dictionary = Assets.acquire(working, asset_id)
		if not asset_result.ok:
			return {"ok": false, "errors": [asset_result.error]}
	var migration_id: String = AutoLife.choose_migration(working, policy_name)
	if migration_id != "":
		var migration_result: Dictionary = Migration.move_to(working, migration_id)
		if not migration_result.ok:
			return {"ok": false, "errors": [migration_result.error]}
	var hobby_id: String = AutoLife.choose_hobby(working, policy_name)
	if hobby_id != "":
		var hobby_result: Dictionary = Hobbies.practice(working, str(working.meta.player_id), hobby_id, "autolife")
		if not hobby_result.ok:
			return {"ok": false, "errors": [hobby_result.error]}
	var treatment_id: String = AutoLife.choose_treatment(working, policy_name)
	if treatment_id != "":
		var treatment_result: Dictionary = Treatments.apply(working, treatment_id)
		if not treatment_result.ok:
			return {"ok": false, "errors": [treatment_result.error]}
	var purchase_id: String = AutoLife.choose_purchase(working, policy_name)
	if purchase_id != "":
		var purchase_result: Dictionary = Purchases.purchase(working, purchase_id)
		if not purchase_result.ok:
			return {"ok": false, "errors": [purchase_result.error]}
	var action_id: String = AutoLife.choose_action(working, policy_name)
	if action_id != "":
		var action_result: Dictionary = LifeActions.apply(working, action_id)
		if not action_result.ok:
			return {"ok": false, "errors": [action_result.error]}
	var result: Dictionary = step(working, [], {}, policy_name)
	if result.ok:
		PersonalEconomy.settle_year(result.state)
		PersonalEconomy.maybe_allowance(result.state)
		result.action_id = action_id
		result.hobby_id = hobby_id
		result.asset_id = asset_id
		result.migration_id = migration_id
		result.purchase_id = purchase_id
		result.treatment_id = treatment_id
		result.social_decision = social_decision
		result.parenting_decision = parenting_decision
		result.elder_care_decision = elder_care_decision
		result.social_event = social_event
	return result


func simulate_auto_life(seed_value: int, policy_name: String = "balanced") -> Dictionary:
	var state: Dictionary = initial_state(seed_value)
	var actions: Array = []
	var hobbies: Array = []
	var assets: Array = []
	var migrations: Array = []
	var purchases: Array = []
	var social_actions: Array = []
	var social_events: Array = []
	var treatments: Array = []
	var parenting_actions: Array = []
	var elder_care_actions: Array = []
	var family_events: Array = []
	while state.meta.status == "running":
		if int(state.world.year) - int(pack.start_year) >= int(pack.limits.max_years):
			break
		var result: Dictionary = auto_step(state, policy_name)
		if not result.ok:
			return result
		for ev: Dictionary in result.get("events", []):
			if ev.kind == "family_event":
				family_events.append({"year": int(result.state.world.year), "event": ev.details})
		if not result.get("parenting_decision", {}).is_empty():
			parenting_actions.append({"year": int(result.state.world.year), "decision": result.parenting_decision})
		if not result.get("elder_care_decision", {}).is_empty():
			elder_care_actions.append({"year": int(result.state.world.year), "decision": result.elder_care_decision})
		if not result.get("social_event", {}).is_empty():
			social_events.append({"year": int(result.state.world.year), "event": result.social_event})
		if not result.get("social_decision", {}).is_empty():
			social_actions.append({"year": int(result.state.world.year), "decision": result.social_decision})
		if str(result.get("treatment_id", "")) != "":
			treatments.append({"year": int(result.state.world.year), "treatment_id": result.treatment_id})
		if str(result.get("asset_id", "")) != "":
			assets.append({"year": int(result.state.world.year), "asset_id": result.asset_id})
		if str(result.get("migration_id", "")) != "":
			migrations.append({"year": int(result.state.world.year), "destination_id": result.migration_id})
		if str(result.get("hobby_id", "")) != "":
			hobbies.append({"year": int(result.state.world.year), "hobby_id": result.hobby_id})
		if str(result.get("purchase_id", "")) != "":
			purchases.append({"year": int(result.state.world.year), "item_id": result.purchase_id})
		if str(result.get("action_id", "")) != "":
			actions.append({"year": int(result.state.world.year), "action_id": result.action_id})
		state = result.state
	var player: Dictionary = state.actors[state.meta.player_id]
	return {"ok": true, "status": "completed" if not player.alive else "year_limit",
		"state": state, "actions": actions, "hobbies": hobbies, "assets": assets, "migrations": migrations, "purchases": purchases, "social_actions": social_actions, "social_events": social_events, "family_events": family_events, "parenting_actions": parenting_actions, "elder_care_actions": elder_care_actions, "treatments": treatments, "life_result": LifeSummary.build(state),
		"fingerprint": JSON.stringify(state, "", true).sha256_text()}
