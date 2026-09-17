extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")


static func mortality_components(actor: Dictionary, definitions: Dictionary,
		rules: Dictionary) -> Dictionary:
	# Hazard applies over the interval just lived, including the first year.
	var interval_age: int = maxi(0, int(actor.age) - 1)
	var base: int = 0
	for band: Dictionary in rules.mortality_bands:
		if interval_age >= band.minimum_age:
			base = int(band.risk_bp)
	var components: Dictionary = {"baseline": base}
	var ids: Array = actor.conditions.keys()
	ids.sort()
	for id: String in ids:
		components[id] = int(definitions[id].mortality_bp)
	return components


static func mortality_risk(actor: Dictionary, definitions: Dictionary, rules: Dictionary) -> int:
	var total: int = 0
	for risk: int in mortality_components(actor, definitions, rules).values():
		total += risk
	return clampi(int(total * (130 - int(actor.constitution)) / 100.0), 0, 10000)


static func advance(delta: RefCounted, pack: Dictionary, occupations: Dictionary,
		parent_event: String) -> Array:
	var deaths: Array = []
	if not pack.systems.health:
		return deaths
	var state: Dictionary = delta.candidate
	var definitions: Dictionary = {}
	for definition: Dictionary in pack.conditions:
		definitions[definition.id] = definition
	var ids: Array = state.actors.keys()
	ids.sort()
	var condition_ids: Array = definitions.keys()
	condition_ids.sort()
	var seed_value: int = str(state.meta.master_seed).to_int()
	for id: String in ids:
		var actor: Dictionary = state.actors[id]
		if not actor.alive:
			continue
		var conditions: Dictionary = actor.conditions.duplicate(true)
		var recovered: Dictionary = {}
		for condition_id: String in condition_ids:
			var definition: Dictionary = definitions[condition_id]
			if conditions.has(condition_id):
				var condition: Dictionary = conditions[condition_id]
				if (definition.exposure == "nutrition" and state.household.food_security >= definition.food_threshold) or \
						condition.remaining_years == 1:
					conditions.erase(condition_id)
					recovered[condition_id] = true
					var event: String = delta.record("condition_recovered", parent_event,
						{"actor_id": id, "condition_id": condition_id})
					delta.set_field("actors", "conditions", conditions.duplicate(true), event, id)
				elif condition.remaining_years > 1:
					condition.remaining_years -= 1
			if conditions.has(condition_id) or recovered.has(condition_id):
				continue
			var chance: int = int(definition.incidence_bp)
			match definition.exposure:
				"nutrition":
					if state.household.food_security >= definition.food_threshold:
						chance = 0
				"ambient":
					chance = int(chance * int(state.world.disease_pressure) / 1000.0)
				"work":
					chance = int(chance * int(occupations[actor.occupation_id].risk_permille) / 1000.0)
			if Rng.integer(seed_value, "health", delta.year, id, "acquire:" + condition_id, 0, 9999) < chance:
				conditions[condition_id] = {"acquired_year": delta.year,
					"remaining_years": -1 if definition.duration_years == 0 else int(definition.duration_years)}
				var event: String = delta.record("condition_acquired", parent_event,
					{"actor_id": id, "condition_id": condition_id,
					"previous_food_security": state.household.food_security, "chance_bp": chance})
				delta.set_field("actors", "conditions", conditions.duplicate(true), event, id)
		var health: int = clampi(80 + int(actor.constitution) / 4 - maxi(0, int(actor.age) - 40), 1, 100)
		var capacity: int = 1000
		for condition_id: String in conditions:
			health -= int(definitions[condition_id].health_penalty)
			capacity -= int(definitions[condition_id].work_penalty)
		var event: String = delta.record("health_evaluated", parent_event,
			{"actor_id": id, "condition_ids": conditions.keys()})
		delta.set_field("actors", "conditions", conditions, event, id)
		delta.set_field("actors", "health", clampi(health, 1, 100), event, id)
		delta.set_field("actors", "work_capacity", clampi(capacity, 0, 1000), event, id)
		var risk: int = mortality_risk(actor, definitions, pack.health_rules)
		if Rng.integer(seed_value, "health", delta.year, id, "mortality", 0, 9999) < risk:
			var components: Dictionary = mortality_components(actor, definitions, pack.health_rules)
			var causes: Array = components.keys()
			causes.sort()
			var weights: Array[int] = []
			for cause: String in causes:
				weights.append(int(components[cause]))
			var selected: int = Rng.weighted(seed_value, "health", delta.year, id, "death_cause", weights)
			deaths.append({"id": "health_death:" + id, "type": "actor_died", "actor_id": id,
				"worked_permille": int(pack.health_rules.death_worked_permille),
				"cause": causes[selected], "cause_id": event})
	return deaths
