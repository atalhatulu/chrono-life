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
	var defs: Dictionary = Actions.actions_by_id(state)
	var best := ids[0]
	var best_score := -999999
	for id: String in ids:
		var score := _utility(defs.get(id, {}), p, state, policy)
		var noise := Rng.integer(str(state.meta.master_seed).to_int(), "autolife",
			int(state.world.year), str(p.id), id, -5, 5)
		score += noise
		if score > best_score:
			best_score = score
			best = id
	return best

static func _utility(action: Dictionary, p: Dictionary, state: Dictionary, policy: String) -> int:
	var n: Dictionary = p.get("needs", {})
	var tags: Array = action.get("ai_tags", [])
	var score := 10
	if "recovery" in tags:
		score += (100 - int(n.get("energy", 70))) + int(n.get("stress", 20))
	if "health" in tags:
		score += (100 - int(p.health)) / 2
	if "leisure" in tags:
		score += (100 - int(n.get("happiness", 55))) / 2 + int(n.get("stress", 20)) / 2
	if "social" in tags:
		score += (100 - int(n.get("social", 50)))
	if "family" in tags:
		score += (100 - int(n.get("social", 50))) / 2 + 15
	if "education" in tags:
		score += (100 - int(p.literacy)) + int(p.willpower) / 3
	if "work" in tags or "income" in tags:
		score += 25 + (20 if int(state.household.savings) < 1000 else 0)
	if "effort" in tags:
		score -= maxi(0, 45 - int(n.get("energy", 70))) / 2
	if "risk" in tags and int(p.health) < 45:
		score -= 25
	if "spending" in tags:
		score -= int(action.get("cash_cost", 0)) / 2
	if "childhood" in tags and int(p.age) < 12:
		score += 15
	if "education_first" in p.get("traits", []) and "education" in tags:
		score += 30
	if "pragmatic" in p.get("traits", []) and ("work" in tags or "recovery" in tags):
		score += 15
	if policy == "education_first" and "education" in tags:
		score += 35
	elif policy == "pragmatic" and ("work" in tags or "recovery" in tags):
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
