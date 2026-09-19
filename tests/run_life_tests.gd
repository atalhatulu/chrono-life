extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Health = preload("res://simulation/health_system.gd")
const Household = preload("res://simulation/household_system.gd")

var checks: int = 0
var failures: Array[String] = []
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
	pack = loaded.pack
	test_validation()
	test_death()
	test_health()
	test_education_and_responses()
	test_orphan_care()
	test_schedule_and_causality()
	test_lives()
	print("Life systems: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func calm_pack() -> Dictionary:
	var calm: Dictionary = pack.duplicate(true)
	calm.systems.health = false
	calm.systems.adaptation = false
	calm.systems.storylets = false
	calm.economy.annual_drift = 0
	calm.economy.food_annual_drift = 0
	calm.world_rules.employment_min = 0
	calm.world_rules.employment_max = 0
	return calm


func death(id: String, fraction: int = 500) -> Dictionary:
	return {"id": "death:" + id, "type": "actor_died", "actor_id": id,
		"worked_permille": fraction, "cause": "test_accident"}


func count_events(state: Dictionary, kind: String, actor_id: String = "") -> int:
	var count: int = 0
	for event: Dictionary in state.history:
		if event.kind == kind and (actor_id == "" or event.details.get("actor_id", "") == actor_id):
			count += 1
	return count


func test_validation() -> void:
	var bad: Dictionary = pack.duplicate(true)
	bad.conditions[0].mortality_bp = 10001
	check(not Content.validate(bad).is_empty(), "Invalid mortality probability rejected")
	bad = pack.duplicate(true)
	bad.conditions.append(bad.conditions[0].duplicate())
	check(not Content.validate(bad).is_empty(), "Duplicate condition rejected")
	bad = pack.duplicate(true)
	bad.conditions[0].exposure = "invented"
	check(not Content.validate(bad).is_empty(), "Unknown exposure rejected")
	bad = pack.duplicate(true)
	bad.health_rules.mortality_bands.reverse()
	check(not Content.validate(bad).is_empty(), "Unordered mortality bands rejected")
	bad = pack.duplicate(true)
	bad.education_rules.start_age = 20
	check(not Content.validate(bad).is_empty(), "Inverted school ages rejected")
	bad = pack.duplicate(true)
	bad.response_rules.weights.wait = 0
	check(not Content.validate(bad).is_empty(), "Response selection requires fallback")
	bad = pack.duplicate(true)
	bad.world_rules.disease_min = "invalid"
	check(not Content.validate(bad).is_empty(), "String disease_min rejected without script error")
	bad = pack.duplicate(true)
	bad.education_rules.start_age = "invalid"
	check(not Content.validate(bad).is_empty(), "String start_age rejected without script error")
	bad = pack.duplicate(true)
	bad.response_rules.weights.wait = "invalid"
	check(not Content.validate(bad).is_empty(), "String wait weight rejected without script error")
	bad = pack.duplicate(true)
	bad.occupations[1].maximum_age = "invalid"
	check(not Content.validate(bad).is_empty(), "String maximum_age rejected without script error")
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42)
	var bad_state: Dictionary = state.duplicate(true)
	bad_state.household.care_mode = "unknown_mode"
	check(not runner.validate_state(bad_state).is_empty(), "Invalid care mode rejected")
	bad_state = state.duplicate(true)
	bad_state.household.guardian_id = "ghost_actor"
	check(not runner.validate_state(bad_state).is_empty(), "Unknown guardian rejected")
	bad_state = state.duplicate(true)
	bad_state.household.aid_uses = -1
	check(not runner.validate_state(bad_state).is_empty(), "Negative aid_uses rejected")
	bad_state = state.duplicate(true)
	bad_state.actors.player.conditions = {"malnutrition": {"acquired_year": 1840, "remaining_years": 1}}
	check(not runner.validate_state(bad_state).is_empty(), "Pre-start acquired_year rejected")
	bad_state = state.duplicate(true)
	bad_state.actors.player.conditions = {"malnutrition": {"acquired_year": 1850, "remaining_years": 0}}
	check(not runner.validate_state(bad_state).is_empty(), "Zero remaining_years rejected")


