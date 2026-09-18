extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Actions = preload("res://simulation/life_action_system.gd")

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
	check(Actions.available_actions(state).has("rest"), "Rest is available from birth")
	check(not Actions.available_actions(state).has("work_hard"), "Infant cannot work hard")
	var first: Dictionary = runner.simulate_auto_life(42, "balanced")
	var again: Dictionary = runner.simulate_auto_life(42, "balanced")
	check(first.ok and again.ok, "AutoLife completes without simulation errors")
	check(first.fingerprint == again.fingerprint, "AutoLife is deterministic for same seed and policy")
	check(first.life_result.has("actions"), "Death summary contains action history")
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
