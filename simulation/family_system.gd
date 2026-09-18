extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const Needs = preload("res://simulation/needs_system.gd")
const Education = preload("res://simulation/education_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Health = preload("res://simulation/health_system.gd")
const HouseholdNetwork = preload("res://simulation/household_network_system.gd")

const FEMALE_NAMES: Array[String] = ["Sarah", "Elizabeth", "Mary", "Hannah", "Alice", "Ellen", "Martha"]
const MALE_NAMES: Array[String] = ["James", "John", "Thomas", "George", "William", "Joseph", "Robert"]

static func ensure_state(state: Dictionary) -> void:
	if not state.has("family") or not state.family is Dictionary:
		state.family = {}
	var fam: Dictionary = state.family
	if not fam.has("marital_status"): fam.marital_status = "unmarried"
	if not fam.has("marriage_year"): fam.marriage_year = 0
	if not fam.has("last_marriage_end_year"): fam.last_marriage_end_year = 0
	if not fam.has("current_spouse_id"): fam.current_spouse_id = "spouse" if state.actors.has("spouse") else ""
	if not fam.has("marriages"): fam.marriages = []
	if not fam.has("children_count"): fam.children_count = 0
	if not fam.has("children_ids"):
		fam.children_ids = []
		for id: String in state.actors:
			if id.begins_with("child"):
				fam.children_ids.append(id)
	if not fam.has("last_birth_year"): fam.last_birth_year = 0
	if not fam.has("kinship"): fam.kinship = {}
	if not fam.has("history"): fam.history = []
	var player_id := str(state.meta.player_id)
	_ensure_kin(state, player_id)
	for id: String in state.actors:
		if id.begins_with("parent"):
			_ensure_kin(state, id)
			_link_parent_child(state, id, player_id)

static func _ensure_kin(state: Dictionary, actor_id: String) -> void:
	if not state.family.kinship.has(actor_id):
		state.family.kinship[actor_id] = {"parents": [], "children": [], "siblings": []}

static func _append_unique(array: Array, value: String) -> void:
	if value != "" and value not in array:
		array.append(value)

static func _link_parent_child(state: Dictionary, parent_id: String, child_id: String) -> void:
	_ensure_kin(state, parent_id)
	_ensure_kin(state, child_id)
	_append_unique(state.family.kinship[parent_id].children, child_id)
	_append_unique(state.family.kinship[child_id].parents, parent_id)
	for sibling_id: String in state.family.kinship[parent_id].children:
		if sibling_id == child_id:
			continue
		_ensure_kin(state, sibling_id)
		_append_unique(state.family.kinship[child_id].siblings, sibling_id)
		_append_unique(state.family.kinship[sibling_id].siblings, child_id)

static func _surname(name: String) -> String:
	var parts := name.split(" ", false)
	return str(parts.back()) if parts.size() > 1 else ""

static func _next_spouse_id(state: Dictionary) -> String:
	var n := 1
	while true:
		var id := "spouse" if n == 1 else "spouse_%d" % n
		if not state.actors.has(id):
			return id
		n += 1
	return ""

static func _choose_spouse_occupation(pack: Dictionary, spouse_age: int) -> String:
	var candidates: Array[String] = []
	for occ: Dictionary in pack.get("occupations", []):
		if int(occ.get("annual_income", 0)) <= 0:
			continue
		if spouse_age < int(occ.get("minimum_age", 0)) or spouse_age > int(occ.get("maximum_age", 200)):
			continue
		if int(occ.get("minimum_literacy", 0)) > 45:
			continue
		candidates.append(str(occ.id))
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else "dependent"

static func create_spouse(delta: RefCounted, pack: Dictionary, cause_event: String, seed_value: int) -> String:
	var state: Dictionary = delta.candidate
	ensure_state(state)
	if str(state.family.current_spouse_id) != "":
		return ""
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	var partner_id: String = Relationships.best_partner_candidate(state)

	var spouse_sex: String = "female" if player.get("sex", "male") == "male" else "male"
	var name_pool: Array[String] = FEMALE_NAMES if spouse_sex == "female" else MALE_NAMES
	var name_idx: int = Rng.integer(seed_value, "family", delta.year, "spouse", "name", 0, name_pool.size() - 1)
	var spouse_name: String = name_pool[name_idx] + (" " + _surname(str(player.name)) if _surname(str(player.name)) != "" else "")
	if partner_id != "" and state.relationships.people.has(partner_id):
		spouse_name = str(state.relationships.people[partner_id].name)

	var birth_offset: int = Rng.integer(seed_value, "family", delta.year, "spouse", "age_offset", -2, 2)
	var min_m_age: int = int(pack.get("family_rules", {}).get("min_marriage_age", 18))
	var spouse_birth_year: int = clampi(int(player.birth_year) + birth_offset,
		int(pack.start_year) - 60, delta.year - min_m_age)
	var spouse_age: int = delta.year - spouse_birth_year
	var occ_id := _choose_spouse_occupation(pack, spouse_age)
	var economy_index: int = int(state.world.economy_index)
	var base_wage := 0
	for occ: Dictionary in pack.get("occupations", []):
		if str(occ.id) == occ_id:
			base_wage = int(occ.annual_income)
			break
	var spouse_wage := int(base_wage * economy_index / 1000.0)

	var spouse_id := _next_spouse_id(state)
	var spouse: Dictionary = {
		"id": spouse_id, "name": spouse_name, "sex": spouse_sex,
		"birth_year": spouse_birth_year, "age": spouse_age,
		"alive": true, "death_year": 0, "death_cause": "",
		"health": 85, "constitution": 65, "willpower": 55, "literacy": 45,
		"conditions": {}, "education_state": "completed",
		"occupation_id": occ_id, "income": spouse_wage, "work_capacity": 1000,
		"household_id": state.household.id, "traits": ["pragmatic"]
	}
	Needs.initialize_actor(spouse)
	Education.initialize_actor(spouse)
	spouse.education.completed_stages.append("elementary")
	Career.initialize_actor(spouse)
	Health.initialize_actor(spouse)
	state.actors[spouse_id] = spouse
	_append_unique(state.household.member_ids, spouse_id)

	state.family.marital_status = "married"
	state.family.marriage_year = delta.year
	state.family.current_spouse_id = spouse_id
	state.family.marriages.append({
		"spouse_id": spouse_id, "start_year": delta.year, "end_year": 0, "end_reason": ""
	})
	_ensure_kin(state, spouse_id)

	Relationships.register_person(state, spouse_id, spouse_name, "spouse", true,
		"existing_relationship" if partner_id != "" else "courtship", spouse_sex)
	if partner_id != "" and partner_id != spouse_id:
		state.relationships.people.erase(partner_id)
		state.relationships.history.append({"year": delta.year, "kind": "relationship_became_marriage",
			"person_id": spouse_id, "former_person_id": partner_id})

	var event := delta.record("marriage_formed", cause_event, {
		"spouse_id": spouse_id, "name": spouse_name, "age": spouse_age,
		"occupation_id": occ_id, "income": spouse_wage
	})
	return event

static func _end_marriage(delta: RefCounted, state: Dictionary, spouse_id: String,
		reason: String, cause: String) -> void:
	if spouse_id == "" or not state.actors.has(spouse_id):
		return
	for marriage: Dictionary in state.family.marriages:
		if str(marriage.get("spouse_id", "")) == spouse_id and int(marriage.get("end_year", 0)) == 0:
			marriage.end_year = delta.year
			marriage.end_reason = reason
	state.family.last_marriage_end_year = delta.year
	state.family.current_spouse_id = ""
	state.family.marital_status = "widowed" if reason == "death" else "divorced"
	var spouse: Dictionary = state.actors[spouse_id]
	if reason != "death":
		state.household.member_ids.erase(spouse_id)
		HouseholdNetwork.create_external_household(state, spouse_id, "former_spouse")
	if state.relationships.people.has(spouse_id):
		var rel: Dictionary = state.relationships.people[spouse_id]
		rel.role = "former_spouse" if reason != "death" else "spouse"
		rel.stage = "ex_partner" if reason != "death" else "spouse"
	state.relationships.history.append({"year": delta.year, "kind": "marriage_ended",
		"person_id": spouse_id, "reason": reason})
	delta.record("marriage_ended", cause, {"spouse_id": spouse_id, "reason": reason})

static func _evaluate_marriage(delta: RefCounted, pack: Dictionary, cause: String, seed_value: int) -> void:
	var state: Dictionary = delta.candidate
	var spouse_id := str(state.family.current_spouse_id)
	if spouse_id == "" or not state.actors.has(spouse_id):
		return
	var spouse: Dictionary = state.actors[spouse_id]
	if not spouse.alive:
		_end_marriage(delta, state, spouse_id, "death", cause)
		return
	var rel: Dictionary = state.relationships.people.get(spouse_id, {})
	var threshold := int(pack.get("family_rules", {}).get("divorce_conflict_threshold", 80))
	if rel.is_empty() or int(rel.get("conflict", 0)) < threshold:
		return
	var chance := int(pack.get("family_rules", {}).get("divorce_chance_permille", 0))
	chance += maxi(0, int(rel.get("conflict", 0)) - threshold) * 10
	chance -= int(rel.get("trust", 50)) * 2
	if Rng.integer(seed_value, "family", delta.year, spouse_id, "divorce", 0, 999) < clampi(chance, 0, 950):
		_end_marriage(delta, state, spouse_id, "divorce", cause)

static func _evaluate_children_leaving(delta: RefCounted, pack: Dictionary, cause: String, seed_value: int) -> void:
	var state: Dictionary = delta.candidate
	var rules: Dictionary = pack.get("family_rules", {})
	var min_age := int(rules.get("adult_child_leave_min_age", 18))
	var base := int(rules.get("adult_child_leave_base_permille", 100))
	var employed_bonus := int(rules.get("adult_child_leave_employed_bonus_permille", 300))
	for child_id: String in state.family.children_ids.duplicate():
		if not state.actors.has(child_id) or child_id not in state.household.member_ids:
			continue
		var child: Dictionary = state.actors[child_id]
		if not child.alive or int(child.age) < min_age:
			continue
		var chance := base
		if child.occupation_id != "dependent":
			chance += employed_bonus
		if int(child.age) >= min_age + 5:
			chance += (int(child.age) - min_age - 4) * 80
		if Rng.integer(seed_value, "family", delta.year, child_id, "leave_home", 0, 999) >= clampi(chance, 0, 950):
			continue
		state.household.member_ids.erase(child_id)
		var new_household_id := HouseholdNetwork.create_external_household(state, child_id, "adult_child")
		state.family.history.append({"year": delta.year, "kind": "child_left_home", "child_id": child_id})
		delta.record("child_left_home", cause, {"child_id": child_id, "age": child.age,
			"occupation_id": child.occupation_id, "household_id": new_household_id})
		if state.relationships.people.has(child_id):
			state.relationships.people[child_id].contact = maxi(20, int(state.relationships.people[child_id].contact) - 15)

static func _create_child(delta: RefCounted, pack: Dictionary, cause: String, seed_value: int) -> void:
	var state: Dictionary = delta.candidate
	var player_id := str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	var spouse_id := str(state.family.current_spouse_id)
	if spouse_id == "" or not state.actors.has(spouse_id):
		return
	var spouse: Dictionary = state.actors[spouse_id]
	if not spouse.alive:
		return
	var female: Dictionary = player if player.get("sex", "male") == "female" else spouse
	var female_id := player_id if player.get("sex", "male") == "female" else spouse_id
	var rules: Dictionary = pack.get("family_rules", {})
	if int(female.age) < int(rules.get("min_parent_age", 18)) or int(female.age) > int(rules.get("max_parent_age", 42)):
		return
	var last_birth := int(state.family.last_birth_year)
	if last_birth > 0 and delta.year - last_birth < int(rules.get("min_birth_interval_years", 2)):
		return
	if int(state.family.children_count) >= int(rules.get("max_children", 6)):
		return
	if Rng.integer(seed_value, "family", delta.year, "birth", "conception", 0, 999) >= int(rules.get("conception_chance_permille", 300)):
		return

	var child_index := int(state.family.children_count) + 1
	var child_id := "child_%d" % child_index
	while state.actors.has(child_id):
		child_index += 1
		child_id = "child_%d" % child_index
	var child_sex := "female" if Rng.integer(seed_value, "family", delta.year, child_id, "sex", 0, 1) == 0 else "male"
	var names: Array[String] = FEMALE_NAMES if child_sex == "female" else MALE_NAMES
	var first := names[Rng.integer(seed_value, "family", delta.year, child_id, "name", 0, names.size() - 1)]
	var surname := _surname(str(player.name))
	var child_name := first + (" " + surname if surname != "" else "")
	var child := {
		"id":child_id,"name":child_name,"sex":child_sex,"birth_year":delta.year,"age":0,
		"alive":true,"death_year":0,"death_cause":"","health":80,"constitution":70,"willpower":50,
		"literacy":0,"conditions":{},"education_state":"none","occupation_id":"dependent","income":0,
		"work_capacity":0,"household_id":state.household.id,"traits":[]
	}
	Needs.initialize_actor(child)
	Education.initialize_actor(child)
	Career.initialize_actor(child)
	Health.initialize_actor(child)
	state.actors[child_id] = child
	_append_unique(state.household.member_ids, child_id)
	_append_unique(state.family.children_ids, child_id)
	state.family.children_count = state.family.children_ids.size()
	state.family.last_birth_year = delta.year
	_link_parent_child(state, player_id, child_id)
	_link_parent_child(state, spouse_id, child_id)

	var maternal_cost := int(rules.get("maternal_health_cost", 8))
	female.health = clampi(int(female.health) - maternal_cost, 1, 100)
	Relationships.register_person(state, child_id, child_name, "child", true, "birth", child_sex)
	delta.record("child_born", cause, {"child_id":child_id,"name":child_name,"sex":child_sex,
		"mother_id":female_id,"father_or_partner_id":spouse_id})

static func advance(delta: RefCounted, pack: Dictionary, year_event: String, seed_value: int) -> void:
	if not pack.systems.get("family", false):
		return
	var state: Dictionary = delta.candidate
	ensure_state(state)
	var player: Dictionary = state.actors[state.meta.player_id]
	if not player.alive:
		return
	_evaluate_marriage(delta, pack, year_event, seed_value)
	_evaluate_children_leaving(delta, pack, year_event, seed_value)
	if state.family.marital_status == "married":
		_create_child(delta, pack, year_event, seed_value)
