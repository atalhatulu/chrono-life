extends RefCounted

static func initialize(state: Dictionary) -> void:
	if not state.has("households") or not state.households is Dictionary:
		state.households = {}
	var primary_id := str(state.household.id)
	if not state.households.has(primary_id):
		state.households[primary_id] = {
			"id": primary_id,
			"member_ids": state.household.member_ids.duplicate(),
			"location_id": str(state.household.location_id),
			"kind": "primary",
			"formed_year": int(state.world.year),
			"active": true
		}

static func sync_primary(state: Dictionary) -> void:
	initialize(state)
	var id := str(state.household.id)
	var entry: Dictionary = state.households[id]
	entry.member_ids = state.household.member_ids.duplicate()
	entry.location_id = str(state.household.location_id)
	entry.active = true

static func create_external_household(state: Dictionary, founder_id: String,
		kind: String = "independent") -> String:
	initialize(state)
	var base := "household_" + founder_id
	var id := base
	var suffix := 2
	while state.households.has(id):
		id = "%s_%d" % [base, suffix]
		suffix += 1
	state.households[id] = {
		"id": id,
		"member_ids": [founder_id],
		"location_id": str(state.world.location_id),
		"kind": kind,
		"formed_year": int(state.world.year),
		"active": true
	}
	if state.actors.has(founder_id):
		state.actors[founder_id].household_id = id
	return id

static func move_actor(state: Dictionary, actor_id: String, target_household_id: String) -> bool:
	initialize(state)
	if not state.actors.has(actor_id) or not state.households.has(target_household_id):
		return false
	for household_id: String in state.households:
		state.households[household_id].member_ids.erase(actor_id)
	state.households[target_household_id].member_ids.append(actor_id)
	state.actors[actor_id].household_id = target_household_id
	if target_household_id == str(state.household.id):
		if actor_id not in state.household.member_ids:
			state.household.member_ids.append(actor_id)
	else:
		state.household.member_ids.erase(actor_id)
	sync_primary(state)
	return true

static func household_of(state: Dictionary, actor_id: String) -> Dictionary:
	initialize(state)
	if not state.actors.has(actor_id):
		return {}
	var household_id := str(state.actors[actor_id].get("household_id", ""))
	return state.households.get(household_id, {})

static func add_member(state: Dictionary, household_id: String, actor_id: String) -> void:
	initialize(state)
	if not state.households.has(household_id):
		return
	if actor_id not in state.households[household_id].member_ids:
		state.households[household_id].member_ids.append(actor_id)
	state.actors[actor_id].household_id = household_id
	if household_id == str(state.household.id) and actor_id not in state.household.member_ids:
		state.household.member_ids.append(actor_id)
	sync_primary(state)

static func active_households(state: Dictionary) -> Array[Dictionary]:
	initialize(state)
	var result: Array[Dictionary] = []
	var ids: Array = state.households.keys()
	ids.sort()
	for id: String in ids:
		var h: Dictionary = state.households[id]
		if bool(h.get("active", true)):
			result.append(h)
	return result
