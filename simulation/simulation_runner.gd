extends RefCounted

const Content = preload("res://simulation/content_registry.gd")
const Rng = preload("res://simulation/deterministic_rng.gd")
const Delta = preload("res://simulation/year_delta.gd")
const Household = preload("res://simulation/household_system.gd")
const VERSION: String = "0.1.0-phase-0a"

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
		actor.household_id = "household_1"
		actor.income = _annual_income(actor.occupation_id, int(pack.economy.initial_index))
		active_income += actor.income
		actors[actor.id] = actor
		ids.append(actor.id)
	ids.sort()
	return {
		"meta": {"simulation_version": VERSION, "content_version": pack.version,
			"content_hash": JSON.stringify(pack, "", true).sha256_text(),
			"engine_version": Engine.get_version_info().string, "rng_version": Rng.VERSION,
			"master_seed": str(seed_value), "player_id": pack.player_id,
			"start_year": int(pack.start_year), "status": "running"},
		"world": {"year": int(pack.start_year), "location_id": pack.location_id,
			"economy_index": int(pack.economy.initial_index),
			"food_price_index": int(pack.economy.food_initial_index)},
		"actors": actors,
		"household": {"id": "household_1", "member_ids": ids,
			"location_id": pack.location_id, "income": active_income,
			"savings": int(pack.economy.initial_savings), "debt": 0,
			"expenses": 0, "food_security": 1000, "living_standard": "unassessed"},
		"ledgers": [], "history": [{"id": "%d:initial" % int(pack.start_year),
			"year": int(pack.start_year), "kind": "household_created", "cause_id": "",
			"details": {"location_id": pack.location_id, "member_ids": ids.duplicate()}}]
	}


func _annual_income(occupation_id: String, economy_index: int) -> int:
	return int(int(occupations[occupation_id].annual_income) * economy_index / 1000.0)


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
		if actor.id != id or not members.has(id):
			errors.append("Actor identity/membership mismatch: " + id)
		if actor.age < 0 or actor.age != year - actor.birth_year:
			errors.append("Invalid age: " + id)
		if not occupations.has(actor.occupation_id):
			errors.append("Unknown occupation: " + id)
		elif actor.alive and (actor.age < occupations[actor.occupation_id].minimum_age or
				actor.income != _annual_income(actor.occupation_id, int(state.world.economy_index))):
			errors.append("Invalid occupation/income: " + id)
		if not actor.alive and actor.income != 0:
			errors.append("Dead actor has active income: " + id)
	if income != state.household.income:
		errors.append("Household income does not match active actor income")
	if state.household.savings < 0 or state.household.debt < 0:
		errors.append("Negative savings/debt")
	for key: String in ["savings", "debt", "income", "expenses"]:
		if not Content.is_integer(state.household[key]):
			errors.append("Household money must use integer units: " + key)
	if state.household.food_security < 0 or state.household.food_security > 1000:
		errors.append("Invalid food security")
	if not state.ledgers.is_empty():
		errors.append_array(Household.validate_ledger(state.ledgers.back()))
	return errors


func step(state: Dictionary, commands: Array = []) -> Dictionary:
	var errors: Array[String] = validate_state(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var year: int = int(state.world.year) + 1
	if year - int(pack.start_year) > int(pack.limits.max_years):
		return {"ok": false, "errors": ["Phase 0A year limit reached; this is not a death"]}
	errors = _validate_commands(state, commands)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var delta = Delta.new(state, year)
	var year_event: String = delta.record("year_started", "", {"from_year": state.world.year})
	delta.set_field("world", "year", year, year_event)
	var seed_value: int = str(state.meta.master_seed).to_int()
	var economy: Dictionary = pack.economy
	var economy_index: int = clampi(int(state.world.economy_index) + Rng.integer(seed_value,
		"world", year, str(pack.location_id), "economy", -int(economy.annual_drift),
		int(economy.annual_drift)), int(economy.minimum_index), int(economy.maximum_index))
	var food_index: int = clampi(int(state.world.food_price_index) + Rng.integer(seed_value,
		"world", year, str(pack.location_id), "food", -int(economy.food_annual_drift),
		int(economy.food_annual_drift)), int(economy.food_minimum_index), int(economy.food_maximum_index))
	var world_event: String = delta.record("world_changed", year_event,
		{"economy_index": economy_index, "food_price_index": food_index})
	delta.set_field("world", "economy_index", economy_index, world_event)
	delta.set_field("world", "food_price_index", food_index, world_event)
	var earned: Dictionary = {}
	var actor_ids: Array = state.actors.keys()
	actor_ids.sort()
	for id: String in actor_ids:
		var actor: Dictionary = state.actors[id]
		delta.set_field("actors", "age", year - int(actor.birth_year), year_event, id)
		var wage: int = _annual_income(actor.occupation_id, economy_index) if actor.alive else 0
		delta.set_field("actors", "income", wage, world_event, id)
		earned[id] = wage
	var consequences: Dictionary = _apply_consequences(delta, commands, earned, world_event)
	if not consequences.ok:
		return {"ok": false, "errors": consequences.errors, "diagnostic_events": delta.events}
	var active_income: int = 0
	for id: String in delta.candidate.household.member_ids:
		active_income += int(delta.candidate.actors[id].income)
	var income_event: String = delta.record("household_income_calculated", world_event,
		{"active_income": active_income, "earned_by_actor": earned,
		"consequence_ids": consequences.event_ids})
	delta.set_field("household", "income", active_income, income_event)
	var ledger: Dictionary = Household.calculate(delta.candidate.household,
		delta.candidate.actors, economy, food_index, earned)
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
	errors = validate_state(delta.candidate)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "diagnostic_events": delta.events}
	delta.record("year_committed", year_event, {"consequences_processed": consequences.count})
	return {"ok": true, "state": delta.finish(), "events": delta.events}


