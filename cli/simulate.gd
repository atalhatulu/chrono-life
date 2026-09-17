extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")


func _initialize() -> void:
	var options: Dictionary = _parse(OS.get_cmdline_user_args())
	if options.has("error"):
		fail(options.error)
		return
	if options.has("help"):
		print("ChronoLife Phase 0C — headless life simulation with storylets & decisions")
		print("--life | --years N; --seed N --count N --policy heuristic_v1|pragmatic|education_first")
		print("--shock-year YYYY --shock-type job_lost|actor_died --actor ID --worked-permille N --output PATH")
		print("Defaults: seed=42 years=12 count=1 policy=heuristic_v1 actor=parent_1 worked-permille=500")
		quit(0)
		return
	var loaded: Dictionary = Content.load_pack()
	if not loaded.ok:
		fail(str(loaded.errors))
		return
	var runner = Runner.new(loaded.pack)
	var seed_value: int = int(options.get("seed", 42))
	var years: int = int(loaded.pack.limits.max_years) if options.has("life") else int(options.get("years", 12))
	if options.has("life") and options.has("years"):
		fail("--life and --years are mutually exclusive")
		return
	var count: int = int(options.get("count", 1))
	if seed_value < 0 or seed_value > 2147483647 or count < 1 or count > 1000 or \
			seed_value + count - 1 > 2147483647:
		fail("seed must be in [0, 2147483647], count in [1, 1000], including the final seed")
		return
	if years < 1 or years > int(loaded.pack.limits.max_years):
		fail("years must be in [1, %d]" % int(loaded.pack.limits.max_years))
		return
	if (options.has("actor") or options.has("worked-permille") or options.has("shock-type")) and not options.has("shock-year"):
		fail("--actor, --worked-permille and --shock-type require --shock-year")
		return
	var schedule: Dictionary = {}
	if options.has("shock-year"):
		var year: int = int(options["shock-year"])
		if year <= int(loaded.pack.start_year) or year > int(loaded.pack.start_year) + years:
			fail("shock-year must fall within the simulated years")
			return
		var shock_type: String = str(options.get("shock-type", "job_lost"))
		if shock_type not in ["job_lost", "actor_died"]:
			fail("Unknown shock-type")
			return
		var actor_id: String = str(options.get("actor", "parent_1"))
		if not runner.initial_state(seed_value).actors.has(actor_id):
			fail("Unknown scenario actor: " + actor_id)
			return
		var fraction: int = int(options.get("worked-permille", 500))
		if fraction < 0 or fraction > 1000:
			fail("worked-permille must be in [0, 1000]")
			return
		schedule[year] = [{"id": "scenario_shock", "type": shock_type,
			"actor_id": options.get("actor", "parent_1"),
			"worked_permille": fraction, "skip_if_unavailable": true}]
	var summaries: Array[Dictionary] = []
	var single_result: Dictionary = {}
	var policy_name: String = str(options.get("policy", "heuristic_v1"))
	var start: int = Time.get_ticks_msec()
	for index: int in range(count):
		var result: Dictionary = runner.simulate_years(seed_value + index, years, schedule, {}, policy_name)
		if not result.ok:
			fail(str(result.errors))
			return
		var state: Dictionary = result.state
		var deficit_years: int = 0
		var food_insecure_years: int = 0
		for ledger: Dictionary in state.ledgers:
			deficit_years += int(ledger.budget_deficit > 0)
			food_insecure_years += int(ledger.food_security < 1000)
		var summary: Dictionary = {"seed": seed_value + index, "year": state.world.year,
			"status": result.status, "savings": state.household.savings, "debt": state.household.debt,
			"age": result.life_result.age, "death_cause": result.life_result.cause_of_death,
			"education": result.life_result.education, "literacy": result.life_result.literacy,
			"deficit_years": deficit_years, "food_insecure_years": food_insecure_years,
			"fingerprint": result.fingerprint}
		summaries.append(summary)
		if count == 1:
			single_result = result
			for ledger: Dictionary in state.ledgers:
				print("YEAR %d | earned %d | needs %d | savings %d | debt %d | unmet %d | food %d/1000" %
					[ledger.year, ledger.earned_income, ledger.planned_expenses, ledger.closing_savings,
						ledger.closing_debt, ledger.unmet_needs, ledger.food_security])
			for event: Dictionary in state.history:
				if event.kind in ["actor_died", "school_started", "school_interrupted", "school_completed",
						"occupation_started", "condition_acquired", "household_response", "life_ended",
						"storylet_triggered", "storylet_choice_made", "quiet_year"]:
					print("EVENT %d | %s | %s" % [event.year, event.kind, JSON.stringify(event.details)])
	var elapsed: int = Time.get_ticks_msec() - start
	var report: Dictionary = {"phase": "0C", "simulation_version": Runner.VERSION,
		"content_version": loaded.pack.version, "historically_calibrated": false,
		"policy": policy_name, "years_per_run": years, "count": count, "elapsed_ms": elapsed, "summaries": summaries}
	if count == 1:
		report.result = single_result
	if options.has("output"):
		var file: FileAccess = FileAccess.open(str(options.output), FileAccess.WRITE)
		if file == null:
			fail("Cannot write output (parent directory must exist): " + str(options.output))
			return
		file.store_string(JSON.stringify(report, "\t", true) + "\n")
		file.flush()
		if file.get_error() != OK:
			fail("Failed while writing output")
			return
	print("Finished %d runs with a %d-year safety limit in %d ms. Completed lives end at player death." %
		[count, years, elapsed])
	for summary: Dictionary in summaries.slice(0, mini(3, count)):
		print(JSON.stringify(summary, "", true))
	quit(0)


func _parse(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	var numeric: Array[String] = ["seed", "years", "count", "shock-year", "worked-permille"]
	var index: int = 0
	while index < args.size():
		if args[index] == "--help" and args.size() == 1:
			return {"help": true}
		if args[index] == "--life":
			if options.has("life"):
				return {"error": "Duplicate --life"}
			options.life = true
			index += 1
			continue
		var key: String = args[index].trim_prefix("--")
		if not args[index].begins_with("--") or key not in numeric + ["actor", "output", "shock-type", "policy"]:
			return {"error": "Unknown argument: " + args[index]}
		if options.has(key) or index + 1 >= args.size():
			return {"error": "Duplicate argument or missing value: " + args[index]}
		var value: String = args[index + 1]
		if value.is_empty() or value.begins_with("--"):
			return {"error": "Missing value for " + args[index]}
		if key in numeric:
			if not value.is_valid_int() or value.length() > 10:
				return {"error": "Expected an integer of at most 10 characters: " + key}
			options[key] = value.to_int()
		else:
			options[key] = value
		index += 2
	return options


func fail(message: String) -> void:
	printerr("ERROR: " + message)
	quit(1)
