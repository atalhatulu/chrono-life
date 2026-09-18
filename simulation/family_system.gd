extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const Needs = preload("res://simulation/needs_system.gd")
const Education = preload("res://simulation/education_system.gd")
const Career = preload("res://simulation/career_system.gd")

const FEMALE_NAMES: Array[String] = ["Sarah", "Elizabeth", "Mary", "Hannah", "Alice", "Ellen", "Martha"]
const MALE_NAMES: Array[String] = ["James", "John", "Thomas", "George", "William", "Joseph", "Robert"]


static func create_spouse(delta: RefCounted, pack: Dictionary, cause_event: String, seed_value: int) -> String:
	var state: Dictionary = delta.candidate
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]

	var spouse_sex: String = "female" if player.sex == "male" else "male"
	var name_pool: Array[String] = FEMALE_NAMES if spouse_sex == "female" else MALE_NAMES
	var name_idx: int = Rng.integer(seed_value, "family", delta.year, "spouse", "name", 0, name_pool.size() - 1)
	var spouse_name: String = name_pool[name_idx] + " Thompson"
	var partner_id: String = Relationships.best_partner_candidate(state)
	if partner_id != "" and state.relationships.people.has(partner_id):
		spouse_name = str(state.relationships.people[partner_id].name)

	var birth_offset: int = Rng.integer(seed_value, "family", delta.year, "spouse", "age_offset", -2, 2)
	var min_m_age: int = int(pack.get("family_rules", {}).get("min_marriage_age", 19))
	var spouse_birth_year: int = clampi(int(player.birth_year) + birth_offset,
		int(pack.start_year) - 40, delta.year - min_m_age)
	var spouse_age: int = delta.year - spouse_birth_year

	var occ_id: String = "sewing_worker" if spouse_sex == "female" else "textile_worker"
	var economy_index: int = int(state.world.economy_index)
	var base_wage: int = 1800
	for occ: Dictionary in pack.get("occupations", []):
		if occ.id == occ_id:
			base_wage = int(occ.annual_income)
			break
	var spouse_wage: int = int(int(base_wage) * economy_index * 1000 / 1000000.0)

	var spouse_id: String = "spouse"
	var spouse: Dictionary = {
		"id": spouse_id,
		"name": spouse_name,
		"sex": spouse_sex,
		"birth_year": spouse_birth_year,
		"age": spouse_age,
		"alive": true,
		"death_year": 0,
		"death_cause": "",
		"health": 85,
		"constitution": 75,
		"willpower": 60,
		"literacy": 45,
		"conditions": {},
		"education_state": "completed",
		"occupation_id": occ_id,
		"income": spouse_wage,
		"work_capacity": 1000,
		"household_id": state.household.id,
		"traits": ["pragmatic"]
	}
	Needs.initialize_actor(spouse)
	Education.initialize_actor(spouse)
	Career.initialize_actor(spouse)

	delta.candidate.actors[spouse_id] = spouse
	if not delta.candidate.household.member_ids.has(spouse_id):
		delta.candidate.household.member_ids.append(spouse_id)
	delta.set_field("household", "income", int(state.household.income) + spouse_wage, cause_event)

	var fam: Dictionary = state.get("family", {}).duplicate(true)
	fam["marital_status"] = "married"
	fam["marriage_year"] = delta.year
	delta.set_field("family", "marital_status", "married", cause_event)
	delta.set_field("family", "marriage_year", delta.year, cause_event)

	Relationships.register_person(state, spouse_id, spouse_name, "spouse", true,
		"existing_relationship" if partner_id != "" else "courtship", spouse_sex)
	if partner_id != "" and partner_id != spouse_id:
		state.relationships.people.erase(partner_id)
		state.relationships.history.append({"year": delta.year, "kind": "relationship_became_marriage",
			"person_id": spouse_id, "former_person_id": partner_id})

	var marriage_event: String = delta.record("marriage_formed", cause_event, {
		"spouse_id": spouse_id,
		"name": spouse_name,
		"age": spouse_age,
		"occupation_id": occ_id,
		"income": spouse_wage
	})

	return marriage_event


