extends SceneTree
## Regressions for the shared lifecycle and the multi-household merge.
const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Delta = preload("res://simulation/year_delta.gd")
const Family = preload("res://simulation/family_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Education = preload("res://simulation/education_system.gd")
const Household = preload("res://simulation/household_system.gd")
const Personal = preload("res://simulation/personal_economy_system.gd")
var checks: int = 0
var failures: Array[String] = []

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
	var pack: Dictionary = loaded.pack
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(19)
	state.actors.player.birth_year = 1820
	state.actors.player.age = 30
	var delta = Delta.new(state, int(state.world.year))
	var cash_before: int = int(state.household.savings)
	Family.create_spouse(delta, pack, "test", 19)
	var married: Dictionary = delta.candidate
	var spouse: Dictionary = married.actors[married.family.current_spouse_id]
	check(Career.eligible(spouse, runner.occupations[spouse.occupation_id], int(spouse.age)), "New spouse meets experience, education and skill requirements")
	check(runner.validate_state(married).is_empty(), "Marriage leaves a valid active income and household registry")
	check(int(married.household.savings) == cash_before, "New spouse does not retroactively add a year of wages")
	check(married.households[married.household.id].member_ids.has(spouse.id), "Spouse is registered in the primary household immediately")

	state = runner.initial_state(42)
	state.household.member_ids.erase("parent_2")
	var ledger: Dictionary = Household.calculate(state.household, state.actors, pack.economy, 1000,
		{"parent_1": 3200, "parent_2": 1800, "player": 0})
	check(ledger.earned_income == 3200 and not ledger.earned_by_actor.has("parent_2"), "External household wages are excluded from both total and breakdown")
	check(Household.validate_ledger(ledger).is_empty(), "Resident-only cash ledger conserves money")

	state = runner.initial_state(42)
	state.world.year = 1864
	state.actors.player.age = 14
	state.actors.player.education.current_stage = "elementary"
	state.actors.player.education_state = "basic_schooling"
	state.actors.player.education.progress = 60
	delta = Delta.new(state, 1864)
	Education.advance(delta, pack, "test")
	check(delta.candidate.actors.player.education.completed_stages.has("elementary"), "Age 14 graduates from a stage with max enrollment age 13")
	check(delta.candidate.actors.player.education.dropout_count == 0, "Graduation is not recorded as dropping out")
	delta.candidate.actors.player.age = 10
	Education.advance(delta, pack, "test")
	check(delta.candidate.actors.player.education.current_stage == "", "Already completed stages cannot enroll again")

	state = runner.initial_state(42)
	state.actors.parent_1.work_capacity = 0
	state.actors.parent_1.income = 0
	state.household.income = int(state.actors.parent_2.income)
	check(runner.validate_state(state).is_empty(), "An employed actor can become temporarily unable to earn")
	check(not Career.eligible(state.actors.parent_1, runner.occupations.textile_worker, 28), "Zero work capacity still prevents taking a new job")

	state = runner.initial_state(42)
	state.world.year = 1875
	state.actors.player.age = 25
	state.actors.player.income = 0 # Job lost after earning part of the year.
	state.ledgers = [{"year": 1875, "earned_by_actor": {"player": 1600}}]
	state.household.savings = 1000
	Personal.settle_year(state)
	check(state.personal_economy.cash == 560, "Personal share uses actual earned wages, including partial years")
	check(state.household.savings == 440, "Personal wages are transferred out of household savings")
	check(state.household.savings + state.personal_economy.cash == 1000, "Household plus personal cash is conserved")
	Personal.settle_year(state)
	check(state.personal_economy.cash == 560, "The same year cannot pay a wage share twice")
	state.world.year += 1
	state.ledgers[0].year += 1
	state.household.savings = 12
	Personal.settle_year(state)
	check(state.household.savings == 0 and state.personal_economy.cash == 572, "Allocations cannot overdraw the family reserve")
	state = runner.initial_state(42)
	state.world.year = 1857
	state.actors.player.age = 7
	state.household.savings = 3
	Personal.maybe_allowance(state)
	check(state.household.savings == 0 and state.personal_economy.cash == 3, "Child allowance transfers existing cash rather than minting money")
	Personal.maybe_allowance(state)
	check(state.personal_economy.cash == 3, "Allowance can only be paid once per year")

	var calm: Dictionary = pack.duplicate(true)
	calm.systems.health = false
	calm.systems.storylets = false
	calm.systems.family = false
	calm.actors[0].birth_year = 1825
	calm.actors[0].occupation_id = "textile_worker"
	calm.economy.initial_savings = 10000
	var calm_runner = Runner.new(calm)
	state = calm_runner.initial_state(42)
	var before: String = JSON.stringify(state)
	var prep: Dictionary = calm_runner.step_prepare(state)
	check(prep.ok and JSON.stringify(state) == before, "Preparing a year leaves authoritative needs and money untouched")
	var resolved: Dictionary = calm_runner.step_resolve(prep)
	check(resolved.ok and resolved.state.personal_economy.cash > 0, "Manual choice resolution receives the shared annual wage allocation")
	check(resolved.ok and int(resolved.state.personal_economy.last_settlement_year) == 1851, "Manual lifecycle settles the newly completed year")
	var automatic: Dictionary = calm_runner.auto_step(state)
	check(automatic.ok and int(automatic.state.personal_economy.last_settlement_year) == 1851, "AutoLife uses the same annual settlement")
	print("Integration: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
