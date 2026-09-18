extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Actions = preload("res://simulation/life_action_system.gd")
const Purchases = preload("res://simulation/purchase_system.gd")
const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const SocialEvents = preload("res://simulation/social_event_system.gd")
const Treatments = preload("res://simulation/health_treatment_system.gd")
const Housing = preload("res://simulation/housing_system.gd")
const Family = preload("res://simulation/family_system.gd")
const Delta = preload("res://simulation/year_delta.gd")
const FamilyDynamics = preload("res://simulation/family_dynamics_system.gd")
const FamilyEvents = preload("res://simulation/family_event_system.gd")
const HouseholdNetwork = preload("res://simulation/household_network_system.gd")
const Hobbies = preload("res://simulation/hobby_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Assets = preload("res://simulation/asset_system.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")
const Migration = preload("res://simulation/migration_system.gd")

var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	var loaded: Dictionary = Content.load_pack()
	if not loaded.ok:
		printerr(loaded.errors)
		quit(1)
		return
	var runner = Runner.new(loaded.pack)
	var state: Dictionary = runner.initial_state(42)
	check(state.actors.player.has("needs"), "Initial player has life needs")
	check(state.actors.player.has("education"), "Initial player has generic education state")
	check(state.actors.player.has("career"), "Initial player has generic career state")
	check(str(state.meta.get("relationships_path", "")) != "", "Relationship content path is carried into state")
	check(str(state.meta.get("health_path", "")) != "", "Health content path is carried into state")
	check(str(state.meta.get("housing_path", "")) != "", "Housing content path is carried into state")
	check(str(state.meta.get("skills_path", "")) != "", "Skills content path is carried into state")
	check(str(state.meta.get("hobbies_path", "")) != "", "Hobbies content path is carried into state")
	check(str(state.meta.get("personality_path", "")) != "", "Personality content path is carried into state")
	check(str(state.meta.get("assets_path", "")) != "", "Asset content path is carried into state")
	check(str(state.meta.get("status_path", "")) != "", "Status content path is carried into state")
	check(str(state.meta.get("migration_path", "")) != "", "Migration content path is carried into state")
	check(state.has("assets"), "Initial state has assets")
	check(state.has("social_status"), "Initial state has social status")
	check(state.has("migration"), "Initial state has migration state")
	check(state.assets.owned.has("heirloom_watch"), "Configured initial asset is owned")
	check(state.actors.player.has("skills"), "Initial player has skills state")
	check(state.actors.player.has("hobbies"), "Initial player has hobbies state")
	check(state.actors.player.has("personality"), "Initial player has personality state")
	check(str(state.housing.get("dwelling_id", "")) != "", "Initial housing state is created")
	check(Housing.annual_cost(state) > 0, "Current dwelling contributes an annual housing cost")
	state.actors.player.age = 16
	state.world.year = state.actors.player.birth_year + 16
	var social_id := Relationships.meet_person(state, "social_venue")
	check(social_id != "", "Relationship system can create era-specific encounters")
	if social_id != "":
		state.relationships.people[social_id].closeness = 75
		state.relationships.people[social_id].trust = 70
		state.relationships.people[social_id].conflict = 65
		var social_event := SocialEvents.resolve_one(state)
		check(not social_event.is_empty(), "Relationship state can produce a social event")
		check(state.history.any(func(e): return e.kind == "social_event"), "Social events are written to life history")
	PersonalEconomy.grant_income(state, 200, "health_test")
	state.actors.player.conditions = {"epidemic_disease": {"acquired_year": int(state.world.year), "remaining_years": 1, "severity": 70}}
	var treatment_options := Treatments.available_treatments(state)
	check(not treatment_options.is_empty(), "Active conditions expose matching treatments")
	if not treatment_options.is_empty():
		var treatment_result := Treatments.apply(state, str(treatment_options[0].id))
		check(treatment_result.ok, "Treatment can be applied through generic health content")
	check(str(state.meta.get("education_path", "")) != "", "Education content path is carried into state")
	check(Actions.available_actions(state).has("rest"), "Rest is available from birth")
	check(not Actions.available_actions(state).has("work_hard"), "Infant cannot work hard")
	PersonalEconomy.grant_income(state, 200, "test")
	check(Purchases.available_items(state).any(func(i): return i.id == "doctor_visit"), "Age-appropriate meaningful purchases are available")
	var future_gate_state: Dictionary = runner.initial_state(91)
	future_gate_state.actors.player.age = 12
	PersonalEconomy.grant_income(future_gate_state, 200, "future_gate_test")
	check(not Purchases.available_items(future_gate_state).any(func(i): return i.id == "cheap_newspaper"),
		"Future-dated purchases remain locked before their configured year")
	var before_cash := int(state.personal_economy.cash)
	var bought: Dictionary = Purchases.purchase(state, "doctor_visit")
	check(bought.ok and int(state.personal_economy.cash) < before_cash, "Purchase spends personal cash")
	PersonalEconomy.grant_income(state, 500, "meaningful_spending_test")
	state.actors.player.age = 16
	state.world.year = state.actors.player.birth_year + 16
	check(not Purchases.available_items(state).any(func(i): return i.id == "coat"), "Routine clothing is not player-facing")
	var society_buy: Dictionary = Purchases.purchase(state, "friendly_society_dues")
	check(society_buy.ok, "Meaningful membership can be purchased")
	check(not Purchases.available_items(state).any(func(i): return i.id == "friendly_society_dues"), "Active membership cannot be renewed early")

	var development_state: Dictionary = runner.initial_state(55)
	development_state.actors.player.age = 16
	development_state.world.year = development_state.actors.player.birth_year + 16
	var curiosity_before := int(development_state.actors.player.personality.axes.curiosity)
	var dev_one := Actions.apply(development_state, "self_education")
	var dev_two := Actions.apply(development_state, "self_education")
	check(dev_one.ok and dev_two.ok, "Repeated life actions can drive long-term development")
	check(int(development_state.actors.player.personality.axes.curiosity) > curiosity_before,
		"Life actions shift personality axes")
	check(int(development_state.actors.player.skills["values"].reading_comprehension) > 0,
		"Life actions convert repeated skill XP into skill levels")
	check(development_state.actors.player.hobbies.active.has("reading"),
		"Linked life actions establish hobby progress")
	var hobby_before := int(development_state.actors.player.hobbies.active.reading.mastery)
	development_state.world.year += 1
	development_state.actors.player.age += 1
	var hobby_result := Hobbies.practice(development_state, "player", "reading", "test")
	check(hobby_result.ok and int(development_state.actors.player.hobbies.active.reading.mastery) > hobby_before,
		"Manual hobby practice increases mastery")

	var jobs := Content.occupations_by_id(loaded.pack)
	var career_probe: Dictionary = development_state.actors.player
	career_probe.age = 25
	career_probe.literacy = 50
	career_probe.career.track_experience["textile"] = 5
	check(not Career.eligible(career_probe, jobs.skilled_textile_worker, 25),
		"Skill requirements can block an otherwise qualified career")
	career_probe.skills["values"].craftsmanship = 5
	career_probe.skills["values"].work_discipline = 5
	check(Career.eligible(career_probe, jobs.skilled_textile_worker, 25),
		"Skill growth can unlock a qualified career")

	var mobility_state: Dictionary = runner.initial_state(88)
	mobility_state.actors.player.age = 22
	mobility_state.world.year = mobility_state.actors.player.birth_year + 22
	PersonalEconomy.grant_income(mobility_state, 5000, "mobility_test")
	var status_before := int(mobility_state.social_status.score)
	var asset_result := Assets.acquire(mobility_state, "work_tools")
	check(asset_result.ok, "Player can acquire a persistent asset")
	check(mobility_state.assets.owned.has("work_tools"), "Acquired asset is stored in persistent asset state")
	check(Assets.total_value(mobility_state) > 0, "Persistent assets contribute durable value")
	SocialStatus.recompute(mobility_state)
	check(int(mobility_state.social_status.score) >= 0 and int(mobility_state.social_status.score) <= 100,
		"Social status recomputes into a valid score")
	check(int(mobility_state.social_status.score) >= status_before or mobility_state.social_status.band_id != "",
		"Asset-aware status remains classified after recompute")
	var destinations := Migration.available_destinations(mobility_state)
	check(not destinations.is_empty(), "Eligible adult with cash can see migration destinations")
	if not destinations.is_empty():
		var destination_id := str(destinations[0].id)
		var move_result := Migration.move_to(mobility_state, destination_id)
		check(move_result.ok, "Migration can move the player household")
		check(str(mobility_state.world.location_id) == destination_id, "Migration updates world location")
		check(str(mobility_state.household.location_id) == destination_id, "Migration updates household location")
		check(str(mobility_state.migration.current_location_id) == destination_id, "Migration state tracks current location")
		check(not mobility_state.migration.history.is_empty(), "Migration history records the move")
		check(str(mobility_state.households[mobility_state.household.id].location_id) == destination_id,
			"Migration updates primary household registry location")

	var cash_before_liquidation := int(mobility_state.personal_economy.cash)
	var liquidation_result := Assets.liquidate(mobility_state, "work_tools")
	check(liquidation_result.ok, "Owned assets can be liquidated")
	check(int(mobility_state.personal_economy.cash) > cash_before_liquidation,
		"Asset liquidation returns value to personal cash")
	check(not mobility_state.assets.owned.has("work_tools"),
		"Non-stackable asset is removed after liquidation")

	var family_state: Dictionary = runner.initial_state(77)
	Family.ensure_state(family_state)
	check(family_state.family.kinship.has("player"), "Player has kinship record")
	check(family_state.family.kinship.player.parents.size() >= 2, "Initial parents are linked in kinship graph")
	var adult_child: Dictionary = family_state.actors.player.duplicate(true)
	adult_child.id = "child_test"
	adult_child.name = "Test Child"
	adult_child.birth_year = int(family_state.world.year) - 22
	adult_child.age = 22
	adult_child.occupation_id = "textile_worker"
	adult_child.income = 3200
	adult_child.household_id = family_state.household.id
	family_state.actors[adult_child.id] = adult_child
	family_state.household.member_ids.append(adult_child.id)
	family_state.family.children_ids.append(adult_child.id)
	family_state.family.children_count = family_state.family.children_ids.size()
	var leave_pack: Dictionary = loaded.pack.duplicate(true)
	leave_pack.family_rules.adult_child_leave_min_age = 18
	leave_pack.family_rules.adult_child_leave_base_permille = 1000
	leave_pack.family_rules.adult_child_leave_employed_bonus_permille = 0
	var family_delta = Delta.new(family_state, int(family_state.world.year) + 1)
	Family.advance(family_delta, leave_pack, "test:family", 77)
	check("child_test" not in family_delta.candidate.household.member_ids, "Adult child can leave the household")
	check(family_delta.candidate.actors.has("child_test"), "Child remains an actor after leaving home")
	check(str(family_delta.candidate.actors.child_test.household_id) != str(family_delta.candidate.household.id),
		"Adult child receives an independent household")
	check(family_delta.candidate.households.has(str(family_delta.candidate.actors.child_test.household_id)),
		"Independent household is registered")

	var descendant_pack: Dictionary = leave_pack.duplicate(true)
	descendant_pack.family_rules.descendant_marriage_min_age = 18
	descendant_pack.family_rules.descendant_marriage_base_permille = 1000
	descendant_pack.family_rules.descendant_marriage_age_bonus_permille = 0
	descendant_pack.family_rules.descendant_birth_chance_permille = 1000
	descendant_pack.family_rules.descendant_max_children = 2
	family_delta.candidate.world.year += 1
	family_delta.candidate.actors.child_test.age += 1
	FamilyDynamics.advance(family_delta.candidate, descendant_pack, 77)
	check(family_delta.candidate.family.descendant_lives.has("child_test"),
		"Independent child receives descendant life state")
	check(str(family_delta.candidate.family.descendant_lives.child_test.partner_id) != "",
		"Independent child can form a partnership")
	check(family_delta.candidate.family.grandchildren_ids.size() >= 1,
		"Independent child can produce a grandchild actor")
	var grandchild_id := str(family_delta.candidate.family.grandchildren_ids[0])
	check(family_delta.candidate.actors.has(grandchild_id),
		"Grandchild exists as a real actor")
	check(str(family_delta.candidate.actors[grandchild_id].household_id) == str(family_delta.candidate.actors.child_test.household_id),
		"Grandchild belongs to the independent child's household")

	FamilyDynamics.initialize(family_delta.candidate)
	family_delta.candidate.family.parenting.child_test = {
		"involvement": 40, "support": 35, "discipline": 50, "conflict": 80,
		"last_active_year": int(family_delta.candidate.world.year)
	}
	family_delta.candidate.actors.parent_1.age = 70
	family_delta.candidate.actors.parent_1.health = 40
	FamilyDynamics.initialize(family_delta.candidate)
	var care_result := FamilyDynamics.care_for_parent(family_delta.candidate, "parent_1", "care")
	check(care_result.ok, "Player can provide elder care to an aging parent")
	check(int(family_delta.candidate.family.elder_care.parent_1.care) > 0,
		"Elder care is tracked in family state")
	var generated_family_event := FamilyEvents.resolve_one(family_delta.candidate)
	check(not generated_family_event.is_empty(), "Family state can generate a family event")
	var first: Dictionary = runner.simulate_auto_life(42, "balanced")
	var again: Dictionary = runner.simulate_auto_life(42, "balanced")
	check(first.ok and again.ok, "AutoLife completes without simulation errors")
	check(first.fingerprint == again.fingerprint, "AutoLife is deterministic for same seed and policy")
	check(first.life_result.has("actions"), "Death summary contains action history")
	check(first.life_result.has("personal_spending"), "Death summary includes personal spending")
	check(first.state.actors.player.education.has("history"), "AutoLife preserves education history")
	check(first.life_result.has("career"), "Life summary includes career history")
	check(first.life_result.has("skills"), "Life summary includes skill progression")
	check(first.life_result.has("personality"), "Life summary includes personality progression")
	check(first.life_result.has("hobbies"), "Life summary includes hobbies")
	check(first.life_result.has("assets"), "Life summary includes assets")
	check(first.life_result.has("social_status"), "Life summary includes social status")
	check(first.life_result.has("migration"), "Life summary includes migration history")
	check(first.life_result.has("relationships"), "Life summary includes relationship history")
	check(first.has("social_actions"), "AutoLife exposes social decisions")
	check(first.has("treatments"), "AutoLife exposes treatment history")
	check(first.state.has("housing"), "AutoLife preserves housing state")
	check(first.life_result.has("family_history"), "Life summary includes Family 2.0 history")
	check(first.life_result.has("parenting"), "Life summary includes parenting state")
	check(first.life_result.has("sibling_bonds"), "Life summary includes sibling bonds")
	check(first.life_result.has("descendant_lives"), "Life summary includes descendant lives")
	check(first.life_result.has("elder_care"), "Life summary includes elder care")
	check(first.has("parenting_actions"), "AutoLife exposes parenting decisions")
	check(first.has("family_events"), "AutoLife exposes family events")
	check(first.has("elder_care_actions"), "AutoLife exposes elder-care decisions")
	check(first.state.family.has("kinship"), "Family 2.0 maintains kinship graph")
	check(first.has("purchases"), "AutoLife exposes purchase history")
	check(first.has("hobbies"), "AutoLife exposes hobby choices")
	check(first.has("assets"), "AutoLife exposes asset acquisitions")
	check(first.has("migrations"), "AutoLife exposes migrations")
	check(first.state.history.any(func(e): return e.kind == "life_action"), "Life actions are recorded in history")
	var varied := {}
	for seed_value: int in range(20):
		var result: Dictionary = runner.simulate_auto_life(seed_value, "balanced")
		check(result.ok, "AutoLife seed %d remains valid" % seed_value)
		if result.ok:
			varied[result.fingerprint] = true
	check(varied.size() > 5, "AutoLife cohort produces varied lives")
	print("%d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