func _validate_commands(state: Dictionary, commands: Array) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	var affected: Dictionary = {}
	for command: Variant in commands:
		if not command is Dictionary:
			errors.append("Command must be an object")
			continue
		if command.get("type") != "job_lost":
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
		if not state.actors.has(id) or not state.actors[id].alive:
			errors.append("Command actor must exist and be alive")
		elif state.actors[id].income <= 0:
			errors.append("Cannot lose a job without an active income source")
		if affected.has(id):
			errors.append("Multiple job losses for one actor in one year")
		affected[id] = true
		var fraction: Variant = command.get("worked_permille")
		if not Content.is_integer(fraction) or float(fraction) < 0 or float(fraction) > 1000:
			errors.append("worked_permille must be an integer in [0, 1000]")
	return errors


func _apply_consequences(delta: RefCounted, commands: Array, earned: Dictionary,
		parent_event: String) -> Dictionary:
	var queue: Array = commands.duplicate(true)
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var seen: Dictionary = {}
	var event_ids: Array[String] = []
	var count: int = 0
	while not queue.is_empty():
		var trigger: Dictionary = queue.pop_front()
		var key: String = str(trigger.id) + ":" + str(trigger.type)
		if seen.has(key):
			continue
		seen[key] = true
		count += 1
		if count > int(pack.limits.max_consequences):
			return {"ok": false, "errors": ["Consequence limit exceeded; year rolled back"]}
		var id: String = trigger.actor_id
		var source: String = str(trigger.get("cause_id", parent_event))
		if trigger.type == "job_lost":
			var event_id: String = delta.record("job_lost", source,
				{"actor_id": id, "command_id": trigger.id, "worked_permille": trigger.worked_permille})
			earned[id] = int(int(earned[id]) * int(trigger.worked_permille) / 1000.0)
			delta.set_field("actors", "occupation_id", "dependent", event_id, id)
			delta.set_field("actors", "income", 0, event_id, id)
			queue.append({"id": trigger.id, "type": "income_lost", "actor_id": id, "cause_id": event_id})
		elif trigger.type == "income_lost":
			event_ids.append(delta.record("income_lost", source,
				{"actor_id": id, "retained_earnings": earned[id]}))
	return {"ok": true, "event_ids": event_ids, "count": count}


func simulate_years(seed_value: int, years: int, schedule: Dictionary = {}) -> Dictionary:
	if years < 1 or years > int(pack.limits.max_years):
		return {"ok": false, "errors": ["years must be in [1, %d]" % int(pack.limits.max_years)]}
	for scheduled_year: Variant in schedule:
		if not Content.is_integer(scheduled_year) or int(scheduled_year) <= int(pack.start_year) or \
				int(scheduled_year) > int(pack.start_year) + years or not schedule[scheduled_year] is Array:
			return {"ok": false, "errors": ["Schedule contains an invalid/out-of-range year"]}
	var state: Dictionary = initial_state(seed_value)
	for offset: int in range(years):
		var result: Dictionary = step(state, schedule.get(int(pack.start_year) + offset + 1, []))
		if not result.ok:
			return result
		state = result.state
	# This is a bounded economic experiment, not a completed life.
	return {"ok": true, "status": "year_limit", "state": state,
		"fingerprint": JSON.stringify(state, "", true).sha256_text()}
