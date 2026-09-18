extends RefCounted

const Needs = preload("res://simulation/needs_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")

const ACTIONS := {
	"play": {"min_age": 4, "max_age": 15, "health": 2, "literacy": 0, "willpower": 0, "happiness": 12, "stress": -8, "social": 5, "energy": -6},
	"study": {"min_age": 6, "max_age": 30, "health": -2, "literacy": 6, "willpower": 2, "happiness": -2, "stress": 5, "social": -2, "energy": -8},
	"rest": {"min_age": 0, "max_age": 200, "health": 5, "literacy": 0, "willpower": 0, "happiness": 3, "stress": -10, "social": -2, "energy": 15},
	"family_time": {"min_age": 3, "max_age": 200, "health": 0, "literacy": 0, "willpower": 2, "happiness": 8, "stress": -5, "social": 10, "energy": -3},
	"socialize": {"min_age": 10, "max_age": 200, "health": 0, "literacy": 0, "willpower": 1, "happiness": 10, "stress": -6, "social": 15, "energy": -6},
	"self_education": {"min_age": 14, "max_age": 200, "health": -2, "literacy": 4, "willpower": 3, "happiness": 1, "stress": 3, "social": -3, "energy": -7},
	"work_hard": {"min_age": 16, "max_age": 70, "health": -5, "literacy": 0, "willpower": 4, "happiness": -3, "stress": 10, "social": -5, "energy": -12}
}

static func available_actions(state: Dictionary) -> Array[String]:
	var player: Dictionary = state.actors[state.meta.player_id]
	var result: Array[String] = []
	if not player.alive:
		return result
	for id: String in ACTIONS:
		var a: Dictionary = ACTIONS[id]
		if int(player.age) >= int(a.min_age) and int(player.age) <= int(a.max_age):
			if id == "work_hard" and player.occupation_id == "dependent":
				continue
			result.append(id)
	result.sort()
	return result

static func apply(state: Dictionary, action_id: String) -> Dictionary:
	if action_id not in available_actions(state):
		return {"ok": false, "error": "Action is not currently available: " + action_id}
	var player: Dictionary = state.actors[state.meta.player_id]
	Needs.normalize_actor(player)
	var a: Dictionary = ACTIONS[action_id]
	player.health = clampi(int(player.health) + int(a.health), 0, 100)
	player.literacy = clampi(int(player.literacy) + int(a.literacy), 0, 100)
	player.willpower = clampi(int(player.willpower) + int(a.willpower), 0, 100)
	for key: String in ["happiness", "stress", "social", "energy"]:
		player.needs[key] = clampi(int(player.needs[key]) + int(a[key]), 0, 100)
	if action_id == "family_time":
		Relationships.spend_time_with_family(state)
	elif action_id == "socialize":
		Relationships.socialize(state)
	state.history.append({"id": "%d:life_action:%s" % [int(state.world.year), action_id],
		"year": int(state.world.year), "kind": "life_action", "cause_id": "",
		"details": {"actor_id": player.id, "action_id": action_id}})
	return {"ok": true, "action_id": action_id}
