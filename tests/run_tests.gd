extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Rng = preload("res://simulation/deterministic_rng.gd")
const Household = preload("res://simulation/household_system.gd")

var failures: Array[String] = []
var checks: int = 0
var pack: Dictionary


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)


func _initialize() -> void:
	var loaded: Dictionary = Content.load_pack()
	if not loaded.ok:
		printerr(loaded.errors)
		quit(1)
		return
	pack = loaded.pack.duplicate(true)
	# Preserve the Phase 0A economic regression fixture while testing life systems separately.
	pack.systems = {"health": false, "education": false, "adaptation": false}
	pack.limits.max_years = 30
	test_content()
	test_replay()
	test_ledger()
	test_shocks()
	test_rollback()
	test_batch()
	print("%d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func test_content() -> void:
	check(Content.validate(pack).is_empty(), "Valid content accepted")
	var bad: Dictionary = pack.duplicate(true)
	bad.occupations.append(bad.occupations[0].duplicate())
	check(not Content.validate(bad).is_empty(), "Duplicate occupation rejected")
	bad = pack.duplicate(true)
	bad.actors[0].occupation_id = "unknown"
	check(not Content.validate(bad).is_empty(), "Unknown occupation rejected")
	bad = pack.duplicate(true)
	bad.actors[0].occupation_id = "textile_worker"
	check(not Content.validate(bad).is_empty(), "Underage occupation rejected")
	bad = pack.duplicate(true)
	bad.economy.food_minimum_index = 2000
	check(not Content.validate(bad).is_empty(), "Invalid index range rejected")
	bad = pack.duplicate(true)
	bad.economy.rent = -1
	check(not Content.validate(bad).is_empty(), "Negative expense rejected")
	bad = pack.duplicate(true)
	bad.economy.rent = 1.5
	check(not Content.validate(bad).is_empty(), "Fractional monetary unit rejected")
	bad = pack.duplicate(true)
	bad.actors.append(bad.actors[0].duplicate())
	check(not Content.validate(bad).is_empty(), "Duplicate actor rejected")
	bad = pack.duplicate(true)
	bad.player_id = "absent"
	check(not Content.validate(bad).is_empty(), "Missing player rejected")
	bad = pack.duplicate(true)
	bad.occupations = ["broken"]
	check(not Content.validate(bad).is_empty(), "Malformed record rejected")
	check(not Content.load_pack("res://missing.json").ok, "Missing content fails explicitly")


func test_replay() -> void:
	var runner = Runner.new(pack)
	var original: Dictionary = runner.initial_state(42)
	var before: String = JSON.stringify(original, "", true)
	var first: Dictionary = runner.simulate_years(42, 20)
	var second: Dictionary = runner.simulate_years(42, 20)
	check(first.ok and second.ok, "Twenty-year simulation runs")
	check(first.fingerprint == second.fingerprint, "Same inputs produce identical full state and trace")
	check(first.state.ledgers != runner.simulate_years(43, 20).state.ledgers,
		"Different seeds change economic trajectories")
	var step_result: Dictionary = runner.step(original)
	check(step_result.ok and JSON.stringify(original, "", true) == before,
		"Successful step leaves input untouched")
	step_result.state.actors.player.name = "Changed"
	check(original.actors.player.name == "William Thompson", "Candidate has no nested alias into input")
	var expected: int = Rng.integer(42, "world", 1851, "manchester", "food", 0, 100000)
	Rng.integer(42, "health", 1851, "player", "unrelated", 0, 100000)
	check(Rng.integer(42, "world", 1851, "manchester", "food", 0, 100000) == expected,
		"Unrelated draws cannot perturb world randomness")
	var reordered: Dictionary = pack.duplicate(true)
	reordered.actors.reverse()
	var other_runner = Runner.new(reordered)
	check(first.state.ledgers == other_runner.simulate_years(42, 20).state.ledgers,
		"Actor declaration order cannot affect economics")
	var intermediate: Dictionary = runner.simulate_years(42, 10).state
	for index: int in range(10):
		intermediate = runner.step(intermediate).state
	check(JSON.stringify(intermediate, "", true) == JSON.stringify(first.state, "", true),
		"Continuing a state matches uninterrupted simulation")
	check(first.status == "year_limit" and first.state.actors.player.alive,
		"End of experiment does not invent a death")
	var known_ids: Dictionary = {}
	var valid_causes: bool = true
	for event: Dictionary in first.state.history:
		if event.cause_id != "" and not known_ids.has(event.cause_id):
			valid_causes = false
		if known_ids.has(event.id):
			valid_causes = false
		known_ids[event.id] = true
	check(valid_causes, "Trace IDs are unique and causal parents precede children")


func test_ledger() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)
	var earned: Dictionary = {"player": 0, "parent_1": 3200, "parent_2": 1800}
	var ledger: Dictionary = Household.calculate(state.household, state.actors, pack.economy, 1000, earned)
	check(ledger.planned_expenses == 4600 and ledger.closing_savings == 1200,
		"Known budget: 5000 income - 4600 expenses + 800 savings = 1200")
	check(Household.validate_ledger(ledger).is_empty(), "Known budget balances")
	earned.parent_1 = 0
	ledger = Household.calculate(state.household, state.actors, pack.economy, 1000, earned)
	check(ledger.savings_used == 800 and ledger.borrowed == 1800 and ledger.unmet_needs == 200,
		"Deficit consumes savings then bounded credit, leaving unfunded needs")
	check(ledger.closing_debt == 1800 and ledger.closing_savings == 0,
		"No negative savings or unlimited credit")
	state.household.savings = 0
	state.household.debt = 1800
	ledger = Household.calculate(state.household, state.actors, pack.economy, 1000, earned)
	check(ledger.borrowed == 0 and ledger.interest == 36 and ledger.closing_debt == 1836,
		"Interest is explicit; credit ceiling blocks further borrowing")
	check(ledger.food_security < 1000 and Household.validate_ledger(ledger).is_empty(),
		"Unfunded food lowers food security without breaking ledger")
	earned.parent_1 = 10000
	ledger = Household.calculate(state.household, state.actors, pack.economy, 1000, earned)
	check(ledger.debt_repaid == 1836 and ledger.closing_debt == 0 and ledger.closing_savings > 0,
		"Surplus repays debt before accumulating new savings")
	ledger.closing_savings += 1
	check(not Household.validate_ledger(ledger).is_empty(), "Cash conservation catches corruption")


