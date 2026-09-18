extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Storylets = preload("res://simulation/storylet_engine.gd")
const Family = preload("res://simulation/family_system.gd")
const Household = preload("res://simulation/household_system.gd")

var checks: int = 0
var failures: Array[String] = []
var pack: Dictionary


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)


func get_total_active_income(state: Dictionary) -> int:
	var total: int = 0
	for actor: Dictionary in state.actors.values():
		if actor.alive:
			total += int(actor.income)
	return total


func _initialize() -> void:
	var loaded: Dictionary = Content.load_pack()
	if not loaded.ok:
		printerr(loaded.errors)
		quit(1)
		return
	pack = loaded.pack
	test_family_validation()
	test_marriage_mechanics()
	test_childbirth_and_interval()
	test_widowhood()
	test_household_budget_impact()
	test_family_cohort_invariants()
	print("Family systems: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func test_family_validation() -> void:
	var bad: Dictionary = pack.duplicate(true)
	bad.systems.family = "yes" # boolean degil
	check(not Content.validate(bad).is_empty(), "Reject non-boolean systems.family")

	bad = pack.duplicate(true)
	bad.family_rules.erase("min_marriage_age")
	check(not Content.validate(bad).is_empty(), "Reject missing family rule")

	bad = pack.duplicate(true)
	bad.family_rules.min_marriage_age = -1
	check(not Content.validate(bad).is_empty(), "Reject negative marriage age")

	bad = pack.duplicate(true)
	bad.family_rules.conception_chance_permille = 1500
	check(not Content.validate(bad).is_empty(), "Reject invalid conception chance")


func test_marriage_mechanics() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)

	check(state.has("family"), "Initial state contains family dictionary")
	check(state.family.marital_status == "unmarried", "Initial marital status is unmarried")
	check(state.family.children_count == 0, "Initial children count is 0")
	check(not state.actors.has("spouse"), "No spouse initially")

	# 19 yasina kadar education_first politikasiyla ilerlet (evlenmeyi reddeder)
	while state.actors.player.age < 19 and state.actors.player.alive:
		var res: Dictionary = runner.step(state, [], {}, "education_first")
		check(res.ok, "Step ok before marriage age")
		state = res.state

	check(state.family.marital_status == "unmarried", "Player reaches 19 unmarried")
	check(not state.actors.has("spouse"), "No spouse before marriage decision")

	# Courtship storylet'ini bul
	var courtship_st: Dictionary = {}
	for st: Dictionary in pack.storylets:
		if st.id == "courtship_and_marriage":
			courtship_st = st
			break
	check(not courtship_st.is_empty(), "Courtship storylet exists in pack")

	# 1. Secenek: marry
	var prep_marry: Dictionary = runner.step_prepare(state)
	prep_marry.storylet = courtship_st
	var res_marry: Dictionary = runner.step_resolve(prep_marry, "marry")
	check(res_marry.ok, "Marriage resolution succeeds without invariant errors")
	var married_state: Dictionary = res_marry.state

	check(married_state.family.marital_status == "married", "Marital status transitions to married")
	check(married_state.family.marriage_year == married_state.world.year, "Marriage year recorded")
	check(married_state.actors.has("spouse"), "Spouse actor added to actors")
	check(married_state.household.member_ids.has("spouse"), "Spouse added to household members")

	var spouse: Dictionary = married_state.actors.spouse
	check(spouse.alive, "Spouse is alive")
	check(spouse.sex != married_state.actors.player.sex, "Spouse has opposite sex")
	check(spouse.age >= 16, "Spouse age is valid working age")
	check(spouse.education_state == "completed", "Spouse education state is completed")
	check(spouse.income > 0, "Spouse contributes positive wage")
	check(married_state.household.income == get_total_active_income(married_state),
		"Household income includes spouse wage immediately")

	# 2. Alternatif secenek: remain_single
	var prep_single: Dictionary = runner.step_prepare(state)
	prep_single.storylet = courtship_st
	var res_single: Dictionary = runner.step_resolve(prep_single, "remain_single")
	check(res_single.ok, "remain_single resolution succeeds")
	check(res_single.state.family.marital_status == "unmarried", "Marital status remains unmarried")
	check(not res_single.state.actors.has("spouse"), "No spouse added on remain_single")
	check(res_single.state.household.income == get_total_active_income(res_single.state),
		"Household income matches active actors when remaining single")


