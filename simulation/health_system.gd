extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static func initialize_actor(actor: Dictionary) -> void:
	if not actor.has("health_profile"):
		actor.health_profile = {
			"disabilities": [],
			"treatment_history": [],
			"lifetime_conditions": [],
			"last_treatment_year": -1
		}

static func definitions_by_id(pack: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for definition: Dictionary in pack.get("conditions", []):
		out[definition.id] = definition
	return out

static func mortality_components(actor: Dictionary, definitions: Dictionary,
		rules: Dictionary) -> Dictionary:
	var interval_age: int = maxi(0, int(actor.age) - 1)
	var base: int = 0
	for band: Dictionary in rules.mortality_bands:
		if interval_age >= int(band.minimum_age):
			base = int(band.risk_bp)
	var components: Dictionary = {"baseline": base}
	var ids: Array = actor.conditions.keys()
	ids.sort()
	for id: String in ids:
		if not definitions.has(id):
			continue
		var definition: Dictionary = definitions[id]
		var severity := int(actor.conditions[id].get("severity", 50))
		components[id] = int(int(definition.mortality_bp) * maxi(25, severity) / 50.0)
	return components

static func mortality_risk(actor: Dictionary, definitions: Dictionary, rules: Dictionary) -> int:
	var total: int = 0
	for risk: int in mortality_components(actor, definitions, rules).values():
		total += risk
	return clampi(int(total * (130 - int(actor.constitution)) / 100.0), 0, 10000)

static func _new_condition(seed_value: int, year: int, actor_id: String,
		definition: Dictionary) -> Dictionary:
	var range: Array = definition.get("severity_range", [50, 50])
	var low := int(range[0]) if range.size() > 0 else 50
	var high := int(range[1]) if range.size() > 1 else low
	return {
		"acquired_year": year,
		"remaining_years": -1 if int(definition.get("duration_years", 0)) == 0 else int(definition.duration_years),
		"severity": Rng.integer(seed_value, "health", year, actor_id, "severity:" + str(definition.id), low, high),
		"treated_this_year": false
	}

static func _incidence_chance(state: Dictionary, actor: Dictionary,
		definition: Dictionary, occupations: Dictionary) -> int:
	var chance := int(definition.get("incidence_bp", 0))
	match str(definition.get("exposure", "ambient")):
		"nutrition":
			if int(state.household.food_security) >= int(definition.get("food_threshold", 0)):
				chance = 0
		"ambient":
			chance = int(chance * int(state.world.disease_pressure) / 1000.0)
		"work":
			if occupations.has(actor.occupation_id):
				chance = int(chance * int(occupations[actor.occupation_id].get("risk_permille", 0)) / 1000.0)
			else:
				chance = 0
	return clampi(chance, 0, 10000)

static func _maybe_disability(delta: RefCounted, actor: Dictionary, actor_id: String,
		definition: Dictionary, condition: Dictionary, seed_value: int, cause: String) -> void:
	initialize_actor(actor)
	var chance := int(definition.get("disability_chance_bp", 0))
	if chance <= 0 or int(condition.get("severity", 0)) < 60:
		return
	if Rng.integer(seed_value, "health", delta.year, actor_id, "disability:" + str(definition.id), 0, 9999) >= chance:
		return
	var disability_id := str(definition.id) + "_sequela"
	if disability_id in actor.health_profile.disabilities:
		return
	actor.health_profile.disabilities.append(disability_id)
	delta.record("disability_acquired", cause, {
		"actor_id": actor_id, "condition_id": definition.id, "disability_id": disability_id
	})

static func advance(delta: RefCounted, pack: Dictionary, occupations: Dictionary,
		parent_event: String) -> Array:
	var deaths: Array = []
	if not pack.systems.health:
		return deaths
	var state: Dictionary = delta.candidate
	var definitions := definitions_by_id(pack)
	var ids: Array = state.actors.keys()
	ids.sort()
	var condition_ids: Array = definitions.keys()
	condition_ids.sort()
	var seed_value: int = str(state.meta.master_seed).to_int()

	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		initialize_actor(actor)
		var conditions: Dictionary = actor.conditions.duplicate(true)
		var recovered: Dictionary = {}

		for condition_id: String in condition_ids:
			var definition: Dictionary = definitions[condition_id]
			if conditions.has(condition_id):
				var condition: Dictionary = conditions[condition_id]
				if not condition.has("severity"):
					condition.severity = 50
				condition.treated_this_year = false
				var nutrition_recovered := str(definition.get("exposure", "")) == "nutrition" and 					int(state.household.food_security) >= int(definition.get("food_threshold", 0))
				var duration_recovered := int(condition.get("remaining_years", -1)) == 1
				var natural_recovery := false
				var recovery_bp := int(definition.get("natural_recovery_bp", 0))
				if recovery_bp > 0:
					natural_recovery = Rng.integer(seed_value, "health", delta.year, id,
						"recover:" + condition_id, 0, 9999) < recovery_bp
				if nutrition_recovered or duration_recovered or natural_recovery:
					conditions.erase(condition_id)
					recovered[condition_id] = true
					var event: String = delta.record("condition_recovered", parent_event,
						{"actor_id": id, "condition_id": condition_id})
					_maybe_disability(delta, actor, id, definition, condition, seed_value, event)
					delta.set_field("actors", "conditions", conditions.duplicate(true), event, id)
				elif int(condition.get("remaining_years", -1)) > 1:
					condition.remaining_years = int(condition.remaining_years) - 1

			if conditions.has(condition_id) or recovered.has(condition_id):
				continue
			var chance := _incidence_chance(state, actor, definition, occupations)
			if Rng.integer(seed_value, "health", delta.year, id, "acquire:" + condition_id, 0, 9999) < chance:
				conditions[condition_id] = _new_condition(seed_value, delta.year, id, definition)
				if condition_id not in actor.health_profile.lifetime_conditions:
					actor.health_profile.lifetime_conditions.append(condition_id)
				var event: String = delta.record("condition_acquired", parent_event,
					{"actor_id": id, "condition_id": condition_id,
					"previous_food_security": state.household.food_security, "chance_bp": chance,
					"severity": conditions[condition_id].severity})
				delta.set_field("actors", "conditions", conditions.duplicate(true), event, id)

		var health: int = clampi(80 + int(actor.constitution) / 4 - maxi(0, int(actor.age) - 40), 1, 100)
		var capacity: int = 1000
		for condition_id: String in conditions:
			var definition: Dictionary = definitions[condition_id]
			var severity := int(conditions[condition_id].get("severity", 50))
			var scale := clampf(severity / 50.0, 0.5, 1.75)
			health -= int(int(definition.get("health_penalty", 0)) * scale)
			capacity -= int(int(definition.get("work_penalty", 0)) * scale)
		for _disability: Variant in actor.health_profile.disabilities:
			health -= 5
			capacity -= 80

		var event: String = delta.record("health_evaluated", parent_event,
			{"actor_id": id, "condition_ids": conditions.keys(),
			"disabilities": actor.health_profile.disabilities.duplicate()})
		delta.set_field("actors", "conditions", conditions, event, id)
		delta.set_field("actors", "health", clampi(health, 1, 100), event, id)
		delta.set_field("actors", "work_capacity", clampi(capacity, 0, 1000), event, id)

		var risk: int = mortality_risk(actor, definitions, pack.health_rules)
		if Rng.integer(seed_value, "health", delta.year, id, "mortality", 0, 9999) < risk:
			var components: Dictionary = mortality_components(actor, definitions, pack.health_rules)
			var causes: Array = components.keys()
			causes.sort()
			var weights: Array[int] = []
			for cause_name: String in causes:
				weights.append(int(components[cause_name]))
			var selected: int = Rng.weighted(seed_value, "health", delta.year, id, "death_cause", weights)
			deaths.append({"id": "health_death:" + id, "type": "actor_died", "actor_id": id,
				"worked_permille": int(pack.health_rules.death_worked_permille),
				"cause": causes[selected], "cause_id": event})
	return deaths