static func advance(delta: RefCounted, pack: Dictionary, year_event: String, seed_value: int) -> void:
	if not pack.systems.get("family", false):
		return

	var state: Dictionary = delta.candidate
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	if not player.alive:
		return

	var fam: Dictionary = state.get("family", {})
	if fam.is_empty():
		return

	# Eşin hayatta kalma kontrolü
	if state.actors.has("spouse"):
		var spouse: Dictionary = state.actors["spouse"]
		if not spouse.alive and fam.get("marital_status") == "married":
			delta.set_field("family", "marital_status", "widowed", year_event)
			delta.record("spouse_bereavement", year_event, {"spouse_id": "spouse"})

	# Çocuk doğumu değerlendirmesi
	if fam.get("marital_status") != "married" or not state.actors.has("spouse"):
		return

	var spouse_actor: Dictionary = state.actors["spouse"]
	if not spouse_actor.alive:
		return

	var female_partner: Dictionary = player if player.sex == "female" else spouse_actor
	var female_partner_id: String = player_id if player.sex == "female" else "spouse"
	var female_age: int = int(female_partner.age)

	# Doğum yaş sınırı (18-42)
	if female_age < 18 or female_age > 42:
		return

	# Doğum aralığı ve çocuk sınırı
	var rules: Dictionary = pack.get("family_rules", {})
	var min_interval: int = int(rules.get("min_birth_interval_years", 2))
	var last_birth: int = int(fam.get("last_birth_year", 0))
	if last_birth > 0 and (delta.year - last_birth) < min_interval:
		return

	var max_children: int = int(rules.get("max_children", 6))
	var current_children: int = int(fam.get("children_count", 0))
	if current_children >= max_children:
		return

	# Gebe kalma zar atımı
	var conception_chance: int = int(rules.get("conception_chance_permille", 300))
	var roll: int = Rng.integer(seed_value, "family", delta.year, "birth", "conception", 0, 999)
	if roll >= conception_chance:
		return

	# Yeni çocuk oluşturuluyor
	var new_child_idx: int = current_children + 1
	var child_id: String = "child_" + str(new_child_idx)
	var child_sex: String = "female" if Rng.integer(seed_value, "family", delta.year, child_id, "sex", 0, 1) == 0 else "male"
	var name_pool: Array[String] = FEMALE_NAMES if child_sex == "female" else MALE_NAMES
	var name_idx: int = Rng.integer(seed_value, "family", delta.year, child_id, "name", 0, name_pool.size() - 1)
	var child_name: String = name_pool[name_idx] + " Thompson"

	var child: Dictionary = {
		"id": child_id,
		"name": child_name,
		"sex": child_sex,
		"birth_year": delta.year,
		"age": 0,
		"alive": true,
		"death_year": 0,
		"death_cause": "",
		"health": 80,
		"constitution": 70,
		"willpower": 50,
		"literacy": 0,
		"conditions": {},
		"education_state": "none",
		"occupation_id": "dependent",
		"income": 0,
		"work_capacity": 0,
		"household_id": state.household.id,
		"traits": []
	}
	Needs.initialize_actor(child)
	Education.initialize_actor(child)
	Career.initialize_actor(child)

	delta.candidate.actors[child_id] = child
	if not delta.candidate.household.member_ids.has(child_id):
		delta.candidate.household.member_ids.append(child_id)

	# Anneye doğum sağlık cezası
	var maternal_cost: int = int(rules.get("maternal_health_cost", 8))
	var new_maternal_health: int = clampi(int(female_partner.health) - maternal_cost, 1, 100)
	delta.set_field("actors", "health", new_maternal_health, year_event, female_partner_id)

	delta.set_field("family", "children_count", new_child_idx, year_event)
	delta.set_field("family", "last_birth_year", delta.year, year_event)

	Relationships.register_person(state, child_id, child_name, "child", true, "birth", child_sex)

	delta.record("child_born", year_event, {
		"child_id": child_id,
		"name": child_name,
		"sex": child_sex,
		"mother_id": female_partner_id
	})
