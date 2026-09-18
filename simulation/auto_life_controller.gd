extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Actions = preload("res://simulation/life_action_system.gd")
const BotPolicy = preload("res://simulation/bot_policy.gd")

static func choose_action(state: Dictionary, policy: String = "balanced") -> String:
	var ids: Array[String] = Actions.available_actions(state)
	if ids.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var best := ids[0]
	var best_score := -999999
	for id: String in ids:
		var score := _utility(id, p, state, policy)
		var noise := Rng.integer(str(state.meta.master_seed).to_int(), "autolife",
			int(state.world.year), str(p.id), id, -5, 5)
		score += noise
		if score > best_score:
			best_score = score
			best = id
	return best

static func _utility(id: String, p: Dictionary, state: Dictionary, policy: String) -> int:
	var n: Dictionary = p.get("needs", {})
	var score := 0
	match id:
		"rest": score = (100 - int(n.get("energy", 70))) + int(n.get("stress", 20))
		"play": score = (100 - int(n.get("happiness", 55))) + (15 if int(p.age) < 12 else 0)
		"family_time": score = (100 - int(n.get("social", 50))) + 15
		"socialize": score = (100 - int(n.get("social", 50))) + (100 - int(n.get("happiness", 55))) / 2
		"study": score = (100 - int(p.literacy)) + int(p.willpower) / 2
		"self_education": score = (100 - int(p.literacy)) / 2 + int(p.willpower) / 2
		"work_hard": score = 30 + (20 if int(state.household.savings) < 1000 else 0)
		"cheap_leisure": score = (100 - int(n.get("happiness", 55))) + int(n.get("stress", 20))
		"buy_book": score = (100 - int(p.literacy)) + (15 if "education_first" in p.get("traits", []) else 0)
	if "education_first" in p.get("traits", []) and id in ["study", "self_education"]:
		score += 30
	if "pragmatic" in p.get("traits", []) and id in ["rest", "work_hard"]:
		score += 15
	if policy == "education_first" and id in ["study", "self_education"]:
		score += 35
	elif policy == "pragmatic" and id in ["work_hard", "rest"]:
		score += 25
	return score

static func choose_storylet(storylet: Dictionary, state: Dictionary, ledger: Dictionary,
		policy: String = "heuristic_v1") -> String:
	return BotPolicy.decide(storylet, state, ledger, str(state.meta.master_seed).to_int(),
		int(state.world.year), policy)
