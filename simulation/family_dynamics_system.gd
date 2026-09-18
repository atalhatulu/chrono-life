extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Needs = preload("res://simulation/needs_system.gd")
const Education = preload("res://simulation/education_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Health = preload("res://simulation/health_system.gd")
const HouseholdNetwork = preload("res://simulation/household_network_system.gd")

static func initialize(state: Dictionary) -> void:
	if not state.family.has("parenting"):
		state.family.parenting = {}
	if not state.family.has("sibling_bonds"):
		state.family.sibling_bonds = {}
	if not state.family.has("descendant_lives"):
		state.family.descendant_lives = {}
	if not state.family.has("grandchildren_ids"):
		state.family.grandchildren_ids = []

static func _bond_key(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]

static func _ensure_parenting(state: Dictionary, child_id: String) -> Dictionary:
	initialize(state)
	if not state.family.parenting.has(child_id):
		state.family.parenting[child_id] = {
			"involvement": 55,
			"support": 55,
			"discipline": 50,
			"conflict": 10,
			"last_active_year": int(state.world.year)
		}
	return state.family.parenting[child_id]

static func _ensure_sibling_bond(state: Dictionary, a: String, b: String) -> Dictionary:
	initialize(state)
	var key := _bond_key(a, b)
	if not state.family.sibling_bonds.has(key):
		state.family.sibling_bonds[key] = {
			"actors": [a, b],
			"closeness": 55,
			"rivalry": 15,
			"support": 45
		}
	return state.family.sibling_bonds[key]

static func interact_with_child(state: Dictionary, child_id: String, kind: String) -> Dictionary:
	if not state.actors.has(child_id) or child_id not in state.family.get("children_ids", []):
		return {"ok": false, "error": "Unknown child"}
	var child: Dictionary = state.actors[child_id]
	if not child.alive:
		return {"ok": false, "error": "Child is not alive"}
	var parenting := _ensure_parenting(state, child_id)
	match kind:
		"support":
			parenting.support = clampi(int(parenting.support) + 10, 0, 100)
			parenting.involvement = clampi(int(parenting.involvement) + 5, 0, 100)
			child.needs.happiness = clampi(int(child.needs.happiness) + 5, 0, 100)
			child.needs.stress = clampi(int(child.needs.stress) - 4, 0, 100)
		"discipline":
			parenting.discipline = clampi(int(parenting.discipline) + 8, 0, 100)
			parenting.conflict = clampi(int(parenting.conflict) + 4, 0, 100)
			child.willpower = clampi(int(child.willpower) + 2, 0, 100)
			child.needs.happiness = clampi(int(child.needs.happiness) - 2, 0, 100)
		"spend_time":
			parenting.involvement = clampi(int(parenting.involvement) + 10, 0, 100)
			parenting.conflict = clampi(int(parenting.conflict) - 4, 0, 100)
			child.needs.social = clampi(int(child.needs.social) + 8, 0, 100)
			child.needs.happiness = clampi(int(child.needs.happiness) + 6, 0, 100)
		"education_support":
			parenting.support = clampi(int(parenting.support) + 7, 0, 100)
			child.literacy = clampi(int(child.literacy) + 2, 0, 100)
			child.willpower = clampi(int(child.willpower) + 1, 0, 100)
		_:
			return {"ok": false, "error": "Unknown parenting interaction"}
	parenting.last_active_year = int(state.world.year)
	state.family.history.append({"year": int(state.world.year), "kind": "parenting",
		"child_id": child_id, "interaction": kind})
	return {"ok": true}

static func _annual_parenting(state: Dictionary) -> void:
	initialize(state)
	for child_id: String in state.family.get("children_ids", []):
		if not state.actors.has(child_id):
			continue
		var child: Dictionary = state.actors[child_id]
		if not child.alive:
			continue
		var parenting := _ensure_parenting(state, child_id)
		if int(parenting.last_active_year) < int(state.world.year):
			parenting.involvement = clampi(int(parenting.involvement) - 2, 0, 100)
		if int(parenting.support) >= 70:
			child.needs.stress = clampi(int(child.needs.stress) - 2, 0, 100)
			child.willpower = clampi(int(child.willpower) + 1, 0, 100)
		if int(parenting.conflict) >= 65:
			child.needs.stress = clampi(int(child.needs.stress) + 4, 0, 100)
			child.needs.happiness = clampi(int(child.needs.happiness) - 3, 0, 100)

static func _annual_siblings(state: Dictionary, seed_value: int) -> void:
	initialize(state)
	var children: Array[String] = []
	for id: String in state.family.get("children_ids", []):
		if state.actors.has(id) and state.actors[id].alive:
			children.append(id)
	children.sort()
	for i: int in range(children.size()):
		for j: int in range(i + 1, children.size()):
			var a := children[i]
			var b := children[j]
			var bond := _ensure_sibling_bond(state, a, b)
			var same_household := str(state.actors[a].household_id) == str(state.actors[b].household_id)
			if same_household:
				bond.closeness = clampi(int(bond.closeness) + 1, 0, 100)
			else:
				bond.closeness = clampi(int(bond.closeness) - 1, 0, 100)
			var age_gap := abs(int(state.actors[a].age) - int(state.actors[b].age))
			if age_gap <= 2:
				var roll := Rng.integer(seed_value, "siblings", int(state.world.year), a, b, 0, 99)
				if roll < 20:
					bond.rivalry = clampi(int(bond.rivalry) + 3, 0, 100)
				elif roll > 80:
					bond.support = clampi(int(bond.support) + 3, 0, 100)

static func _next_grandchild_id(state: Dictionary) -> String:
	var n := int(state.family.get("grandchildren_ids", []).size()) + 1
	var id := "grandchild_%d" % n
	while state.actors.has(id):
		n += 1
		id = "grandchild_%d" % n
	return id

static func _ensure_descendant_profile(state: Dictionary, child_id: String) -> Dictionary:
	initialize(state)
	if not state.family.descendant_lives.has(child_id):
		state.family.descendant_lives[child_id] = {
			"marital_status": "single",
			"partner_id": "",
			"marriage_year": 0,
			"children_ids": [],
			"last_birth_year": 0
		}
	return state.family.descendant_lives[child_id]

static func _create_descendant_partner(state: Dictionary, child_id: String, seed_value: int) -> String:
	var child: Dictionary = state.actors[child_id]
	var profile := _ensure_descendant_profile(state, child_id)
	if str(profile.partner_id) != "":
		return str(profile.partner_id)
	var partner_id := "partner_" + child_id
	if state.actors.has(partner_id):
		return partner_id
	var sex := "female" if child.get("sex", "male") == "male" else "male"
	var partner := {
		"id": partner_id,
		"name": "Partner of " + str(child.name),
		"sex": sex,
		"birth_year": int(child.birth_year) + Rng.integer(seed_value, "descendants", int(state.world.year), child_id, "partner_age", -3, 3),
		"alive": true,
		"death_year": 0,
		"death_cause": "",
		"health": 80,
		"constitution": 60,
		"willpower": 50,
		"literacy": int(child.literacy),
		"conditions": {},
		"education_state": str(child.education_state),
		"occupation_id": str(child.occupation_id),
		"income": int(child.income),
		"work_capacity": 1000,
		"household_id": str(child.household_id),
		"traits": []
	}
	partner.age = int(state.world.year) - int(partner.birth_year)
	Needs.initialize_actor(partner)
	Education.initialize_actor(partner)
	Career.initialize_actor(partner)
	Health.initialize_actor(partner)
	state.actors[partner_id] = partner
	HouseholdNetwork.add_member(state, str(child.household_id), partner_id)
	profile.partner_id = partner_id
	profile.marital_status = "married"
	profile.marriage_year = int(state.world.year)
	state.family.history.append({"year": int(state.world.year), "kind": "child_married",
		"child_id": child_id, "partner_id": partner_id})
	state.history.append({"id":"%d:child_married:%s" % [int(state.world.year), child_id],
		"year":int(state.world.year),"kind":"child_married","cause_id":"",
		"details":{"child_id":child_id,"partner_id":partner_id}})
	return partner_id

static func _create_grandchild(state: Dictionary, child_id: String, seed_value: int) -> String:
	var child: Dictionary = state.actors[child_id]
	var profile := _ensure_descendant_profile(state, child_id)
	var partner_id := str(profile.partner_id)
	if partner_id == "" or not state.actors.has(partner_id):
		return ""
	var id := _next_grandchild_id(state)
	var sex := "female" if Rng.integer(seed_value, "descendants", int(state.world.year), id, "sex", 0, 1) == 0 else "male"
	var gc := {
		"id": id,
		"name": "Grandchild %d" % (state.family.grandchildren_ids.size() + 1),
		"sex": sex,
		"birth_year": int(state.world.year),
		"age": 0,
		"alive": true,
		"death_year": 0,
		"death_cause": "",
		"health": 80,
		"constitution": 65,
		"willpower": 50,
		"literacy": 0,
		"conditions": {},
		"education_state": "none",
		"occupation_id": "dependent",
		"income": 0,
		"work_capacity": 0,
		"household_id": str(child.household_id),
		"traits": []
	}
	Needs.initialize_actor(gc)
	Education.initialize_actor(gc)
	Career.initialize_actor(gc)
	Health.initialize_actor(gc)
	state.actors[id] = gc
	HouseholdNetwork.add_member(state, str(child.household_id), id)
	profile.children_ids.append(id)
	profile.last_birth_year = int(state.world.year)
	state.family.grandchildren_ids.append(id)
	if not state.family.kinship.has(child_id):
		state.family.kinship[child_id] = {"parents": [], "children": [], "siblings": []}
	if not state.family.kinship.has(partner_id):
		state.family.kinship[partner_id] = {"parents": [], "children": [], "siblings": []}
	if not state.family.kinship.has(id):
		state.family.kinship[id] = {"parents": [child_id, partner_id], "children": [], "siblings": []}
	if id not in state.family.kinship[child_id].children:
		state.family.kinship[child_id].children.append(id)
	if id not in state.family.kinship[partner_id].children:
		state.family.kinship[partner_id].children.append(id)
	for sibling_id: String in profile.children_ids:
		if sibling_id == id or not state.family.kinship.has(sibling_id):
			continue
		if sibling_id not in state.family.kinship[id].siblings:
			state.family.kinship[id].siblings.append(sibling_id)
		if id not in state.family.kinship[sibling_id].siblings:
			state.family.kinship[sibling_id].siblings.append(id)
	state.family.history.append({"year": int(state.world.year), "kind": "grandchild_born",
		"parent_id": child_id, "grandchild_id": id})
	state.history.append({"id":"%d:grandchild_born:%s" % [int(state.world.year), id],
		"year":int(state.world.year),"kind":"grandchild_born","cause_id":"",
		"details":{"parent_id":child_id,"grandchild_id":id}})
	return id

static func _advance_descendants(state: Dictionary, pack: Dictionary, seed_value: int) -> void:
	var rules: Dictionary = pack.get("family_rules", {})
	var min_marriage_age := int(rules.get("descendant_marriage_min_age", rules.get("min_marriage_age", 18) + 2))
	for child_id: String in state.family.get("children_ids", []):
		if not state.actors.has(child_id):
			continue
		var child: Dictionary = state.actors[child_id]
		if not child.alive or str(child.household_id) == str(state.household.id):
			continue
		var profile := _ensure_descendant_profile(state, child_id)
		if str(profile.marital_status) == "single" and int(child.age) >= min_marriage_age:
			var chance := int(rules.get("descendant_marriage_base_permille", 120)) + maxi(0, int(child.age) - min_marriage_age) * int(rules.get("descendant_marriage_age_bonus_permille", 15))
			if Rng.integer(seed_value, "descendants", int(state.world.year), child_id, "marry", 0, 999) < mini(chance, 1000):
				_create_descendant_partner(state, child_id, seed_value)
		if str(profile.marital_status) != "married":
			continue
		var gap := int(state.world.year) - int(profile.get("last_birth_year", 0))
		if int(profile.get("last_birth_year", 0)) > 0 and gap < 2:
			continue
		var max_children := int(rules.get("descendant_max_children", mini(4, int(rules.get("max_children", 6)))))
		if profile.children_ids.size() >= max_children:
			continue
		if int(child.age) > 45:
			continue
		if Rng.integer(seed_value, "descendants", int(state.world.year), child_id, "birth", 0, 999) < int(rules.get("descendant_birth_chance_permille", 180)):
			_create_grandchild(state, child_id, seed_value)

static func advance(state: Dictionary, pack: Dictionary, seed_value: int) -> void:
	initialize(state)
	_annual_parenting(state)
	_annual_siblings(state, seed_value)
	_advance_descendants(state, pack, seed_value)
