extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Family = preload("res://simulation/family_system.gd")
const Assets = preload("res://simulation/asset_system.gd")
const Housing = preload("res://simulation/housing_system.gd")


static func is_eligible(storylet: Dictionary, state: Dictionary) -> bool:
	var reqs: Dictionary = storylet.requirements
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]

	if reqs.get("player_alive", true) and not player.alive:
		return false

	var age: int = int(player.age)
	if reqs.has("min_age") and age < int(reqs.min_age):
		return false
	if reqs.has("max_age") and age > int(reqs.max_age):
		return false

	if reqs.has("occupation_id") and player.occupation_id != reqs.occupation_id:
		return false
	if reqs.has("not_occupation") and player.occupation_id == reqs.not_occupation:
		return false
	if reqs.has("marital_status_in") and str(state.family.get("marital_status", "unmarried")) not in reqs.marital_status_in:
		return false

	if reqs.has("education_states") and player.education_state not in reqs.education_states:
		return false

	if reqs.has("min_health") and int(player.health) < int(reqs.min_health):
		return false

	if reqs.has("max_literacy") and int(player.literacy) > int(reqs.max_literacy):
		return false

	if reqs.has("max_savings") and int(state.household.savings) > int(reqs.max_savings):
		return false
	if reqs.has("min_savings") and int(state.household.savings) < int(reqs.min_savings):
		return false

	if reqs.has("min_debt") and int(state.household.get("debt", 0)) < int(reqs.min_debt):
		return false

	if reqs.has("max_food_security") and int(state.household.get("food_security", 1000)) > int(reqs.max_food_security):
		return false

	if reqs.has("min_overcrowding"):
		var oc: int = Housing.overcrowding(state)
		if oc < int(reqs.min_overcrowding):
			return false

	if reqs.has("has_living_children"):
		var child_count: int = 0
		for cid: String in state.get("family", {}).get("children_ids", []):
			if state.actors.has(cid) and state.actors[cid].alive:
				child_count += 1
		if child_count == 0:
			return false

	if reqs.has("has_living_sibling"):
		var sib_count: int = 0
		var parents: Array = [player.get("parent_1_id", ""), player.get("parent_2_id", "")]
		for aid: String in state.actors:
			if aid == player_id or not state.actors[aid].alive:
				continue
			var a: Dictionary = state.actors[aid]
			if (a.get("parent_1_id", "") != "" and a.get("parent_1_id", "") in parents) or (a.get("parent_2_id", "") != "" and a.get("parent_2_id", "") in parents):
				sib_count += 1
		if sib_count == 0:
			return false

	var flags: Dictionary = state.get("storylets", {}).get("flags", {})
	if reqs.has("not_flag") and flags.get(reqs.not_flag, false):
		return false
	if reqs.has("has_flag") and not flags.get(reqs.has_flag, false):
		return false

	if reqs.has("has_any_condition"):
		var has_one: bool = false
		for cond_id: String in reqs.has_any_condition:
			if player.conditions.has(cond_id):
				has_one = true
				break
		if not has_one:
			return false

	# Bekleme süresi (cooldown) denetimi
	if reqs.has("cooldown_years"):
		var last_seen: Dictionary = state.get("storylets", {}).get("last_seen", {})
		if last_seen.has(storylet.id):
			var years_since: int = int(state.world.year) - int(last_seen[storylet.id])
			if years_since < int(reqs.cooldown_years):
				return false

	return true