func test_death() -> void:
	var runner = Runner.new(calm_pack())
	var state: Dictionary = runner.initial_state(42)
	var result: Dictionary = runner.step(state, [death("parent_1")])
	check(result.ok, "Parent death commits successfully")
	if not result.ok:
		printerr(result.errors)
		return
	var after: Dictionary = result.state
	check(not after.actors.parent_1.alive and after.actors.parent_1.income == 0,
		"Death ends active income")
	check(after.ledgers[0].earned_by_actor.parent_1 == 1600, "Death preserves half-year earnings")
	check(after.ledgers[0].planned_expenses == 3950, "Death prorates food and personal essentials")
	check(Household.validate_ledger(after.ledgers[0]).is_empty(), "Death-year ledger balances")
	var duplicate: Dictionary = runner.step(state, [death("parent_1"), death("parent_1")])
	check(duplicate.ok and duplicate.state == after, "Duplicate death is idempotent")
	check(not runner.step(after, [death("parent_1")]).ok, "Dead actor cannot die in another year")
	var next: Dictionary = runner.step(after)
	check(next.ok and next.state.actors.parent_1.age == after.actors.parent_1.age,
		"Age at death remains frozen")
	check(next.state.ledgers.back().earned_by_actor.parent_1 == 0,
		"Dead actor produces no later wages")
	var job_loss: Dictionary = {"id": "loss", "type": "job_lost", "actor_id": "parent_1", "worked_permille": 100}
	var combined: Dictionary = runner.step(state, [death("parent_1", 750), job_loss])
	check(combined.ok and combined.state.ledgers[0].earned_by_actor.parent_1 == 320,
		"Job loss then death uses earliest income cutoff, not multiplied fractions")
	check(count_events(combined.state, "income_lost", "parent_1") == 1,
		"Death does not remove already-lost income twice")
	var terminal: Dictionary = runner.simulate_years(42, 120, {1851: [death("player")]})
	check(terminal.ok and terminal.status == "completed" and terminal.state.world.year == 1851,
		"Player death stops a long run immediately after committing that year")
	check(terminal.life_result.death_year == 1851 and terminal.life_result.cause_of_death == "test_accident",
		"LifeResult contains death attribution")
	check(not runner.step(terminal.state).ok, "Cannot advance an ended life")
	check(runner.simulate_life(42).status == "year_limit", "Safety horizon cannot invent mortality")
	var limited: Dictionary = calm_pack()
	limited.limits.max_consequences = 1
	var limited_runner = Runner.new(limited)
	var original: Dictionary = limited_runner.initial_state(42)
	var before: String = JSON.stringify(original)
	var rejected: Dictionary = limited_runner.step(original, [death("parent_1")])
	check(not rejected.ok and JSON.stringify(original) == before,
		"Death transaction rolls back completely on propagation overflow")