func command(id: String = "loss_1") -> Dictionary:
	return {"id": id, "type": "job_lost", "actor_id": "parent_1", "worked_permille": 500}


func test_shocks() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)
	var baseline: Dictionary = runner.step(state)
	var shock: Dictionary = runner.step(state, [command()])
	check(shock.ok, "Income-loss consequence chain runs")
	check(shock.state.actors.parent_1.income == 0 and shock.state.actors.parent_1.occupation_id == "dependent",
		"Lost job stops active income")
	check(shock.state.ledgers[0].earned_by_actor.parent_1 ==
		int(baseline.state.actors.parent_1.income * 0.5), "Half-year loss preserves earnings before job loss")
	check(shock.state.household.income < shock.state.ledgers[0].earned_income,
		"Active annual income differs from realized annual earnings")
	var duplicate: Dictionary = runner.step(state, [command(), command()])
	check(duplicate.ok and duplicate.state == shock.state, "Duplicate trigger does not remove income twice")
	var rich: Dictionary = state.duplicate(true)
	rich.household.savings = 10000
	var rich_shock: Dictionary = runner.step(rich, [command()])
	check(rich_shock.state.household.debt < shock.state.household.debt,
		"Identical shock has different consequences when household has savings")
	var later: Dictionary = runner.step(shock.state)
	check(later.ok and later.state.ledgers.back().earned_by_actor.parent_1 == 0,
		"Income loss persists in the following year")
	check(not runner.step(state, [command(), command("different_id")]).ok,
		"Conflicting job losses are rejected")
	var bad_command: Dictionary = command()
	bad_command.worked_permille = 1001
	check(not runner.step(state, [bad_command]).ok, "Invalid event timing rejected")
	bad_command = command()
	bad_command.type = "invented"
	check(not runner.step(state, [bad_command]).ok, "Unknown effect type rejected")
	bad_command = command()
	bad_command.actor_id = "missing"
	check(not runner.step(state, [bad_command]).ok, "Unknown actor rejected")
	bad_command = command()
	bad_command.actor_id = "player"
	check(not runner.step(state, [bad_command]).ok, "Dependent cannot lose a nonexistent job")
	bad_command = command()
	bad_command.worked_permille = 100
	check(not runner.step(state, [command(), bad_command]).ok,
		"Conflicting payloads cannot reuse a command id")
	var at_start: Dictionary = command()
	at_start.worked_permille = 0
	check(runner.step(state, [at_start]).state.ledgers[0].earned_by_actor.parent_1 == 0,
		"Start-of-year loss yields no earnings")
	var at_end: Dictionary = command()
	at_end.worked_permille = 1000
	check(runner.step(state, [at_end]).state.ledgers[0].earned_by_actor.parent_1 ==
		baseline.state.actors.parent_1.income, "End-of-year loss retains full-year earnings")


func test_rollback() -> void:
	var restricted: Dictionary = pack.duplicate(true)
	restricted.limits.max_consequences = 1
	var runner = Runner.new(restricted)
	var state: Dictionary = runner.initial_state(42)
	var before: String = JSON.stringify(state, "", true)
	var result: Dictionary = runner.step(state, [command()])
	check(not result.ok and not result.has("state"), "Propagation overflow returns no committed state")
	check(JSON.stringify(state, "", true) == before, "Overflow cannot mutate authoritative input")
	check(result.has("diagnostic_events"), "Rejected transaction retains diagnostic trace")
	state.household.member_ids.append("player")
	check(not runner.step(state).ok, "Duplicate household membership rejected before tick")
	state = runner.initial_state(42)
	state.actors.parent_1.alive = false
	check(not runner.step(state).ok, "Dead earner violates invariant")
	state = runner.initial_state(42)
	state.meta.content_hash = "changed"
	check(not runner.step(state).ok, "Content mismatch rejected")
	state = runner.initial_state(42)
	state.household.savings = 0.5
	check(not runner.step(state).ok, "Fractional currency in state rejected")
	state = runner.initial_state(42)
	state.world.food_price_index = -100
	check(not runner.step(state).ok, "Invalid world index rejected")
	check(not runner.simulate_years(42, 31).ok, "Experiment cannot exceed configured horizon")
	check(not runner.simulate_years(42, 10, {1900: [command()]}).ok,
		"Out-of-range scenario cannot be silently ignored")


func test_batch() -> void:
	var runner = Runner.new(pack)
	var unique_trajectories: Dictionary = {}
	var all_valid: bool = true
	for seed_value: int in range(100):
		var result: Dictionary = runner.simulate_years(seed_value, 20, {1858: [command()]})
		if not result.ok:
			all_valid = false
			continue
		unique_trajectories[JSON.stringify(result.state.ledgers).sha256_text()] = true
		for ledger: Dictionary in result.state.ledgers:
			if not Household.validate_ledger(ledger).is_empty():
				all_valid = false
	check(all_valid, "100 seeds x 20 years maintain invariants and balanced ledgers")
	check(unique_trajectories.size() > 90, "Batch produces varied economic trajectories")
