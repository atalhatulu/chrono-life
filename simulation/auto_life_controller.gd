extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Actions = preload("res://simulation/life_action_system.gd")
const BotPolicy = preload("res://simulation/bot_policy.gd")
const Purchases = preload("res://simulation/purchase_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const Treatments = preload("res://simulation/health_treatment_system.gd")
const FamilyDynamics = preload("res://simulation/family_dynamics_system.gd")
const Hobbies = preload("res://simulation/hobby_system.gd")
const Assets = preload("res://simulation/asset_system.gd")
const Migration = preload("res://simulation/migration_system.gd")

static func choose_action(state: Dictionary, policy: String = "balanced") -> String:
	var ids: Array[String] = Actions.available_actions(state)
	if ids.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var defs: Dictionary = Actions.actions_by_id(state)
	var best: String = ids[0]
	var best_score: int = -999999
	for id: String in ids:
		var score: int = _utility(defs.get(id, {}), p, state, policy)
		var noise: int = Rng.integer(str(state.meta.master_seed).to_int(), "autolife",
			int(state.world.year), str(p.id), id, -5, 5)
		score += noise
		if score > best_score:
			best_score = score
			best = id
	return best

static func _utility(action: Dictionary, p: Dictionary, state: Dictionary, policy: String) -> int:
	var n: Dictionary = p.get("needs", {})
	var tags: Array = action.get("ai_tags", [])
	var score: int = 10
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
	var axes: Dictionary = p.get("personality", {}).get("axes", {})
	if "education" in tags:
		score += int(axes.get("curiosity", 50)) / 5
	if "social" in tags or "family" in tags:
		score += int(axes.get("sociability", 50)) / 6 + int(axes.get("empathy", 50)) / 8
	if "effort" in tags or "work" in tags:
		score += int(axes.get("discipline", 50)) / 6
	if "risk" in tags:
		score += (int(axes.get("risk_tolerance", 50)) - 50) / 3
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
	var cash: int = int(state.personal_economy.cash)
	var best_id: String = ""
	var best_score: int = 0
	for item: Dictionary in options:
		var effects: Dictionary = item.get("effects", {})
		var score: int = 0
		score += int(effects.get("health", 0)) * (3 if int(p.health) < 60 else 1)
		score += int(effects.get("literacy", 0)) * (3 if "education_first" in p.get("traits", []) else 2)
		score += int(effects.get("happiness", 0)) * (2 if int(n.get("happiness", 55)) < 50 else 1)
		score += -int(effects.get("stress", 0)) * (2 if int(n.get("stress", 20)) > 55 else 1)
		score += int(effects.get("social", 0)) * (2 if int(n.get("social", 50)) < 45 else 1)
		score += int(effects.get("energy", 0))
		score += int(effects.get("willpower", 0))
		var cost: int = int(item.cost)
		score -= int(cost * 18.0 / maxi(cash, 1))
		if str(item.category) == "finance" and policy == "pragmatic":
			score += 12
		if str(item.category) in ["education", "media"] and policy == "education_first":
			score += 15
		if str(item.category) == "vice" and "education_first" in p.get("traits", []):
			score -= 12
		var noise: int = Rng.integer(str(state.meta.master_seed).to_int(), "purchase_ai",
			int(state.world.year), str(p.id), str(item.id), -3, 3)
		score += noise
		if score > best_score:
			best_score = score
			best_id = str(item.id)
	return best_id if best_score >= 8 else ""


static func choose_relationship_action(state: Dictionary, policy: String = "balanced") -> Dictionary:
	Relationships.normalize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	var social_need: int = int(p.get("needs", {}).get("social", 50))
	var candidates: Array[String] = []
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if rel.alive and rel.role not in ["parent", "child", "family", "spouse", "ex_partner", "estranged"]:
			candidates.append(id)
	if candidates.is_empty():
		if social_need < 65 or int(p.age) >= 10:
			return {"action": "meet", "person_id": ""}
		return {}
	candidates.sort()
	var best_id: String = ""
	var best_score: int = -999999
	for id: String in candidates:
		var rel: Dictionary = state.relationships.people[id]
		var score: int = int(rel.closeness) + int(rel.trust) + int(rel.compatibility) - int(rel.conflict)
		if rel.stage in ["romantic_interest", "dating"]:
			score += int(rel.attraction)
		if score > best_score:
			best_score = score
			best_id = id
	if best_id == "":
		return {}
	var rel: Dictionary = state.relationships.people[best_id]
	if int(rel.conflict) >= 45:
		return {"action": "apologize", "person_id": best_id}
	if rel.stage == "romantic_interest" and int(p.age) >= 16:
		return {"action": "flirt", "person_id": best_id}
	if social_need < 45:
		return {"action": "spend_time", "person_id": best_id}
	if policy == "pragmatic" and int(rel.trust) < 45:
		return {"action": "talk", "person_id": best_id}
	var roll: int = Rng.integer(str(state.meta.master_seed).to_int(), "social_ai",
		int(state.world.year), str(p.id), best_id, 0, 99)
	if roll < 45:
		return {"action": "talk", "person_id": best_id}
	elif roll < 85:
		return {"action": "spend_time", "person_id": best_id}
	return {}


static func choose_treatment(state: Dictionary, policy: String = "balanced") -> String:
	var options: Array[Dictionary] = Treatments.available_treatments(state)
	if options.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var severity_total: int = 0
	for id: String in p.conditions:
		severity_total += int(p.conditions[id].get("severity", 50))
	if severity_total < 35 and int(p.health) >= 70:
		return ""
	var best_id: String = ""
	var best_score: int = -999999
	for t: Dictionary in options:
		var score: int = int(t.get("success_bp", 0)) / 100
		score += int(t.get("severity_reduction", 0)) * 2
		score += int(t.get("health_restore", 0))
		score -= int(t.get("cost", 0))
		if policy == "pragmatic":
			score -= int(t.get("cost", 0)) / 2
		var noise: int = Rng.integer(str(state.meta.master_seed).to_int(), "treatment_ai",
			int(state.world.year), str(p.id), str(t.id), -3, 3)
		score += noise
		if score > best_score:
			best_score = score
			best_id = str(t.id)
	return best_id


static func choose_parenting_action(state: Dictionary, policy: String = "balanced") -> Dictionary:
	if not state.has("family"):
		return {}
	var children: Array[String] = []
	for child_id: String in state.family.get("children_ids", []):
		if state.actors.has(child_id) and state.actors[child_id].alive:
			children.append(child_id)
	if children.is_empty():
		return {}
	children.sort()
	var best_id: String = ""
	var best_score: int = -999999
	for child_id: String in children:
		var child: Dictionary = state.actors[child_id]
		var parenting: Dictionary = state.family.get("parenting", {}).get(child_id, {})
		var score: int = 0
		score += 100 - int(parenting.get("support", 55))
		score += int(child.get("needs", {}).get("stress", 20))
		if str(child.household_id) == str(state.household.id):
			score += 10
		if score > best_score:
			best_score = score
			best_id = child_id
	if best_id == "":
		return {}
	var p: Dictionary = state.family.get("parenting", {}).get(best_id, {})
	var child: Dictionary = state.actors[best_id]
	if int(p.get("conflict", 10)) >= 55:
		return {"child_id": best_id, "action": "spend_time"}
	if int(child.get("education", {}).get("progress", 0)) > 0 and int(p.get("support", 55)) < 70:
		return {"child_id": best_id, "action": "education_support"}
	if int(p.get("involvement", 55)) < 60:
		return {"child_id": best_id, "action": "spend_time"}
	if policy == "pragmatic" and int(child.willpower) < 45:
		return {"child_id": best_id, "action": "discipline"}
	return {"child_id": best_id, "action": "support"}


static func choose_elder_care_action(state: Dictionary, policy: String = "balanced") -> Dictionary:
	if not state.has("family"):
		return {}
	var player_id: String = str(state.meta.player_id)
	var parents: Array = state.family.get("kinship", {}).get(player_id, {}).get("parents", [])
	var target: String = ""
	var best_need: int = -1
	for parent_id: String in parents:
		if not state.actors.has(parent_id):
			continue
		var parent: Dictionary = state.actors[parent_id]
		if not parent.alive or (int(parent.age) < 60 and int(parent.health) >= 55):
			continue
		var care: Dictionary = state.family.get("elder_care", {}).get(parent_id, {})
		var need: int = (100 - int(parent.health)) + maxi(0, 60 - int(care.get("care", 0)))
		if need > best_need:
			best_need = need
			target = parent_id
	if target == "":
		return {}
	var care: Dictionary = state.family.get("elder_care", {}).get(target, {})
	if int(care.get("care", 0)) < 30:
		return {"parent_id": target, "action": "care"}
	if policy == "pragmatic":
		return {"parent_id": target, "action": "visit"}
	return {"parent_id": target, "action": "care"}


static func choose_hobby(state: Dictionary, policy: String = "balanced") -> String:
	var options: Array[Dictionary] = Hobbies.available_hobbies(state)
	if options.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var axes: Dictionary = p.get("personality", {}).get("axes", {})
	var needs: Dictionary = p.get("needs", {})
	var best_id: String = ""
	var best_score: int = -999999
	for hobby: Dictionary in options:
		var score: int = 10
		var tags: Array = hobby.get("tags", [])
		if "learning" in tags:
			score += int(axes.get("curiosity", 50)) / 2
		if "social" in tags:
			score += int(axes.get("sociability", 50)) / 2 + maxi(0, 60 - int(needs.get("social", 50)))
		if "physical" in tags:
			score += int(axes.get("resilience", 50)) / 3 + maxi(0, 65 - int(p.health))
		if "creative" in tags:
			score += int(axes.get("curiosity", 50)) / 3
		if "quiet" in tags:
			score += int(needs.get("stress", 20)) / 2
		var existing: Dictionary = p.get("hobbies", {}).get("active", {}).get(hobby.id, {})
		score += int(existing.get("mastery", 0)) / 4
		if policy == "education_first" and "learning" in tags:
			score += 15
		var noise: int = Rng.integer(str(state.meta.master_seed).to_int(), "hobby_ai",
			int(state.world.year), str(p.id), str(hobby.id), -4, 4)
		score += noise
		if score > best_score:
			best_score = score
			best_id = str(hobby.id)
	return best_id


static func choose_asset(state: Dictionary, policy: String = "balanced") -> String:
	var options: Array[Dictionary] = Assets.available_assets(state)
	if options.is_empty():
		return ""
	var cash: int = int(state.personal_economy.cash)
	var best_id: String = ""
	var best_score: int = -999999
	for asset: Dictionary in options:
		var cost = int(asset.get("acquire_cost", 0))
		var value: int = int(asset.get("base_value", cost))
		var score: int = int(asset.get("status_value", 0)) * 3 + maxi(0, value - cost) / 50
		if str(asset.get("category", "")) == "productive":
			score += 20
		if policy == "pragmatic" and str(asset.get("category", "")) in ["productive", "financial"]:
			score += 15
		score -= int(cost * 25.0 / maxi(cash, 1))
		if score > best_score:
			best_score = score
			best_id = str(asset.id)
	return best_id if best_score >= 8 else ""


static func choose_migration(state: Dictionary, policy: String = "balanced") -> String:
	var options: Array[Dictionary] = Migration.available_destinations(state)
	if options.is_empty():
		return ""
	var p: Dictionary = state.actors[state.meta.player_id]
	var best_id: String = ""
	var best_score: int = -999999
	for destination: Dictionary in options:
		var employment_modifier: int = int(destination.get("world_modifiers", {}).get("employment_pressure", 0))
		var score: int = employment_modifier / 5
		score -= int(destination.get("move_cost", 0)) / 100
		if int(state.household.debt) > 1000:
			score += employment_modifier / 3
		if "bold" in p.get("traits", []):
			score += 10
		if "cautious" in p.get("traits", []):
			score -= 15
		if policy == "pragmatic":
			score += employment_modifier / 4
		if score > best_score:
			best_score = score
			best_id = str(destination.id)
	return best_id if best_score >= 10 else ""