func test_health() -> void:
	var safe: Dictionary = calm_pack()
	safe.systems.health = true
	for band: Dictionary in safe.health_rules.mortality_bands:
		band.risk_bp = 0
	for condition: Dictionary in safe.conditions:
		condition.incidence_bp = 0
		condition.mortality_bp = 0
	safe.conditions[0].incidence_bp = 10000
	var runner = Runner.new(safe)
	var state: Dictionary = runner.initial_state(42)
	state.household.food_security = 100
	var result: Dictionary = runner.step(state)
	check(result.ok and result.state.actors.player.conditions.has("malnutrition"),
		"Previous-year food insecurity causes a nutritional condition")
	check(result.state.actors.parent_1.income < 3200, "Condition reduces earning capacity")
	check(result.state.actors.player.health < 100, "Condition affects visible health")
	var recovered: Dictionary = runner.step(result.state)
	check(recovered.ok and not recovered.state.actors.player.conditions.has("malnutrition"),
		"Restored nutrition allows condition recovery")
	state = runner.initial_state(42)
	state.actors.player.conditions = {"workplace_injury": {"acquired_year": 1850, "remaining_years": 1}}
	check(not runner.step(state).state.actors.player.conditions.has("workplace_injury"),
		"Finite condition expires once")
	state = runner.initial_state(42)
	state.actors.player.conditions = {"chronic_disease": {"acquired_year": 1850, "remaining_years": -1}}
	check(runner.step(state).state.actors.player.conditions.has("chronic_disease"),
		"Chronic condition persists")
	var definitions: Dictionary = {}
	for condition: Dictionary in pack.conditions:
		definitions[condition.id] = condition
	var actor: Dictionary = {"age": 30, "constitution": 60, "conditions": {}}
	var base_risk: int = Health.mortality_risk(actor, definitions, pack.health_rules)
	actor.conditions.chronic_disease = {}
	check(Health.mortality_risk(actor, definitions, pack.health_rules) > base_risk,
		"Conditions increase mortality hazard")
	actor.conditions.clear()
	actor.age = 1
	check(Health.mortality_risk(actor, definitions, pack.health_rules) > base_risk,
		"First annual interval uses infant mortality band")
	var fatal: Dictionary = safe.duplicate(true)
	for band: Dictionary in fatal.health_rules.mortality_bands:
		band.risk_bp = 10000
	var fatal_runner = Runner.new(fatal)
	state = fatal_runner.initial_state(42)
	state.actors.player.constitution = 0
	result = fatal_runner.step(state)
	check(result.ok and not result.state.actors.player.alive, "Health system emits actual death consequence")
	check(count_events(result.state, "actor_died", "player") == 1, "Mortality cannot kill the player twice")


func test_education_and_responses() -> void:
	var rules: Dictionary = calm_pack()
	rules.systems.adaptation = true
	rules.response_rules.weights.child_work = 10000
	rules.response_rules.weights.seek_aid = 0
	var runner = Runner.new(rules)
	var state: Dictionary = runner.simulate_years(42, 7).state
	check(state.actors.player.education_state == "basic_schooling" and state.actors.player.literacy == 20,
		"School begins at configured age and advances literacy")
	state.household.savings = 0
	var poor: Dictionary = runner.step(state, [death("parent_1", 0)])
	check(poor.ok and not poor.state.household.pending_effects.is_empty(),
		"Household pressure can select a deferred adaptation")
	check(poor.state.actors.player.occupation_id == "dependent" and poor.state.actors.player.education_state == "basic_schooling",
		"Selecting work next year does not retroactively interrupt this year's school")
	var next: Dictionary = runner.step(poor.state)
	check(next.ok and (next.state.actors.player.occupation_id in ["child_factory_worker", "chimney_sweep", "piecer"]),
		"Eligible child starts selected work the following year")
	check(next.state.actors.player.education_state == "interrupted" and next.state.actors.player.literacy == poor.state.actors.player.literacy,
		"Work interrupts schooling and its literacy progression")
	check(count_events(next.state, "school_interrupted", "player") == 1,
		"Educational interruption is recorded once")
	var rich: Dictionary = state.duplicate(true)
	rich.household.savings = 100000
	var cushioned: Dictionary = runner.step(rich, [death("parent_1", 0)])
	check(cushioned.ok and cushioned.state.household.pending_effects.is_empty(),
		"Savings buffer prevents the same loss from forcing child work")
	var early: Dictionary = runner.initial_state(42)
	early.household.savings = 0
	var toddler: Dictionary = runner.step(early, [death("parent_1", 0)])
	check(toddler.ok and toddler.state.household.pending_effects.is_empty(),
		"Too-young child cannot be selected for work")
	var uninterrupted: Dictionary = runner.simulate_years(42, 17)
	check(uninterrupted.ok and uninterrupted.state.actors.player.education_state == "completed",
		"Supported child can complete basic schooling")
	check(uninterrupted.state.actors.player.income > 0, "Adult player can independently find employment")
	var job_loss: Dictionary = {"id": "loss", "type": "job_lost", "actor_id": "parent_1", "worked_permille": 500}
	var unemployed: Dictionary = runner.step(runner.initial_state(42), [job_loss])
	check(runner.step(unemployed.state).state.actors.parent_1.income > 0,
		"Available work permits adult reemployment")
	var help_rules: Dictionary = rules.duplicate(true)
	help_rules.response_rules.weights.child_work = 0
	help_rules.response_rules.weights.seek_aid = 10000
	var helper = Runner.new(help_rules)
	var help_state: Dictionary = helper.initial_state(42)
	help_state.household.savings = 0
	var planned: Dictionary = helper.step(help_state, [death("parent_1", 0)])
	var received: Dictionary = helper.step(planned.state)
	check(received.ok and received.state.ledgers.back().external_income == help_rules.response_rules.aid_amount,
		"Selected aid arrives next year and is accounted separately from wages")
	check(Household.validate_ledger(received.state.ledgers.back()).is_empty(), "Aid preserves cash conservation")
	var growing: Dictionary = next.state
	while growing.world.year < 1866:
		var tick: Dictionary = runner.step(growing)
		if not tick.ok:
			check(false, "Child-to-adult career transition runs")
			return
		growing = tick.state
	check(growing.actors.player.occupation_id != "child_factory_worker",
		"Adult cannot remain in age-restricted child job")


