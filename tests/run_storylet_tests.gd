extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Storylets = preload("res://simulation/storylet_engine.gd")
const BotPolicy = preload("res://simulation/bot_policy.gd")
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
	test_storylet_validation()
	test_eligibility_and_cooldown()
	test_choices_and_effects()
	test_childhood_agency()
	test_bot_policies_and_divergence()
	test_cohort_with_storylets()
	print("Storylet systems: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func test_storylet_validation() -> void:
	var bad: Dictionary = pack.duplicate(true)
	bad.storylets[0].erase("title")
	check(not Content.validate(bad).is_empty(), "Missing storylet title rejected")

	bad = pack.duplicate(true)
	bad.storylets.append(bad.storylets[0].duplicate(true))
	check(not Content.validate(bad).is_empty(), "Duplicate storylet ID rejected")

	bad = pack.duplicate(true)
	bad.storylets[0].choices.append(bad.storylets[0].choices[0].duplicate(true))
	check(not Content.validate(bad).is_empty(), "Duplicate storylet choice ID rejected")

	bad = pack.duplicate(true)
	bad.storylets[0].utility.base = -5
	check(not Content.validate(bad).is_empty(), "Negative storylet utility base rejected")


func test_eligibility_and_cooldown() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.initial_state(42) # age 0
	var labor_storylet: Dictionary = {}
	for st: Dictionary in pack.storylets:
		if st.id == "childhood_labor_demand":
			labor_storylet = st
			break

	check(not Storylets.is_eligible(labor_storylet, state),
		"Infant is not eligible for child labor demand")

	# Yaşı 10'a ilerlet ve hanehalkını yoksul tut
	var child_state: Dictionary = runner.simulate_years(42, 10).state
	child_state.household.savings = 500
	check(Storylets.is_eligible(labor_storylet, child_state),
		"10-year-old poor dependent child is eligible for labor demand")

	# Cooldown denetimi: Storylet'i çalıştır ve last_seen kaydet
	var cooldown_state: Dictionary = child_state.duplicate(true)
	cooldown_state.storylets.last_seen[labor_storylet.id] = cooldown_state.world.year
	check(not Storylets.is_eligible(labor_storylet, cooldown_state),
		"Storylet on cooldown is not eligible in the same year")

	# Cooldown süresi dolmadan hemen sonraki yıl da uygun olmamalı (cooldown_years: 4)
	cooldown_state.world.year += 2
	check(not Storylets.is_eligible(labor_storylet, cooldown_state),
		"Storylet is still not eligible before cooldown_years elapses")

	cooldown_state.world.year += 3 # 5 yıl geçti
	check(Storylets.is_eligible(labor_storylet, cooldown_state),
		"Storylet becomes eligible again after cooldown elapses")


func test_choices_and_effects() -> void:
	var runner = Runner.new(pack)

	# 1. Gece okuması (night_reading)
	var reading_storylet: Dictionary = {}
	for st: Dictionary in pack.storylets:
		if st.id == "night_reading":
			reading_storylet = st
			break

	var youth_state: Dictionary = runner.simulate_years(42, 12).state # 12 yaş
	var initial_lit: int = int(youth_state.actors.player.literacy)
	var initial_hlth: int = int(youth_state.actors.player.health)

	var read_step: Dictionary = runner.step(youth_state, [], {"night_reading": "study_diligently"})
	check(read_step.ok, "Night reading choice step succeeds")
	check(read_step.state.actors.player.literacy == initial_lit + 25,
		"Diligent study increases literacy by 15 over baseline schooling")
	check(read_step.state.actors.player.health == initial_hlth - 5,
		"Diligent study exacts health penalty from eye strain/sleep loss")

	# 2. Aile yadigârını rehin verme (pawn_family_heirloom)
	var pawn_storylet: Dictionary = {}
	for st: Dictionary in pack.storylets:
		if st.id == "pawn_family_heirloom":
			pawn_storylet = st
			break

	var adult_state: Dictionary = runner.simulate_years(42, 20).state
	adult_state.household.savings = 50
	adult_state.actors.player.willpower = 60
	var job_loss: Array = [{"type": "job_lost", "id": "job_loss_pawn", "actor_id": "player", "worked_permille": 0}]
	var pawn_step: Dictionary = runner.step(adult_state, job_loss, {"pawn_family_heirloom": "pawn_heirloom"})
	check(pawn_step.ok, "Pawn heirloom step succeeds")
	check(pawn_step.state.household.savings >= 750, "Pawning heirloom grants ready cash")
	check(pawn_step.state.actors.player.willpower == 50, "Pawning heirloom lowers willpower")
	check(pawn_step.state.storylets.flags.get("heirloom_pawned", false),
		"Heirloom pawned flag is recorded")
	check(not Storylets.is_eligible(pawn_storylet, pawn_step.state),
		"Cannot pawn the heirloom a second time due to flag constraint")

	# 3. Fazla mesai (overtime_shift)
	var adult_worker_state: Dictionary = runner.simulate_years(42, 18).state
	var ovt_step: Dictionary = runner.step(adult_worker_state, [], {"overtime_shift": "accept_overtime"})
	check(ovt_step.ok, "Overtime shift step succeeds")
	check(ovt_step.state.household.savings > adult_worker_state.household.savings,
		"Overtime grants additional cash")


func test_childhood_agency() -> void:
	var runner = Runner.new(pack)
	var state: Dictionary = runner.simulate_years(42, 10).state
	state.household.savings = 500

	# Senaryo A: Koruyucu eğitim yanlısı (traits'te education_first var)
	state.actors.parent_1.traits = ["education_first"]
	state.household.guardian_id = "parent_1"

	var protest_step: Dictionary = runner.step(state, [], {"childhood_labor_demand": "protest_for_school"})
	check(protest_step.ok, "Protest step commits")
	check(protest_step.state.household.pending_effects.is_empty(),
		"Guardian who values education allows child to stay in school upon protest")

	# Senaryo B: Koruyucu pragmatik ve çocuğun iradesi düşük (willpower: 20)
	var strict_state: Dictionary = state.duplicate(true)
	strict_state.actors.parent_1.traits = ["pragmatic"]
	strict_state.actors.player.willpower = 20
	var forced_step: Dictionary = runner.step(strict_state, [], {"childhood_labor_demand": "protest_for_school"})
	check(forced_step.ok, "Forced work protest step commits")
	check(not forced_step.state.household.pending_effects.is_empty(),
		"Child with insufficient agency is overruled by pragmatic parent and scheduled for work")
	var next_year: Dictionary = runner.step(forced_step.state)
	check(next_year.ok and next_year.state.actors.player.occupation_id == "child_factory_worker",
		"Overruled child enters factory labor the following year")


func test_bot_policies_and_divergence() -> void:
	var runner = Runner.new(pack)

	# 1. Determinizm: Aynı seed + aynı bot politikası = 100% eşitlik
	var first: Dictionary = runner.simulate_years(42, 30, {}, {}, "heuristic_v1")
	var second: Dictionary = runner.simulate_years(42, 30, {}, {}, "heuristic_v1")
	check(first.ok and second.ok and first.fingerprint == second.fingerprint,
		"Same seed and same bot policy produce identical state and trace")

	# 2. Farklı politikalar farklı hayat yolları ve olay seçimleri üretir
	var pragmatic_run: Dictionary = runner.simulate_years(42, 30, {}, {}, "pragmatic")
	var edu_run: Dictionary = runner.simulate_years(42, 30, {}, {}, "education_first")
	check(pragmatic_run.ok and edu_run.ok, "Both bot policy runs complete")
	check(pragmatic_run.fingerprint != edu_run.fingerprint,
		"Different bot policies produce meaningfully divergent life outcomes")


func test_cohort_with_storylets() -> void:
	var runner = Runner.new(pack)
	var total_runs: int = 100
	var completed: int = 0
	var quiet_years_counted: int = 0
	var storylets_triggered: int = 0
	var all_invariants_valid: bool = true

	for seed_value: int in range(total_runs):
		var result: Dictionary = runner.simulate_life(seed_value)
		if not result.ok:
			printerr("Seed %d failed: %s" % [seed_value, result.errors])
			all_invariants_valid = false
			continue

		if result.status == "completed":
			completed += 1

		if not runner.validate_state(result.state).is_empty():
			all_invariants_valid = false

		for ev: Dictionary in result.state.history:
			if ev.kind == "quiet_year":
				quiet_years_counted += 1
			elif ev.kind == "storylet_triggered":
				storylets_triggered += 1

		for ledger: Dictionary in result.state.ledgers:
			if not Household.validate_ledger(ledger).is_empty():
				all_invariants_valid = false

	check(all_invariants_valid, "All 100 seeds preserve invariants with storylets enabled")
	check(completed == total_runs, "100% of cohort naturally completes life")
	check(storylets_triggered > 50, "Storylets actively trigger across cohort")
	check(quiet_years_counted > 100, "Quiet years occur regularly without constant crisis")