static func calculate_utility(storylet: Dictionary, state: Dictionary, ledger: Dictionary) -> int:
	var util_def: Dictionary = storylet.utility
	var score: int = int(util_def.base)
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	var guardian_id: String = str(state.household.get("guardian_id", ""))
	var guardian: Dictionary = state.actors.get(guardian_id, {})

	for mod: Dictionary in util_def.get("modifiers", []):
		var cond: String = mod.get("condition", "")
		var add: int = int(mod.get("add", 0))
		var applies: bool = false
		match cond:
			"budget_deficit_gt_zero":
				applies = int(ledger.get("budget_deficit", 0)) > 0
			"food_security_lt_800":
				applies = int(ledger.get("food_security", 1000)) < 800
			"guardian_education_first":
				applies = "education_first" in guardian.get("traits", [])
			"player_education_first":
				applies = "education_first" in player.get("traits", [])
			"education_completed":
				applies = player.get("education_state") == "completed"
			"high_employment_pressure":
				applies = int(state.world.employment_pressure) > 500
			"player_has_epidemic":
				applies = player.conditions.has("epidemic_disease")
			"player_has_malnutrition":
				applies = player.conditions.has("malnutrition")
			"high_savings":
				applies = int(state.household.savings) > 5000
			"player_pragmatic":
				applies = "pragmatic" in player.get("traits", [])
			"high_debt":
				applies = int(state.household.get("debt", 0)) > 500
			"severe_food_insecurity":
				applies = int(state.household.get("food_security", 1000)) < 600
			"overcrowded":
				applies = Housing.overcrowding(state) > 0
			"has_sick_family":
				for mem_id: String in state.household.get("member_ids", []):
					if state.actors.has(mem_id) and state.actors[mem_id].alive and not state.actors[mem_id].conditions.is_empty():
						applies = true
						break
		if applies:
			score += add

	return maxi(0, score)


static func select_storylet(pack: Dictionary, state: Dictionary, ledger: Dictionary, seed_value: int) -> Dictionary:
	var storylets: Array = pack.get("storylets", [])
	if storylets.is_empty():
		return {}

	var candidates: Array[Dictionary] = []
	var weights: Array[int] = []

	for st: Dictionary in storylets:
		if is_eligible(st, state):
			var score: int = calculate_utility(st, state, ledger)
			if score > 0:
				candidates.append(st)
				weights.append(score)

	if candidates.is_empty():
		return {}

	# Sakin yıl ihtimali (sabit ağırlıkla her yıl felaket olmaması sağlanır)
	var quiet_weight: int = 35
	weights.append(quiet_weight)

	var selected_idx: int = Rng.weighted(seed_value, "storylet", int(state.world.year),
		str(state.meta.player_id), "selection", weights)

	if selected_idx >= candidates.size():
		return {} # Sakin yıl

	return candidates[selected_idx]


