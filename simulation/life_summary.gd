extends RefCounted

static func build(state: Dictionary) -> Dictionary:
	var p: Dictionary = state.actors[state.meta.player_id]
	var actions: Dictionary = {}
	var important: Array = []
	for event: Dictionary in state.history:
		if event.get("kind") == "life_action":
			var id: String = str(event.details.get("action_id", "unknown"))
			actions[id] = int(actions.get(id, 0)) + 1
		elif event.get("kind") in ["occupation_started", "condition_acquired", "marriage", "child_born", "actor_died"]:
			important.append(event)
	return {
		"name": p.name,
		"birth_year": int(p.birth_year),
		"death_year": int(p.death_year),
		"age_at_death": int(p.age),
		"death_cause": str(p.death_cause),
		"literacy": int(p.literacy),
		"willpower": int(p.willpower),
		"final_savings": int(state.household.savings),
		"final_debt": int(state.household.debt),
		"personal_cash": int(state.get("personal_economy", {}).get("cash", 0)),
		"personal_income": int(state.get("personal_economy", {}).get("lifetime_income", 0)),
		"personal_spending": int(state.get("personal_economy", {}).get("lifetime_spending", 0)),
		"marital_status": str(state.family.marital_status),
		"children": int(state.family.children_count),
		"actions": actions,
		"important_events": important
	}
