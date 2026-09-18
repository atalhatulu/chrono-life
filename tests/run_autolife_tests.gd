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
	check(not Purchases.available_items(state).any(func(i): return i.id == "cheap_newspaper"), "Future-dated purchases remain locked")
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
	var first: Dictionary = runner.simulate_auto_life(42, "balanced")
	var again: Dictionary = runner.simulate_auto_life(42, "balanced")
	check(first.ok and again.ok, "AutoLife completes without simulation errors")
	check(first.fingerprint == again.fingerprint, "AutoLife is deterministic for same seed and policy")
	check(first.life_result.has("actions"), "Death summary contains action history")
	check(first.life_result.has("personal_spending"), "Death summary includes personal spending")
	check(first.state.actors.player.education.has("history"), "AutoLife preserves education history")
	check(first.life_result.has("career"), "Life summary includes career history")
	check(first.life_result.has("relationships"), "Life summary includes relationship history")
	check(first.has("social_actions"), "AutoLife exposes social decisions")
	check(first.has("treatments"), "AutoLife exposes treatment history")
	check(first.state.has("housing"), "AutoLife preserves housing state")
	check(first.has("purchases"), "AutoLife exposes purchase history")
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