static func apply_choice(delta: RefCounted, storylet: Dictionary, choice_id: String,
		cause_event: String, seed_value: int, pack: Dictionary = {}) -> Dictionary:
	var state: Dictionary = delta.candidate
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]

	var selected_choice: Dictionary = {}
	for ch: Dictionary in storylet.choices:
		if ch.id == choice_id:
			selected_choice = ch
			break

	if selected_choice.is_empty():
		selected_choice = storylet.choices[0]

	var effects: Dictionary = selected_choice.get("effects", {})
	var outcome: Dictionary = {
		"storylet_id": storylet.id,
		"choice_id": selected_choice.id,
		"applied_effects": {}
	}

	# Cooldown ve son görülme güncellemesi
	var st_state: Dictionary = state.get("storylets", {})
	var last_seen: Dictionary = st_state.get("last_seen", {}).duplicate(true)
	last_seen[storylet.id] = delta.year
	delta.set_field("storylets", "last_seen", last_seen, cause_event)

	# 1. Nakit kazanç (cash_grant)
	if effects.has("cash_grant"):
		var grant: int = int(effects.cash_grant)
		delta.set_field("household", "savings", int(state.household.savings) + grant, cause_event)
		outcome.applied_effects["cash_grant"] = grant

	# 2. Nakit harcama (cash_cost)
	if effects.has("cash_cost"):
		var cost: int = int(effects.cash_cost)
		var current_savings: int = int(state.household.savings)
		if current_savings >= cost:
			delta.set_field("household", "savings", current_savings - cost, cause_event)
		else:
			delta.set_field("household", "savings", 0, cause_event)
			var remainder: int = cost - current_savings
			delta.set_field("household", "debt", int(state.household.debt) + remainder, cause_event)
		outcome.applied_effects["cash_cost"] = cost

	# 3. İrade değişimi (willpower_delta)
	if effects.has("willpower_delta"):
		var wp: int = clampi(int(player.willpower) + int(effects.willpower_delta), 0, 100)
		delta.set_field("actors", "willpower", wp, cause_event, player_id)
		outcome.applied_effects["willpower"] = wp

	# 4. Sağlık değişimi (health_delta)
	if effects.has("health_delta"):
		var hlth: int = clampi(int(player.health) + int(effects.health_delta), 1, 100)
		delta.set_field("actors", "health", hlth, cause_event, player_id)
		outcome.applied_effects["health"] = hlth

	# 5. Okuryazarlık değişimi (literacy_delta)
	if effects.has("literacy_delta"):
		var lit: int = clampi(int(player.literacy) + int(effects.literacy_delta), 0, 100)
		delta.set_field("actors", "literacy", lit, cause_event, player_id)
		outcome.applied_effects["literacy"] = lit

	# 6. Bayrak atama (set_flag)
	if effects.has("set_flag"):
		var flags: Dictionary = st_state.get("flags", {}).duplicate(true)
		flags[effects.set_flag] = true
		delta.set_field("storylets", "flags", flags, cause_event)
		outcome.applied_effects["flag"] = effects.set_flag

	# 7. Ertelenen iş (deferred_job)
	if effects.has("deferred_job"):
		var pending: Array = state.household.pending_effects.duplicate(true)
		var job_id: String = effects.deferred_job
		pending.append({
			"id": player_id + ":" + job_id,
			"type": "start_job",
			"actor_id": player_id,
			"occupation_id": job_id,
			"due_year": delta.year + 1,
			"cause_id": cause_event
		})
		delta.set_field("household", "pending_effects", pending, cause_event)
		outcome.applied_effects["deferred_job"] = job_id

	# 8. Koşul iyileştirme (cure_condition)
	if effects.has("cure_condition"):
		var conds: Dictionary = player.conditions.duplicate(true)
		var cured_id: String = ""
		for candidate_c: String in ["epidemic_disease", "workplace_injury", "malnutrition"]:
			if conds.has(candidate_c):
				conds.erase(candidate_c)
				cured_id = candidate_c
				break
		if cured_id != "":
			delta.set_field("actors", "conditions", conds, cause_event, player_id)
			outcome.applied_effects["cured"] = cured_id

	# 9. İş kazası riski (injury_hazard_bp)
	if effects.has("injury_hazard_bp"):
		if Rng.integer(seed_value, "storylet", delta.year, player_id, "injury_hazard", 0, 9999) < int(effects.injury_hazard_bp):
			var conds: Dictionary = player.conditions.duplicate(true)
			conds["workplace_injury"] = {"acquired_year": delta.year, "remaining_years": 2}
			delta.set_field("actors", "conditions", conds, cause_event, player_id)
			outcome.applied_effects["injury_occurred"] = true
		else:
			outcome.applied_effects["injury_occurred"] = false

	# 10. Çocukluk iradesi denetimi (agency_check)
	if effects.has("agency_check"):
		var check_def: Dictionary = effects.agency_check
		var guardian_id: String = str(state.household.get("guardian_id", ""))
		var guardian: Dictionary = state.actors.get(guardian_id, {})
		var guardian_agrees: bool = check_def.get("trait", "") in guardian.get("traits", [])
		if not guardian_agrees and int(player.willpower) >= int(check_def.get("fallback_willpower", 50)):
			guardian_agrees = true
		if guardian_agrees:
			outcome.applied_effects["agency_success"] = true
		else:
			outcome.applied_effects["agency_success"] = false
			var job_id: String = check_def.get("failure_deferred_job", "child_factory_worker")
			var pending: Array = state.household.pending_effects.duplicate(true)
			pending.append({
				"id": player_id + ":" + job_id,
				"type": "start_job",
				"actor_id": player_id,
				"occupation_id": job_id,
				"due_year": delta.year + 1,
				"cause_id": cause_event
			})
			delta.set_field("household", "pending_effects", pending, cause_event)
			outcome.applied_effects["agency_success"] = false

	# 11. Kalıcı varlık kaldırma
	if effects.has("remove_asset"):
		var removed_asset_id: String = str(effects.remove_asset)
		if Assets.remove_asset(state, removed_asset_id, "storylet:" + str(storylet.id)):
			outcome.applied_effects["removed_asset"] = removed_asset_id

	# 12. Evlilik oluşturma (marry seçimi veya create_spouse)
	if selected_choice.id == "marry" or effects.has("create_spouse"):
		Family.ensure_state(state)
		if str(state.family.get("current_spouse_id", "")) == "" and not pack.is_empty():
			var marriage_event: String = Family.create_spouse(delta, pack, cause_event, seed_value)
			outcome.applied_effects["married"] = marriage_event != ""

	return outcome
