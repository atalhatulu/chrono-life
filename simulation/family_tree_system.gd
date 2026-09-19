extends RefCounted
## Family Tree / Genealogy System.
## Reconstructs multi-generational lineage, roles, and branch relations.

const FamilySystem = preload("res://simulation/family_system.gd")

static func _role_label(id: String, role: String, sex: String, is_player: bool) -> String:
	if is_player:
		return "Sen"
	match role:
		"father":
			return "Baban"
		"mother":
			return "Annen"
		"parent":
			return "Annen" if sex == "female" else "Baban"
		"spouse":
			return "Eşin"
		"ex_spouse":
			return "Eski Eşin"
		"child":
			return "Kızın" if sex == "female" else "Oğlun"
		"sibling":
			return "Kız Kardeşin" if sex == "female" else "Erkek Kardeşin"
		"grandchild":
			return "Kız Torunun" if sex == "female" else "Erkek Torunun"
		"in_law":
			return "Gelin" if sex == "female" else "Damat"
		_:
			return "Aile Bireyi"

static func build_tree(state: Dictionary) -> Dictionary:
	FamilySystem.ensure_state(state)
	var player_id: String = str(state.get("meta", {}).get("player_id", "player"))
	var actors: Dictionary = state.get("actors", {})
	var kinship: Dictionary = state.get("family", {}).get("kinship", {})
	var marriages: Array = state.get("family", {}).get("marriages", [])
	var current_spouse_id: String = str(state.get("family", {}).get("current_spouse_id", ""))
	var player_household: String = str(state.get("household", {}).get("id", ""))

	var members_by_gen: Dictionary = {
		-1: [], # Roots / Parents
		0: [],  # Core / Player, Spouse, Siblings
		1: [],  # Descendants / Children
		2: []   # Extended / Grandchildren
	}

	var processed_ids: Dictionary = {}

	# 1. Parents (-1)
	var player_parents: Array = kinship.get(player_id, {}).get("parents", [])
	for parent_id in player_parents:
		var pid: String = str(parent_id)
		if actors.has(pid):
			var actor: Dictionary = actors[pid]
			var sex: String = str(actor.get("sex", "male"))
			var role: String = "mother" if sex == "female" else "father"
			members_by_gen[-1].append(_create_member(pid, actor, role, sex, false, player_household))
			processed_ids[pid] = true

	# Fallback check for parent_1, parent_2 if not linked in kinship
	for pid: String in ["parent_1", "parent_2"]:
		if actors.has(pid) and not processed_ids.has(pid):
			var actor: Dictionary = actors[pid]
			var sex: String = str(actor.get("sex", "male"))
			var role: String = "mother" if sex == "female" else "father"
			members_by_gen[-1].append(_create_member(pid, actor, role, sex, false, player_household))
			processed_ids[pid] = true

	# 2. Core Generation (0): Player
	if actors.has(player_id):
		var p_actor: Dictionary = actors[player_id]
		var p_sex: String = str(p_actor.get("sex", "male"))
		members_by_gen[0].append(_create_member(player_id, p_actor, "self", p_sex, true, player_household))
		processed_ids[player_id] = true

	# Core Generation (0): Spouses
	var all_spouses: Array = []
	if current_spouse_id != "" and current_spouse_id not in all_spouses:
		all_spouses.append(current_spouse_id)
	for m: Dictionary in marriages:
		var sp_id: String = str(m.get("spouse_id", ""))
		if sp_id != "" and sp_id not in all_spouses:
			all_spouses.append(sp_id)
	for sp_id: String in all_spouses:
		if actors.has(sp_id) and not processed_ids.has(sp_id):
			var actor: Dictionary = actors[sp_id]
			var sex: String = str(actor.get("sex", "female"))
			var is_current: bool = (sp_id == current_spouse_id)
			var role: String = "spouse" if is_current else "ex_spouse"
			members_by_gen[0].append(_create_member(sp_id, actor, role, sex, false, player_household))
			processed_ids[sp_id] = true

	# Core Generation (0): Siblings
	var player_siblings: Array = kinship.get(player_id, {}).get("siblings", [])
	for sib_id in player_siblings:
		var sid: String = str(sib_id)
		if actors.has(sid) and not processed_ids.has(sid):
			var actor: Dictionary = actors[sid]
			var sex: String = str(actor.get("sex", "male"))
			members_by_gen[0].append(_create_member(sid, actor, "sibling", sex, false, player_household))
			processed_ids[sid] = true

	# 3. Generation 1: Children
	var children_ids: Array = state.get("family", {}).get("children_ids", [])
	for cid in children_ids:
		var child_id: String = str(cid)
		if actors.has(child_id) and not processed_ids.has(child_id):
			var actor: Dictionary = actors[child_id]
			var sex: String = str(actor.get("sex", "male"))
			members_by_gen[1].append(_create_member(child_id, actor, "child", sex, false, player_household))
			processed_ids[child_id] = true

	# 4. Generation 2: Grandchildren
	var grandchildren_ids: Array = state.get("family", {}).get("grandchildren_ids", [])
	for gcid in grandchildren_ids:
		var gc_id: String = str(gcid)
		if actors.has(gc_id) and not processed_ids.has(gc_id):
			var actor: Dictionary = actors[gc_id]
			var sex: String = str(actor.get("sex", "male"))
			members_by_gen[2].append(_create_member(gc_id, actor, "grandchild", sex, false, player_household))
			processed_ids[gc_id] = true

	# Catch any remaining actors that belong to family or household
	for aid: String in actors.keys():
		if not processed_ids.has(aid):
			var actor: Dictionary = actors[aid]
			var sex: String = str(actor.get("sex", "male"))
			var role: String = "in_law" if (aid.begins_with("partner_") or aid.contains("child_partner")) else "family"
			var gen: int = 1 if role == "in_law" else 0
			members_by_gen[gen].append(_create_member(aid, actor, role, sex, false, player_household))
			processed_ids[aid] = true

	var total_members: int = 0
	var living_count: int = 0
	var deceased_count: int = 0

	var generations_array: Array[Dictionary] = []
	var titles: Dictionary = {
		-1: {"title": "I. Kuşak · Kökler", "desc": "Ebeveynlerin"},
		0: {"title": "II. Kuşak · Çekirdek Aile", "desc": "Sen, eşin ve kardeşlerin"},
		1: {"title": "III. Kuşak · Çocuklar", "desc": "Evlatların ve onların haneleri"},
		2: {"title": "IV. Kuşak · Torunlar", "desc": "Soyun sonraki dalları"}
	}

	for gen_level: int in [-1, 0, 1, 2]:
		var members: Array = members_by_gen[gen_level]
		if members.is_empty():
			continue
		for m: Dictionary in members:
			total_members += 1
			if m.alive:
				living_count += 1
			else:
				deceased_count += 1
		generations_array.append({
			"level": gen_level,
			"title": titles[gen_level]["title"],
			"description": titles[gen_level]["desc"],
			"members": members
		})

	return {
		"player_id": player_id,
		"generations": generations_array,
		"stats": {
			"total_members": total_members,
			"living_count": living_count,
			"deceased_count": deceased_count,
			"generations_count": generations_array.size()
		}
	}

static func _create_member(id: String, actor: Dictionary, role: String, sex: String, is_player: bool, player_household: String) -> Dictionary:
	var alive: bool = bool(actor.get("alive", true))
	var birth_year: int = int(actor.get("birth_year", 0))
	var death_year: int = int(actor.get("death_year", 0))
	var age: int = int(actor.get("age", 0))
	var household_id: String = str(actor.get("household_id", ""))
	var same_household: bool = (household_id == player_household and player_household != "")
	return {
		"id": id,
		"name": str(actor.get("name", id)),
		"sex": sex,
		"role": role,
		"role_label": _role_label(id, role, sex, is_player),
		"is_player": is_player,
		"birth_year": birth_year,
		"death_year": death_year,
		"alive": alive,
		"age": age,
		"occupation_id": str(actor.get("occupation_id", "dependent")),
		"health": int(actor.get("health", 100)),
		"same_household": same_household
	}
