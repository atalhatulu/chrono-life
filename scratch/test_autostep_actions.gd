extends SceneTree

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")

func _initialize() -> void:
	var loaded = Content.load_pack()
	var runner = Runner.new(loaded.pack)
	var state = runner.initial_state(42)
	for i in range(15):
		var yr_before = state.world.year
		var act_used_before = state.meta.get("action_used_year", -1)
		var res = runner.auto_step(state, "balanced")
		if not res.ok:
			print("auto_step failed: ", res.errors)
			break
		state = res.state
		print("Year %d (age %d): chosen action_id='%s', action_used_year=%d" % [
			yr_before,
			state.actors.player.age - 1,
			res.get("action_id", ""),
			state.meta.get("action_used_year", -1)
		])
	quit()