func test_orphan_care() -> void:
	var rules: Dictionary = calm_pack()
	rules.systems.adaptation = true
	var runner = Runner.new(rules)
	var state: Dictionary = runner.initial_state(42)
	var orphan: Dictionary = runner.step(state, [death("parent_1", 0), death("parent_2", 0)])
	check(orphan.ok and orphan.state.household.care_mode == "institutional",
		"Loss of both guardians activates explicit placeholder care")
	check(orphan.state.household.guardian_id == "", "Infant is not assigned household decision authority")
	check(orphan.state.ledgers[0].external_income == rules.response_rules.orphan_support_per_child,
		"Orphan support appears as external income")
	var next: Dictionary = runner.step(orphan.state)
	check(next.ok and next.state.actors.player.occupation_id == "dependent",
		"Orphan childhood progresses without impossible work")


func test_schedule_and_causality() -> void:
	var runner = Runner.new(pack)
	# Yapısal takvim doğrulama
	var bad_schedule: Dictionary = {1852: [{"id": "s1", "type": "bad_type", "actor_id": "player", "worked_permille": 500}]}
	var res: Dictionary = runner.simulate_years(42, 10, bad_schedule)
	check(not res.ok, "Malformed schedule command type rejected upfront")
	bad_schedule = {1852: [{"id": "s1", "type": "job_lost", "actor_id": "ghost", "worked_permille": 500}]}
	res = runner.simulate_years(42, 10, bad_schedule)
	check(not res.ok, "Unknown schedule actor rejected upfront")
	bad_schedule = {1852: [{"id": "s1", "type": "job_lost", "actor_id": "parent_1", "worked_permille": 500, "skip_if_unavailable": "not_bool"}]}
	res = runner.simulate_years(42, 10, bad_schedule)
	check(not res.ok, "Non-boolean skip_if_unavailable rejected upfront")
	# Step komutunda geçersiz skip_if_unavailable
	var step_cmd: Dictionary = {"id": "loss", "type": "job_lost", "actor_id": "parent_1", "worked_permille": 500, "skip_if_unavailable": 123}
	check(not runner.step(runner.initial_state(42), [step_cmd]).ok, "Non-boolean skip_if_unavailable in step rejected")

	# Ertelenen etkinin ölüm/uygunsuzluk durumunda iptali
	var rules: Dictionary = calm_pack()
	rules.systems.adaptation = true
	var adapt_runner = Runner.new(rules)
	var state: Dictionary = adapt_runner.initial_state(42)
	state.household.pending_effects = [{"id": "parent_1:sewing_worker", "type": "start_job",
		"actor_id": "parent_1", "occupation_id": "sewing_worker", "due_year": 1852, "cause_id": "1850:test"}]
	var dead_step: Dictionary = adapt_runner.step(state, [death("parent_1", 500)])
	check(dead_step.ok, "Parent dies while having pending job effect")
	var next_step: Dictionary = adapt_runner.step(dead_step.state)
	check(next_step.ok, "Year advances after parent death")
	check(not next_step.state.actors.parent_1.alive and next_step.state.actors.parent_1.occupation_id == "dependent",
		"Dead actor was not assigned deferred job")
	check(count_events(next_step.state, "deferred_effect_cancelled", "parent_1") == 1,
		"Cancelled deferred effect recorded for dead actor")

	# Sağlık kaynaklı gelir değişiminin nedensel bağı
	var safe: Dictionary = calm_pack()
	safe.systems.health = true
	for cond: Dictionary in safe.conditions:
		cond.incidence_bp = 0
		cond.mortality_bp = 0
	safe.conditions[0].incidence_bp = 10000 # malnutrition
	var health_runner = Runner.new(safe)
	var hstate: Dictionary = health_runner.initial_state(42)
	hstate.household.food_security = 100
	var hresult: Dictionary = health_runner.step(hstate)
	check(hresult.ok, "Health step commits")
	var health_event_id: String = ""
	var income_change_cause: String = ""
	for ev: Dictionary in hresult.events:
		if ev.kind == "health_evaluated" and ev.details.get("actor_id") == "parent_1":
			health_event_id = ev.id
		if ev.kind == "state_changed" and ev.details.get("actor_id") == "parent_1" and ev.details.get("field") == "income":
			income_change_cause = ev.cause_id
	check(health_event_id != "" and income_change_cause == health_event_id,
		"Income change caused by health evaluation points directly to health_evaluated event")


