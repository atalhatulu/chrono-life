extends RefCounted

static func build(state: Dictionary) -> Dictionary:
	var p: Dictionary = state.actors[state.meta.player_id]
	var relationship_summary := {"friends": 0, "close_friends": 0, "romantic": 0, "ex_partners": 0, "estranged": 0, "social_events": 0}
	for id: String in state.get("relationships", {}).get("people", {}):
		var rel: Dictionary = state.relationships.people[id]
		match str(rel.get("stage", "")):
			"friend": relationship_summary.friends += 1
			"close_friend": relationship_summary.close_friends += 1
			"romantic_interest", "dating", "spouse": relationship_summary.romantic += 1
			"ex_partner": relationship_summary.ex_partners += 1
			"estranged": relationship_summary.estranged += 1
	for event: Dictionary in state.get("relationships", {}).get("history", []):
		if event.get("kind") == "social_event":
			relationship_summary.social_events += 1
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
		"grandchildren": state.family.get("grandchildren_ids", []).size(),
		"household_count": state.get("households", {}).size(),
		"family_history": state.family.duplicate(true),
		"parenting": state.family.get("parenting", {}).duplicate(true),
		"sibling_bonds": state.family.get("sibling_bonds", {}).duplicate(true),
		"descendant_lives": state.family.get("descendant_lives", {}).duplicate(true),
		"household_members": state.household.member_ids.duplicate(),
		"career": p.get("career", {}).duplicate(true),
		"relationships": state.get("relationships", {}).duplicate(true),
		"relationship_summary": relationship_summary,
		"actions": actions,
		"important_events": important
	}
