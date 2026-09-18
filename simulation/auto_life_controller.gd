extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Actions = preload("res://simulation/life_action_system.gd")
const BotPolicy = preload("res://simulation/bot_policy.gd")
const Purchases = preload("res://simulation/purchase_system.gd")

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


static func choose_purchase(state: Dictionary, policy: String = "balanced") -> String:
	var options: Array[Dictionary] = Purchases.available_items(state)
	if options.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var n: Dictionary = p.get("needs", {})
	var cash := int(state.personal_economy.cash)
	var best_id := ""
	var best_score := 0
	for item: Dictionary in options:
		var effects: Dictionary = item.get("effects", {})
		var score := 0
		score += int(effects.get("health", 0)) * (3 if int(p.health) < 60 else 1)
		score += int(effects.get("literacy", 0)) * (3 if "education_first" in p.get("traits", []) else 2)
		score += int(effects.get("happiness", 0)) * (2 if int(n.get("happiness", 55)) < 50 else 1)
		score += -int(effects.get("stress", 0)) * (2 if int(n.get("stress", 20)) > 55 else 1)
		score += int(effects.get("social", 0)) * (2 if int(n.get("social", 50)) < 45 else 1)
		score += int(effects.get("energy", 0))
		score += int(effects.get("willpower", 0))
		var cost := int(item.cost)
		score -= int(cost * 18.0 / maxi(cash, 1))
		if str(item.category) == "finance" and policy == "pragmatic":
			score += 12
		if str(item.category) in ["education", "media"] and policy == "education_first":
			score += 15
		if str(item.category) == "vice" and "education_first" in p.get("traits", []):
			score -= 12
		var noise := Rng.integer(str(state.meta.master_seed).to_int(), "purchase_ai",
			int(state.world.year), str(p.id), str(item.id), -3, 3)
		score += noise
		if score > best_score:
			best_score = score
			best_id = str(item.id)
	return best_id if best_score >= 8 else ""