func test_childbirth_and_interval() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)

	# 19 yasina getir
	while state.actors.player.age < 19 and state.actors.player.alive:
		state = runner.step(state, [], {}, "education_first").state

	# Evlendir
	var prep: Dictionary = runner.step_prepare(state)
	for st: Dictionary in pack.storylets:
		if st.id == "courtship_and_marriage":
			prep.storylet = st
			break
	state = runner.step_resolve(prep, "marry").state
	check(state.family.marital_status == "married", "State is married for childbirth test")

	var birth_occurred: bool = false
	var birth_year: int = 0

	for i in range(20):
		if not state.actors.player.alive or not state.actors.spouse.alive:
			break
		var prev_children: int = state.family.children_count

		var step_res: Dictionary = runner.step(state, [], {}, "pragmatic")
		check(step_res.ok, "Step ok during marriage lifecycle")
		state = step_res.state

		if state.family.children_count > prev_children:
			birth_occurred = true
			birth_year = state.world.year
			var child_id: String = "child_" + str(state.family.children_count)
			check(state.actors.has(child_id), "Child actor exists in state.actors")
			check(state.household.member_ids.has(child_id), "Child in household members")
			var child: Dictionary = state.actors[child_id]
			check(child.age == 0, "Newborn age is 0")
			check(child.birth_year == birth_year, "Child birth year matches current year")
			check(child.occupation_id == "dependent", "Newborn is dependent")
			check(child.income == 0, "Newborn income is 0")
			check(state.family.last_birth_year == birth_year, "last_birth_year updated")
			break

	check(birth_occurred, "At least one child born during marriage lifecycle")
	if birth_occurred and state.actors.player.alive and state.actors.spouse.alive:
		# Bir sonraki yil (interval < 2) yeni cocuk dogmamali
		var next_step: Dictionary = runner.step(state, [], {}, "pragmatic")
		check(next_step.ok, "Next step after birth ok")
		if next_step.state.world.year == birth_year + 1:
			check(next_step.state.family.children_count == state.family.children_count,
				"No child born within minimum birth interval (2 years)")


func test_widowhood() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)

	while state.actors.player.age < 19 and state.actors.player.alive:
		state = runner.step(state, [], {}, "education_first").state

	var prep: Dictionary = runner.step_prepare(state)
	for st: Dictionary in pack.storylets:
		if st.id == "courtship_and_marriage":
			prep.storylet = st
			break
	state = runner.step_resolve(prep, "marry").state
	check(state.actors.has("spouse"), "Spouse created before widowhood test")

	# Es icin suni olum komutu gonder
	var spouse_death: Dictionary = {
		"id": "scenario_spouse_death",
		"type": "actor_died",
		"actor_id": "spouse",
		"worked_permille": 0,
		"cause": "cholera"
	}
	var step_res: Dictionary = runner.step(state, [spouse_death], {}, "pragmatic")
	check(step_res.ok, "Step with spouse death processed ok")
	var widowed_state: Dictionary = step_res.state

	check(not widowed_state.actors.spouse.alive, "Spouse is marked dead")
	check(widowed_state.family.marital_status == "widowed", "Marital status transitions to widowed")
	check(widowed_state.actors.spouse.income == 0, "Dead spouse has 0 income")
	check(widowed_state.household.income == get_total_active_income(widowed_state),
		"Household income drops back to active actors only after spouse death")


func test_household_budget_impact() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)

	while state.actors.player.age < 19 and state.actors.player.alive:
		state = runner.step(state, [], {}, "education_first").state

	var single_expenses: int = state.household.expenses

	var prep: Dictionary = runner.step_prepare(state)
	for st: Dictionary in pack.storylets:
		if st.id == "courtship_and_marriage":
			prep.storylet = st
			break
	state = runner.step_resolve(prep, "marry").state

	# Evlendikten sonraki yil hane masraflarini kontrol et
	var married_step: Dictionary = runner.step(state, [], {}, "pragmatic")
	check(married_step.ok, "Married step ok")
	var married_state: Dictionary = married_step.state
	check(married_state.household.expenses > single_expenses,
		"Household expenses increase with spouse in household")


func test_family_cohort_invariants() -> void:
	var runner = Runner.new(pack)
	var married_count: int = 0
	var children_born_total: int = 0
	var widowed_count: int = 0

	for s in range(50):
		var sim: Dictionary = runner.simulate_life(s, {}, "pragmatic")
		check(sim.ok, "Cohort seed %d preserves all invariants through entire life" % s)
		var final_state: Dictionary = sim.state
		var fam: Dictionary = final_state.get("family", {})
		if fam.get("marital_status") in ["married", "widowed"]:
			married_count += 1
		if fam.get("marital_status") == "widowed":
			widowed_count += 1
		children_born_total += int(fam.get("children_count", 0))

	check(married_count > 0, "Cohort produced marriages under pragmatic bot policy")
	check(children_born_total > 0, "Cohort produced childbirths")