func test_lives() -> void:
	var runner = Runner.new(pack)
	var first: Dictionary = runner.simulate_life(42)
	var again: Dictionary = runner.simulate_life(42)
	check(first.ok and again.ok and first.fingerprint == again.fingerprint,
		"Full life replay includes identical health, adaptation and death")
	var all_valid: bool = true
	var completed: int = 0
	var signatures: Dictionary = {}
	var total_deaths: int = 0
	var valid_causes: bool = true
	for seed_value: int in range(100):
		var result: Dictionary = runner.simulate_life(seed_value)
		if not result.ok:
			printerr("Seed %d: %s" % [seed_value, result.errors])
			all_valid = false
			continue
		if result.status == "completed":
			completed += 1
		if not runner.validate_state(result.state).is_empty():
			all_valid = false
		var seen: Dictionary = {}
		var deaths: Dictionary = {}
		for event: Dictionary in result.state.history:
			if seen.has(event.id) or (event.cause_id != "" and not seen.has(event.cause_id)):
				valid_causes = false
			seen[event.id] = true
			if event.kind == "actor_died":
				if deaths.has(event.details.actor_id):
					all_valid = false
				deaths[event.details.actor_id] = true
				total_deaths += 1
		for ledger: Dictionary in result.state.ledgers:
			if not Household.validate_ledger(ledger).is_empty():
				all_valid = false
		signatures[JSON.stringify(result.life_result)] = true
	check(all_valid, "100 full-life seeds preserve invariants, single deaths and balanced ledgers")
	check(valid_causes, "Full-life causal parents precede children, including deferred events")
	check(completed > 90 and total_deaths >= completed, "Mortality naturally completes the test cohort")
	check(signatures.size() > 20, "Cohort has varied ages, causes and education outcomes")
